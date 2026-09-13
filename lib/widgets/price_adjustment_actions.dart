import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../services/order_service.dart';
import '../theme.dart';

final _currency = NumberFormat.simpleCurrency(name: 'USD');

/// The customer's side of a staff reprice: what changed, and the yes/no that
/// unblocks (or cancels) the purchase. Rendered inside [OrderSummaryCard]
/// wherever the owner can see their own order — home, history, or the
/// closed-app screen — so the answer is never more than one tap away from
/// the email that announced it.
class PriceAdjustmentActions extends StatefulWidget {
  const PriceAdjustmentActions({super.key, required this.order});

  final CardOrder order;

  @override
  State<PriceAdjustmentActions> createState() => _PriceAdjustmentActionsState();
}

class _PriceAdjustmentActionsState extends State<PriceAdjustmentActions> {
  bool _submitting = false;

  Future<void> _respond(bool accepted) async {
    final adjustment = widget.order.priceAdjustment;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accepted ? 'Confirmar nuevo precio' : 'Rechazar el ajuste'),
        content: Text(
          accepted
              ? 'Aceptas pagar ${_currency.format(widget.order.estimatedTotal)} '
                    'por este pedido. El staff procederá con la compra.'
              : 'Tu pedido se cancelará y podrás armar uno nuevo cuando '
                    'quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(accepted ? 'Sí, confirmo' : 'Sí, cancelar pedido'),
          ),
        ],
      ),
    );
    if (confirmed != true || adjustment == null) return;

    setState(() => _submitting = true);
    try {
      await OrderService.instance.respondToPriceAdjustment(
        widget.order,
        accepted: accepted,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? 'Listo, confirmaste el nuevo precio. El staff hará la compra.'
                : 'Pedido cancelado.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo registrar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<LaFosaColors>()!;
    final adjustment = widget.order.priceAdjustment;
    final wentUp = (adjustment?.difference ?? 0) >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brand.violet.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brand.violet.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.price_change_outlined, color: brand.violet, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El staff ajustó el precio de tu pedido',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: brand.violet,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (adjustment != null) ...[
            Text(
              'Antes: ${_currency.format(adjustment.previousTotal)}  →  '
              'Ahora: ${_currency.format(adjustment.newTotal)}',
            ),
            Text(
              wentUp
                  ? 'Diferencia: +${_currency.format(adjustment.difference)}'
                  : 'Ahorro: ${_currency.format(adjustment.difference.abs())}',
              style: TextStyle(
                color: wentUp ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (adjustment.note != null && adjustment.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Nota del staff: ${adjustment.note}'),
            ],
            const SizedBox(height: 8),
          ],
          const Text(
            'Confirma el nuevo precio para que el staff pueda comprarlo.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          if (_submitting)
            const Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _respond(false),
                  child: const Text('Rechazar y cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () => _respond(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Acepto el nuevo precio'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
