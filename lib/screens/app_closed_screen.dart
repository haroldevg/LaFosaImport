import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/app_version_badge.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';

/// Shown to signed-in non-admin users instead of [HomeScreen] while
/// `config/settings.closed` is true in Firestore — e.g. once a promotional
/// intake period ends. The flag is toggled live from the admin panel's
/// "Convocatoria" switch. Admins are never gated by this screen. Users can't
/// start a new order from here, but can still view the ones they already
/// placed via [OrderHistoryScreen].
class AppClosedScreen extends StatelessWidget {
  const AppClosedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<LaFosaColors>()!;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingLogoGlow(brand: brand),
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
                        MaterialPageRoute(
                          builder: (_) => const OrderHistoryScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Ver mis pedidos'),
                    ),
                    const SizedBox(height: 12),
                    // Reachable from here too: a WhatsApp number is required
                    // to order, so people should be able to register or fix
                    // one while the convocatoria is closed — otherwise they
                    // only find out they can't order once it reopens.
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      ),
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Mi perfil'),
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
          ),
          const Positioned(bottom: 8, right: 12, child: AppVersionBadge()),
        ],
      ),
    );
  }
}

/// The logo's violet glow, breathing in and out on a loop — draws the eye to
/// the one thing on this screen without anything to click, instead of the
/// static glow every other screen already uses.
class _PulsingLogoGlow extends StatefulWidget {
  const _PulsingLogoGlow({required this.brand});

  final LaFosaColors brand;

  @override
  State<_PulsingLogoGlow> createState() => _PulsingLogoGlowState();
}

class _PulsingLogoGlowState extends State<_PulsingLogoGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: 148,
          height: 148,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.brand.violet.withValues(
                  alpha: lerpDouble(0.35, 0.7, t)!,
                ),
                blurRadius: lerpDouble(32, 62, t)!,
                spreadRadius: lerpDouble(2, 10, t)!,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.style, size: 72, color: widget.brand.violet),
      ),
    );
  }
}
