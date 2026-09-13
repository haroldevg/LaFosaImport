import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';

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

  Color _statusColor(BuildContext context) {
    return switch (order.status) {
      OrderStatus.pending => Colors.orange,
      OrderStatus.ordered => Colors.blue,
      OrderStatus.shipped => Colors.purple,
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
            if (trailing != null) ...[const SizedBox(height: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
