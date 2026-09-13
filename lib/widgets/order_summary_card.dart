import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../services/auth_service.dart';
import 'price_adjustment_actions.dart';

final _currency = NumberFormat.simpleCurrency(name: 'USD');

class OrderSummaryCard extends StatelessWidget {
  final CardOrder order;
  final bool showRequester;
  final Widget? trailing;

  const OrderSummaryCard({
    super.key,
    required this.order,
    this.showRequester = false,
    this.trailing,
  });

  /// Whether the person looking at this card is the customer who has to
  /// answer a pending reprice — admins browsing the same order see the
  /// read-only summary instead.
  bool get _showsPriceResponse =>
      order.awaitsPriceConfirmation &&
      order.userId == AuthService.instance.currentUser?.uid;

  Color _statusColor(BuildContext context) {
    return switch (order.status) {
      OrderStatus.pending => Colors.orange,
      OrderStatus.priceReview => Colors.amber,
      OrderStatus.priceConfirmed => Colors.teal,
      OrderStatus.awaitingPayment => Colors.deepOrange,
      OrderStatus.ordered => Colors.blue,
      OrderStatus.shipped => Colors.purple,
      OrderStatus.inTransit => Colors.indigo,
      OrderStatus.delivered => Colors.green,
      OrderStatus.cancelled => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.items.length} carta(s)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(order.status.label),
                  backgroundColor: _statusColor(
                    context,
                  ).withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: _statusColor(context)),
                ),
              ],
            ),
            if (showRequester)
              Text(
                'Pedido por: ${order.userDisplayName}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            const Divider(),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                              item.isReferencePrice
                                  ? (item.sellerName?.isNotEmpty == true
                                        ? 'Vendedor: ${item.sellerName} (referencial)'
                                        : 'Precio referencial')
                                  : 'Vendedor: ${item.sellerName ?? '—'}',
                              if (item.shipping > 0)
                                '+ ${_currency.format(item.shipping)} envío',
                            ].where((s) => s.isNotEmpty).join(' · '),
                          ),
                        ],
                      ),
                    ),
                    Text(_currency.format(item.lineTotal)),
                  ],
                ),
              ),
            const Divider(),
            Text('Subtotal: ${_currency.format(order.estimatedSubtotal)}'),
            Text(
              'Tax estimado (${(order.estimatedTaxRate * 100).toStringAsFixed(2)}%): '
              '${_currency.format(order.estimatedTax)}',
            ),
            if (order.estimatedMargin > 0)
              Text(
                'Margen de servicio: ${_currency.format(order.estimatedMargin)}',
              ),
            if (order.estimatedInternationalShipping > 0)
              Text(
                'Envío a Perú: ${_currency.format(order.estimatedInternationalShipping)}',
              ),
            Text(
              'Total estimado: ${_currency.format(order.estimatedTotal)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_showsPriceResponse) ...[
              const SizedBox(height: 12),
              PriceAdjustmentActions(order: order),
            ] else if (order.priceAdjustment != null) ...[
              const SizedBox(height: 8),
              _AdjustmentSummary(
                adjustment: order.priceAdjustment!,
                status: order.status,
              ),
            ],
            if (trailing != null) ...[const SizedBox(height: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Read-only trace of the last reprice, for everyone who isn't the customer
/// being asked to approve it (staff in the admin panel, or the customer
/// themselves once they've already answered).
class _AdjustmentSummary extends StatelessWidget {
  const _AdjustmentSummary({required this.adjustment, required this.status});

  final PriceAdjustment adjustment;
  final OrderStatus status;

  String get _state {
    if (status == OrderStatus.priceReview) {
      return 'Esperando la conformidad del cliente.';
    }
    return switch (adjustment.accepted) {
      true => 'El cliente dio su conformidad.',
      false => 'El cliente rechazó el ajuste.',
      _ => 'Sin respuesta del cliente.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final wentUp = adjustment.difference >= 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ajuste de precio: ${_currency.format(adjustment.previousTotal)} → '
            '${_currency.format(adjustment.newTotal)} '
            '(${wentUp ? '+' : '−'}${_currency.format(adjustment.difference.abs())})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (adjustment.adjustedByName?.isNotEmpty == true)
            Text(
              'Por: ${adjustment.adjustedByName}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          if (adjustment.note?.isNotEmpty == true)
            Text(
              'Nota: ${adjustment.note}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          Text(
            _state,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
