import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../services/app_update_service.dart';
import '../services/order_service.dart';
import '../services/pricing_config.dart';
import '../theme.dart';
import 'add_card_item_screen.dart';
import 'profile_screen.dart';

final _currency = NumberFormat.simpleCurrency(name: 'USD');

/// The "new order" flow: a shopping-cart-style screen where the user adds
/// one or more cards (via [AddCardItemScreen]) before sending the whole
/// cart as a single order request. [isAdmin] is resolved once by the caller
/// (see `_AccessGate` in main.dart) rather than re-queried here, since every
/// screen asking the same tiny doc independently was three listeners for one
/// value.
class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final List<OrderItem> _cartItems = [];
  bool _submitting = false;
  String? _error;

  double get _cardsSubtotal => _cartItems.fold<double>(
    0,
    (acc, item) => acc + item.unitPrice * item.quantity,
  );

  double get _shippingTotal =>
      _cartItems.fold<double>(0, (acc, item) => acc + item.shipping);

  double get _subtotal =>
      double.parse((_cardsSubtotal + _shippingTotal).toStringAsFixed(2));

  double get _tax =>
      double.parse((_subtotal * fixedTaxRate).toStringAsFixed(2));

  int get _totalQuantity =>
      _cartItems.fold<int>(0, (acc, item) => acc + item.quantity);

  /// Flat per-card fee for consolidating and forwarding to Peru — charged
  /// per unit (quantity), not per line item, and not subject to US sales tax.
  /// Admins pay a reduced fee.
  double get _shippingFeePerCard => internationalShippingFeeFor(widget.isAdmin);

  double get _internationalShipping =>
      double.parse((_totalQuantity * _shippingFeePerCard).toStringAsFixed(2));

  /// Tiered service margin (see [marginTiers]) — each card's own unit price
  /// picks its bracket, not subject to US sales tax. Admins pay no margin.
  double get _margin => widget.isAdmin
      ? 0
      : double.parse(
          _cartItems
              .fold<double>(0, (acc, item) => acc + marginAmountForItem(item))
              .toStringAsFixed(2),
        );

  double get _total => double.parse(
    (_subtotal + _tax + _margin + _internationalShipping).toStringAsFixed(2),
  );

  void _showMarginTable() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tabla de margen escalonado'),
        content: Table(
          border: TableBorder.all(color: Theme.of(context).dividerColor),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.3),
            2: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              children: const [
                _TableCell('Desde (USD)', header: true),
                _TableCell('Rango', header: true),
                _TableCell('Margen %', header: true),
              ],
            ),
            for (final tier in marginTiers)
              TableRow(
                children: [
                  _TableCell(tier.from.toStringAsFixed(2)),
                  _TableCell(tier.rangeLabel),
                  _TableCell('${(tier.rate * 100).toStringAsFixed(2)}%'),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    final item = await Navigator.of(context).push<OrderItem>(
      MaterialPageRoute(builder: (_) => const AddCardItemScreen()),
    );
    if (item == null) return;
    setState(() => _cartItems.add(item));
  }

  Future<void> _submit() async {
    if (_cartItems.isEmpty) return;
    setState(() => _error = null);

    setState(() => _submitting = true);
    final canSubmit = await AppUpdateService.instance.canSubmitOrders();
    if (!mounted) return;
    if (!canSubmit) {
      setState(() {
        _submitting = false;
        _error =
            'Es necesario actualizar la aplicación. Por favor actualiza o '
            'limpia la caché.';
      });
      return;
    }
    setState(() => _submitting = false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar pedido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_cartItems.length} carta(s)'),
            const SizedBox(height: 8),
            _PriceRow('Cartas', _cardsSubtotal),
            if (_shippingTotal > 0) _PriceRow('Envío', _shippingTotal),
            _PriceRow(
              'Tax estimado (${(fixedTaxRate * 100).toStringAsFixed(0)}%)',
              _tax,
            ),
            _PriceRow('Margen de servicio', _margin),
            _PriceRow(
              'Envío a Perú ($_totalQuantity carta(s) × ${_currency.format(_shippingFeePerCard)})',
              _internationalShipping,
            ),
            const Divider(),
            _PriceRow('Total estimado', _total, bold: true),
            const SizedBox(height: 8),
            const Text(
              'Este pedido lo compra el staff manualmente en TCGPlayer; el monto final '
              'puede variar levemente.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar pedido'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await OrderService.instance.createOrder(items: _cartItems);
      if (mounted) Navigator.of(context).pop();
    } on ActiveOrderExistsException {
      setState(
        () =>
            _error = 'Ya tienes un pedido activo. Espera a que sea entregado.',
      );
    } on MissingWhatsAppException {
      setState(
        () => _error =
            'Registra tu número de WhatsApp para poder enviar el pedido.',
      );
      await _promptForWhatsapp();
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Offers to go fill in the missing WhatsApp number. The cart is left
  /// untouched, so coming back from the profile is one tap away from sending
  /// the same order.
  Future<void> _promptForWhatsapp() async {
    if (!mounted) return;
    final goToProfile = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Falta tu WhatsApp'),
        content: const Text(
          'Necesitamos tu número para coordinar el pago y la entrega del '
          'pedido. Regístralo en tu perfil y vuelve a enviarlo — tu carrito '
          'se mantiene.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Completar perfil'),
          ),
        ],
      ),
    );
    if (goToProfile != true || !mounted) return;

    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (saved == true && mounted) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<LaFosaColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _cartItems.isEmpty
              ? 'Nuevo pedido'
              : 'Nuevo pedido · ${_cartItems.length} carta(s)',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Ver tabla de margen',
            onPressed: _showMarginTable,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Agregar carta'),
      ),
      body: _cartItems.isEmpty
          ? _buildEmptyState(context, brand)
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _cartItems.length,
              itemBuilder: (context, i) {
                return _CartItemCard(
                  item: _cartItems[i],
                  brand: brand,
                  isAdmin: widget.isAdmin,
                  onRemove: () => setState(() => _cartItems.removeAt(i)),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              if (_cartItems.isNotEmpty) ...[
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: brand.violet,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Resumen del pedido',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _PriceRow(
                          'Cartas',
                          _cardsSubtotal,
                          icon: Icons.style_outlined,
                        ),
                        if (_shippingTotal > 0)
                          _PriceRow(
                            'Envío del vendedor',
                            _shippingTotal,
                            icon: Icons.local_shipping_outlined,
                          ),
                        _PriceRow(
                          'Tax estimado (${(fixedTaxRate * 100).toStringAsFixed(0)}%)',
                          _tax,
                          icon: Icons.percent,
                        ),
                        _PriceRow(
                          'Margen de servicio',
                          _margin,
                          icon: Icons.storefront_outlined,
                        ),
                        _PriceRow(
                          'Envío a Perú ($_totalQuantity carta(s) × ${_currency.format(_shippingFeePerCard)})',
                          _internationalShipping,
                          icon: Icons.flight_takeoff_outlined,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: brand.violet.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total estimado',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _currency.format(_total),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: brand.violet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: (_cartItems.isEmpty || _submitting) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar pedido'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, LaFosaColors brand) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brand.violet.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: brand.violet.withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.add_shopping_cart_outlined,
                size: 48,
                color: brand.violet,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tu carrito está vacío',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega tu primera carta con el botón de abajo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A cart line: card name/set up top with the price and a remove button,
/// then a row of small chips for the details (quantity, condition, seller or
/// reference status, shipping) instead of one run-on sentence — easier to
/// scan than the plain `ListTile` this replaced.
class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.brand,
    required this.isAdmin,
    required this.onRemove,
  });

  final OrderItem item;
  final LaFosaColors brand;
  final bool isAdmin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isReferencePrice ? Colors.amber : brand.violet;
    final statusIcon = item.isReferencePrice
        ? Icons.help_outline
        : Icons.verified_outlined;
    final statusLabel = item.isReferencePrice
        ? (item.sellerName?.isNotEmpty == true
              ? '${item.sellerName} (referencial)'
              : 'Precio referencial')
        : (item.sellerName?.isNotEmpty == true
              ? item.sellerName!
              : 'Vendedor confirmado');

    // The line's own price + seller shipping, plus this card's share of the
    // cart-level fees — every one of these is a simple per-item slice of how
    // the bottom summary computes the same totals, so they always add up to
    // exactly what the cart shows overall.
    final lineSubtotal = item.lineTotal;
    final itemTax = double.parse(
      (lineSubtotal * fixedTaxRate).toStringAsFixed(2),
    );
    final itemMargin = isAdmin
        ? 0.0
        : double.parse(marginAmountForItem(item).toStringAsFixed(2));
    final itemPeruShipping = double.parse(
      (item.quantity * internationalShippingFeeFor(isAdmin)).toStringAsFixed(2),
    );
    final itemGrandTotal = double.parse(
      (lineSubtotal + itemTax + itemMargin + itemPeruShipping).toStringAsFixed(
        2,
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.15),
                  ),
                  child: Icon(statusIcon, size: 20, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.cardName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (item.setName.isNotEmpty)
                        Text(
                          item.setName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currency.format(itemGrandTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onRemove,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _DetailChip(icon: Icons.style_outlined, label: item.condition),
                _DetailChip(icon: Icons.numbers, label: '×${item.quantity}'),
                _DetailChip(
                  icon: statusIcon,
                  label: statusLabel,
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // What gets added on top of the seller's own price to reach the
            // total above — mirrors the bottom summary's rows, one line at a
            // time, so it's clear why the total is more than "precio × qty".
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (item.shipping > 0)
                  _DetailChip(
                    icon: Icons.local_shipping_outlined,
                    label: 'Envío vendedor +${_currency.format(item.shipping)}',
                  ),
                _DetailChip(
                  icon: Icons.percent,
                  label: 'Tax +${_currency.format(itemTax)}',
                ),
                if (itemMargin > 0)
                  _DetailChip(
                    icon: Icons.storefront_outlined,
                    label: 'Margen +${_currency.format(itemMargin)}',
                  ),
                _DetailChip(
                  icon: Icons.flight_takeoff_outlined,
                  label: 'Envío Perú +${_currency.format(itemPeruShipping)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill used inside [_CartItemCard] to show one detail at a glance.
/// Neutral (grey) by default; pass [color] for the seller/reference status
/// chip so it stands out from the rest.
class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: color != null ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tint.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: tint.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool header;

  const _TableCell(this.text, {this.header = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: header ? const TextStyle(fontWeight: FontWeight.bold) : null,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  final IconData? icon;

  const _PriceRow(this.label, this.amount, {this.bold = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 15,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(child: Text(label, style: style)),
              ],
            ),
          ),
          Text(_currency.format(amount), style: style),
        ],
      ),
    );
  }
}
