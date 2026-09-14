import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../services/pricing_config.dart';
import '../../widgets/customer_contact.dart';

final _currency = NumberFormat.simpleCurrency(name: 'USD');

/// Admin-only reprice of an already-placed order: TCGPlayer prices move
/// constantly, so by the time the staff sits down to buy, the quoted numbers
/// are often stale. Editing any line recalculates tax, margin, Peru shipping
/// and the total live — on the same fee schedule the order was originally
/// quoted with — and saving parks the order in [OrderStatus.priceReview]
/// until the customer approves the new total next time they open the app.
class EditOrderPricesScreen extends StatefulWidget {
  const EditOrderPricesScreen({super.key, required this.order});

  final CardOrder order;

  @override
  State<EditOrderPricesScreen> createState() => _EditOrderPricesScreenState();
}

class _EditOrderPricesScreenState extends State<EditOrderPricesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  late final List<_ItemDraft> _drafts;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _drafts = widget.order.items.map(_ItemDraft.new).toList();
    for (final draft in _drafts) {
      draft.priceCtrl.addListener(_onChanged);
      draft.shippingCtrl.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// The cart as currently typed. Lines whose price the staff touched stop
  /// being flagged as referential — a staff-entered number *is* the price the
  /// customer is being asked to confirm.
  List<OrderItem> get _editedItems =>
      _drafts.map((d) => d.toItem()).toList(growable: false);

  bool get _hasChanges => _drafts.any((d) => d.isDirty);

  OrderTotals get _totals => OrderTotals.forItems(
    _editedItems,
    adminPricing: widget.order.usesAdminPricing,
  );

  double get _difference => double.parse(
    (_totals.total - widget.order.estimatedTotal).toStringAsFixed(2),
  );

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_hasChanges) {
      setState(() => _error = 'No cambiaste ningún precio todavía.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar ajuste de precio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TotalRow('Total anterior', widget.order.estimatedTotal),
            _TotalRow('Total nuevo', _totals.total, bold: true),
            _TotalRow(
              _difference >= 0 ? 'Diferencia a pagar' : 'Ahorro',
              _difference.abs(),
              color: _difference >= 0 ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 12),
            Text(
              'El pedido quedará en "${OrderStatus.priceReview.label}" y '
              '${widget.order.userDisplayName} verá el nuevo precio al entrar '
              'a la app para dar su conformidad. Recién ahí podrás marcarlo '
              'como comprado.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
            child: const Text('Enviar al cliente'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Captured before the await: the screen pops itself on success, so the
    // snackbar has to be handed to the messenger that outlives this route.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    try {
      final totals = await OrderService.instance.applyPriceAdjustment(
        order: widget.order,
        items: _editedItems,
        note: _noteCtrl.text,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Precio actualizado a ${_currency.format(totals.total)}. '
            '${widget.order.userDisplayName} verá el cambio al entrar a la app.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo guardar el ajuste: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    return Scaffold(
      appBar: AppBar(title: const Text('Editar precios del pedido')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                'Pedido de ${widget.order.userDisplayName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              // Same tap-to-chat link as the panel list: a reprice is exactly
              // when the staff may need to ask the customer something.
              CustomerContact(order: widget.order),
              const SizedBox(height: 8),
              const Text(
                'Actualiza el precio de cada carta con lo que realmente cuesta '
                'ahora en TCGPlayer. Los cálculos se rehacen solos y el cliente '
                'tendrá que confirmar el nuevo total.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              for (final draft in _drafts) ...[
                _ItemPriceEditor(draft: draft),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nota para el cliente (opcional)',
                  hintText: 'Ej: el vendedor original se quedó sin stock.',
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _TotalRow('Subtotal', totals.subtotal),
                      _TotalRow(
                        'Tax estimado (${(totals.taxRate * 100).toStringAsFixed(0)}%)',
                        totals.tax,
                      ),
                      _TotalRow('Margen de servicio', totals.margin),
                      _TotalRow(
                        'Envío a Perú (${totals.totalQuantity} carta(s))',
                        totals.internationalShipping,
                      ),
                      const Divider(),
                      _TotalRow(
                        'Total anterior',
                        widget.order.estimatedTotal,
                        color: Colors.grey,
                      ),
                      _TotalRow('Total nuevo', totals.total, bold: true),
                      if (_hasChanges)
                        _TotalRow(
                          _difference >= 0 ? 'Diferencia' : 'Ahorro',
                          _difference.abs(),
                          color: _difference >= 0
                              ? Colors.orange
                              : Colors.green,
                        ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.price_change_outlined),
                label: Text(
                  _saving
                      ? 'Guardando…'
                      : 'Guardar y pedir conformidad al cliente',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One editable cart line: the fields that make up its price, plus whatever
/// the customer was originally quoted for it so the staff can see the drift.
class _ItemDraft {
  _ItemDraft(this.original)
    : priceCtrl = TextEditingController(
        text: original.unitPrice.toStringAsFixed(2),
      ),
      shippingCtrl = TextEditingController(
        text: original.shipping.toStringAsFixed(2),
      ),
      sellerCtrl = TextEditingController(text: original.sellerName ?? '');

  final OrderItem original;
  final TextEditingController priceCtrl;
  final TextEditingController shippingCtrl;
  final TextEditingController sellerCtrl;

  double get unitPrice =>
      double.tryParse(priceCtrl.text.trim()) ?? original.unitPrice;

  double get shipping =>
      double.tryParse(shippingCtrl.text.trim()) ?? original.shipping;

  String? get sellerName {
    final seller = sellerCtrl.text.trim();
    return seller.isEmpty ? null : seller;
  }

  double get lineTotal => unitPrice * original.quantity + shipping;

  /// Compared with a half-cent tolerance: the fields start out rendered to two
  /// decimals, so an untouched line whose stored price had more precision than
  /// that must not count as an edit.
  bool get priceChanged =>
      (unitPrice - original.unitPrice).abs() >= 0.005 ||
      (shipping - original.shipping).abs() >= 0.005;

  bool get isDirty =>
      priceChanged || (sellerName ?? '') != (original.sellerName ?? '');

  /// Rebuilt field by field rather than with a copyWith, so that emptying the
  /// seller box actually clears the seller instead of reading as "unchanged".
  OrderItem toItem() => OrderItem(
    cardName: original.cardName,
    setName: original.setName,
    condition: original.condition,
    sellerName: sellerName,
    listingUrl: original.listingUrl,
    unitPrice: unitPrice,
    shipping: shipping,
    quantity: original.quantity,
    // A price the staff typed in is a real quote, not the customer's own
    // rough estimate any more.
    isReferencePrice: priceChanged ? false : original.isReferencePrice,
  );

  void dispose() {
    priceCtrl.dispose();
    shippingCtrl.dispose();
    sellerCtrl.dispose();
  }
}

class _ItemPriceEditor extends StatelessWidget {
  const _ItemPriceEditor({required this.draft});

  final _ItemDraft draft;

  @override
  Widget build(BuildContext context) {
    final item = draft.original;
    final delta = draft.lineTotal - item.lineTotal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.cardName}  ×${item.quantity}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              [
                if (item.setName.isNotEmpty) item.setName,
                item.condition,
                if (item.isReferencePrice) 'Precio referencial',
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.priceCtrl,
                    decoration: InputDecoration(
                      labelText: 'Precio unitario',
                      prefixText: '\$ ',
                      helperText: 'Antes: ${_currency.format(item.unitPrice)}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final parsed = double.tryParse((v ?? '').trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Precio inválido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: draft.shippingCtrl,
                    decoration: InputDecoration(
                      labelText: 'Envío vendedor',
                      prefixText: '\$ ',
                      helperText: 'Antes: ${_currency.format(item.shipping)}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final parsed = double.tryParse((v ?? '').trim());
                      if (parsed == null || parsed < 0) {
                        return 'Envío inválido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.sellerCtrl,
              decoration: const InputDecoration(
                labelText: 'Vendedor (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total de la línea'),
                Text(
                  _currency.format(draft.lineTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: delta == 0
                        ? null
                        : (delta > 0 ? Colors.orange : Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.amount, {this.bold = false, this.color});

  final String label;
  final double amount;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : null,
      fontSize: bold ? 16 : null,
      color: color,
    );
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
