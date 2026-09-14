import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../services/app_update_service.dart';
import '../services/order_service.dart';
import '../services/pricing_config.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo pedido'),
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
          ? const Center(
              child: Text('Agrega al menos una carta con el botón de abajo.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _cartItems.length,
              itemBuilder: (context, i) {
                final item = _cartItems[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text('${item.cardName}  ×${item.quantity}'),
                    subtitle: Text(
                      [
                        if (item.setName.isNotEmpty) item.setName,
                        item.condition,
                        item.isReferencePrice
                            ? (item.sellerName?.isNotEmpty == true
                                  ? '${item.sellerName} (referencial)'
                                  : 'Precio referencial')
                            : (item.sellerName ?? ''),
                        if (item.shipping > 0)
                          '+ ${_currency.format(item.shipping)} envío',
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_currency.format(item.lineTotal)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => _cartItems.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              if (_cartItems.isNotEmpty) ...[
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
                const Divider(height: 16),
                _PriceRow('Total estimado', _total, bold: true),
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

  const _PriceRow(this.label, this.amount, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(_currency.format(amount), style: style),
        ],
      ),
    );
  }
}
