import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../widgets/order_summary_card.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pedidos')),
      body: SafeArea(
        child: StreamBuilder<List<CardOrder>>(
          stream: OrderService.instance.orderHistory(uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snap.data ?? [];
            if (orders.isEmpty) {
              return const Center(child: Text('Todavía no tienes pedidos.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: orders.length,
              itemBuilder: (context, i) => OrderSummaryCard(order: orders[i]),
            );
          },
        ),
      ),
    );
  }
}
