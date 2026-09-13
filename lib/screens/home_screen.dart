import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart' show routeObserver;
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../widgets/app_version_badge.dart';
import '../widgets/order_summary_card.dart';
import 'admin/admin_orders_screen.dart';
import 'new_order_screen.dart';
import 'order_history_screen.dart';

/// [isAdmin] is resolved once by the caller (see `_AccessGate` in main.dart)
/// rather than re-queried here — this screen used to run its own separate
/// `isAdmin` listener for the same value the access gate already has.
///
/// The active-order listener is managed by hand (not a plain `StreamBuilder`)
/// so it can pause via [RouteAware] whenever another screen — "Mis pedidos",
/// "Nuevo pedido", the admin panel — gets pushed on top: `Navigator.push`
/// keeps this screen alive underneath, so a `StreamBuilder` would otherwise
/// keep listening to data nobody can see, right alongside whatever the
/// screen on top is already fetching for the same order.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  StreamSubscription<CardOrder?>? _subscription;
  CardOrder? _activeOrder;
  bool _loading = true;
  bool _routeSubscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies can fire more than once (e.g. a system theme
    // change) — only register with the route observer the first time.
    if (!_routeSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<void>) {
        routeObserver.subscribe(this, route);
        _routeSubscribed = true;
      }
    }
    _subscribe();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _subscription?.cancel();
    super.dispose();
  }

  // RouteAware: another screen was pushed on top of this one — it's no
  // longer visible, so stop listening until we're back on top.
  @override
  void didPushNext() => _unsubscribe();

  // RouteAware: back on top again (the screen pushed over us was popped).
  @override
  void didPopNext() => _subscribe();

  void _subscribe() {
    if (_subscription != null) return;
    final uid = AuthService.instance.currentUser!.uid;
    setState(() => _loading = true);
    _subscription = OrderService.instance.activeOrder(uid).listen((order) {
      if (!mounted) return;
      setState(() {
        _activeOrder = order;
        _loading = false;
      });
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
        title: const Text('La Fosa Store'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Panel admin',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => AuthService.instance.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildBody(context)),
            const Positioned(bottom: 8, right: 12, child: AppVersionBadge()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final activeOrder = _activeOrder;
    if (activeOrder == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No tienes ningún pedido activo.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nuevo pedido'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NewOrderScreen(isAdmin: widget.isAdmin),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Tu pedido activo:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        OrderSummaryCard(order: activeOrder),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No puedes crear un nuevo pedido hasta que este sea entregado.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
