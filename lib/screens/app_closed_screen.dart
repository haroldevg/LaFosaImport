import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'order_history_screen.dart';

/// Shown to signed-in non-admin users instead of [HomeScreen] while
/// `config/settings.closed` is true in Firestore — e.g. once a promotional
/// intake period ends. Admins are never gated by this screen. Users can't
/// start a new order from here, but can still view the ones they already
/// placed via [OrderHistoryScreen].
class AppClosedScreen extends StatelessWidget {
  const AppClosedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<LaFosaColors>()!;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: brand.violet.withValues(alpha: 0.45),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.style, size: 72, color: brand.violet),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Gracias por participar de la convocatoria.\n'
                'Estar atento a nuestras redes sociales.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                ),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Ver mis pedidos'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => AuthService.instance.signOut(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
