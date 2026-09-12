import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/order_export_service.dart';
import '../../services/order_service.dart';
import '../../widgets/order_summary_card.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  bool _exporting = false;

  Future<void> _changeStatus(BuildContext context, CardOrder order) async {
    final newStatus = await showDialog<OrderStatus>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Cambiar estado — ${order.items.length} carta(s)'),
        children: OrderStatus.values
            .map(
              (s) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(s),
                child: Text(s.label),
              ),
            )
            .toList(),
      ),
    );
    if (newStatus == null || newStatus == order.status) return;
    try {
      await OrderService.instance.updateOrderStatus(order.id, newStatus);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
      }
    }
  }

  Future<void> _exportPending(List<CardOrder> orders) async {
    setState(() => _exporting = true);
    try {
      final count = await OrderExportService.instance.exportPendingOrders(
        orders,
      );
      if (!mounted) return;
      if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay pedidos pendientes por exportar.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CardOrder>>(
      stream: OrderService.instance.allOrders(),
      builder: (context, snap) {
        final orders = snap.data ?? [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Panel admin — Pedidos'),
            actions: [
              IconButton(
                icon: _exporting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                tooltip: 'Exportar pendientes a Excel',
                onPressed: _exporting ? null : () => _exportPending(orders),
              ),
            ],
          ),
          body: SafeArea(
            child: snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                ? const Center(child: Text('No hay pedidos todavía.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    itemCount: orders.length,
                    itemBuilder: (context, i) {
                      final order = orders[i];
                      return OrderSummaryCard(
                        order: order,
                        showRequester: true,
                        trailing: Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: () => _changeStatus(context, order),
                            child: const Text('Cambiar estado'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
