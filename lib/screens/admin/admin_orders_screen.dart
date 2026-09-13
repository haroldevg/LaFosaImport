import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/order_export_service.dart';
import '../../services/order_service.dart';
import '../../widgets/order_summary_card.dart';
import 'edit_order_prices_screen.dart';

/// The two Excel reports the panel can produce: what still has to be bought,
/// and what was already bought and has to be delivered.
enum _ExportKind { pending, purchased }

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  static const _pageSize = 100;

  bool _exporting = false;
  bool _togglingIntake = false;
  int _limit = _pageSize;

  /// Opens or closes the convocatoria for every non-admin user. Closing is
  /// confirmed first: it takes effect live and drops everyone who isn't an
  /// admin onto the closed screen mid-session.
  Future<void> _setIntakeOpen(bool open) async {
    if (!open) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cerrar la convocatoria'),
          content: const Text(
            'Los clientes dejarán de poder crear pedidos de inmediato y verán '
            'la pantalla de cierre. Los pedidos ya enviados siguen su curso y '
            'pueden seguir consultándolos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cerrar convocatoria'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _togglingIntake = true);
    try {
      await OrderService.instance.setAppClosed(!open);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            open
                ? 'Convocatoria abierta: los clientes ya pueden pedir.'
                : 'Convocatoria cerrada para los clientes.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cambiar: $e')));
    } finally {
      if (mounted) setState(() => _togglingIntake = false);
    }
  }

  Future<void> _changeStatus(BuildContext context, CardOrder order) async {
    final newStatus = await showDialog<OrderStatus>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Cambiar estado — ${order.items.length} carta(s)'),
        children: OrderStatus.values
            // "Ajuste de precio" isn't a state to be set by hand: it's what
            // saving new prices in EditOrderPricesScreen puts the order in,
            // waiting on the customer to approve them from the app.
            .where((s) => s != OrderStatus.priceReview)
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

    // Buying an order whose reprice the customer hasn't answered yet is
    // exactly what this flow exists to prevent, so make it deliberate.
    if (order.awaitsPriceConfirmation && newStatus == OrderStatus.ordered) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sin conformidad del cliente'),
          content: Text(
            '${order.userDisplayName} todavía no confirmó el precio ajustado. '
            '¿Marcar como comprado igual?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Esperar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Comprar igual'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

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

  Future<void> _editPrices(BuildContext context, CardOrder order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditOrderPricesScreen(order: order)),
    );
  }

  /// Runs one of the Excel reports, reporting "nothing to export" as a message
  /// rather than an error — an empty report is a normal answer, not a failure.
  Future<void> _runExport(
    Future<int> Function() export, {
    required String emptyMessage,
  }) async {
    setState(() => _exporting = true);
    try {
      final count = await export();
      if (!mounted) return;
      if (count == 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(emptyMessage)));
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

  /// The convocatoria switch, pinned above the list so its current state is
  /// visible at a glance instead of hidden behind an icon — this is what
  /// decides whether every non-admin user sees the app or the closed screen.
  Widget _buildIntakeToggle() {
    return StreamBuilder<bool>(
      stream: OrderService.instance.appClosed(),
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final closed = snap.data ?? false;
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SwitchListTile(
            value: !closed,
            onChanged: (loading || _togglingIntake) ? null : _setIntakeOpen,
            secondary: _togglingIntake
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(closed ? Icons.lock_outline : Icons.lock_open_outlined),
            title: Text(
              loading
                  ? 'Cargando convocatoria…'
                  : (closed ? 'Convocatoria cerrada' : 'Convocatoria abierta'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              closed
                  ? 'Los clientes ven la pantalla de cierre y solo pueden '
                        'consultar sus pedidos.'
                  : 'Los clientes pueden crear pedidos nuevos.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CardOrder>>(
      stream: OrderService.instance.allOrders(limit: _limit),
      builder: (context, snap) {
        final orders = snap.data ?? [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Panel admin — Pedidos'),
            actions: [
              PopupMenuButton<_ExportKind>(
                icon: _exporting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                tooltip: 'Exportar a Excel',
                enabled: !_exporting,
                // Both reports fetch every matching order directly, on
                // demand — never from the (capped) list already on screen,
                // so an old pending order that scrolled past the limit is
                // never silently left off.
                onSelected: (kind) => switch (kind) {
                  _ExportKind.pending => _runExport(
                    () async => OrderExportService.instance.exportPendingOrders(
                      await OrderService.instance.ordersReadyToBuy(),
                    ),
                    emptyMessage: 'No hay pedidos pendientes por exportar.',
                  ),
                  _ExportKind.purchased => _runExport(
                    () async =>
                        OrderExportService.instance.exportPurchasedOrders(
                          await OrderService.instance.purchasedOrders(),
                        ),
                    emptyMessage: 'No hay pedidos comprados por entregar.',
                  ),
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ExportKind.pending,
                    child: ListTile(
                      leading: Icon(Icons.shopping_cart_outlined),
                      title: Text('Pendientes por comprar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _ExportKind.purchased,
                    child: ListTile(
                      leading: Icon(Icons.local_shipping_outlined),
                      title: Text('Comprados por entregar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _buildIntakeToggle(),
                Expanded(
                  child: snap.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : orders.isEmpty
                      ? const Center(child: Text('No hay pedidos todavía.'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          // orders.length == _limit means there may be older
                          // orders this page doesn't include yet — offer to
                          // load another page rather than silently hiding them.
                          itemCount:
                              orders.length + (orders.length >= _limit ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == orders.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () =>
                                        setState(() => _limit += _pageSize),
                                    child: const Text('Cargar más'),
                                  ),
                                ),
                              );
                            }
                            final order = orders[i];
                            return OrderSummaryCard(
                              order: order,
                              showRequester: true,
                              trailing: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (order.status.isActive)
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _editPrices(context, order),
                                      icon: const Icon(
                                        Icons.price_change_outlined,
                                      ),
                                      label: const Text('Editar precios'),
                                    ),
                                  OutlinedButton(
                                    onPressed: () =>
                                        _changeStatus(context, order),
                                    child: const Text('Cambiar estado'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
