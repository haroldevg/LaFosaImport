import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../screens/profile_screen.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

/// Nudges the customer to register their WhatsApp before they build a cart —
/// creating an order without one is refused, and finding that out at the end,
/// with the cart already full, is a bad way to learn it. Renders nothing once
/// the number is set.
class WhatsappReminderBanner extends StatelessWidget {
  const WhatsappReminderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<UserProfile?>(
      stream: ProfileService.instance.profile(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snap.data?.hasWhatsapp ?? false) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          color: scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Falta tu número de WhatsApp. Regístralo para poder '
                    'enviar pedidos: lo usamos para coordinar el pago y la '
                    'entrega.',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  child: const Text('Completar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
