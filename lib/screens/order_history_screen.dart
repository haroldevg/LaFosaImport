import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../widgets/order_summary_card.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  static const _pageSize = 30;

  int _limit = _pageSize;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pedidos')),
      body: SafeArea(
        child: StreamBuilder<List<CardOrder>>(
          stream: OrderService.instance.orderHistory(uid, limit: _limit),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snap.data ?? [];
            if (orders.isEmpty) {
              return const Center(child: Text('Todavía no tienes pedidos.'));
            }
            // orders.length == _limit means there may be older orders this
            // page doesn't include yet — offer to load another page rather
            // than silently hiding them.
            final hasMore = orders.length >= _limit;
            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: orders.length + (hasMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == orders.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: TextButton(
                        onPressed: () => setState(() => _limit += _pageSize),
                        child: const Text('Cargar más'),
                      ),
                    ),
                  );
                }
                return OrderSummaryCard(order: orders[i]);
              },
            );
          },
        ),
      ),
    );
  }
}
