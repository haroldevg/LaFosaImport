import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../widgets/app_version_badge.dart';
import '../widgets/order_summary_card.dart';
import '../widgets/whatsapp_reminder_banner.dart';
import 'admin/admin_orders_screen.dart';
import 'new_order_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser!.uid;
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
          StreamBuilder<bool>(
            stream: OrderService.instance.isAdmin(uid),
            builder: (context, snap) {
              if (snap.data != true) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                tooltip: 'Panel admin',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mi perfil',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
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
            Positioned.fill(
              child: Column(
                children: [
                  const WhatsappReminderBanner(),
                  Expanded(
                    child: StreamBuilder<CardOrder?>(
                      stream: OrderService.instance.activeOrder(uid),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final activeOrder = snap.data;
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
                                        builder: (_) => const NewOrderScreen(),
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
                                'No puedes crear un nuevo pedido hasta que este '
                                'sea entregado.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(bottom: 8, right: 12, child: AppVersionBadge()),
          ],
        ),
      ),
    );
  }
}
