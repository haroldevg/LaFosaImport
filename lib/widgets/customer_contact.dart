import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

/// Who placed the order and how to reach them, for the staff only: the
/// customer's name plus a tap-to-chat WhatsApp link (`wa.me`), which opens the
/// app on Android/iOS and a new tab on web.
///
/// The number normally travels on the order itself, copied there when it was
/// placed. Orders from before WhatsApp was required don't carry one, so for
/// those — and only those — the current number is looked up from the
/// customer's profile, which admins are allowed to read.
class CustomerContact extends StatelessWidget {
  const CustomerContact({super.key, required this.order});

  final CardOrder order;

  Future<void> _openChat(BuildContext context, String number) async {
    final url = whatsappChatUrl(number);
    if (url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        messenger.showSnackBar(
          SnackBar(content: Text('No se pudo abrir WhatsApp ($number).')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo abrir WhatsApp: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_outline, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                order.userDisplayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (order.userWhatsapp.isNotEmpty)
          _WhatsappLink(
            number: order.userWhatsapp,
            onTap: () => _openChat(context, order.userWhatsapp),
          )
        else
          FutureBuilder<UserProfile?>(
            future: ProfileService.instance.fetchProfile(order.userId),
            builder: (context, snap) {
              final number = snap.data?.whatsapp ?? '';
              if (number.isEmpty) {
                return const Text(
                  'Sin WhatsApp registrado',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                );
              }
              return _WhatsappLink(
                number: number,
                onTap: () => _openChat(context, number),
              );
            },
          ),
      ],
    );
  }
}

class _WhatsappLink extends StatelessWidget {
  const _WhatsappLink({required this.number, required this.onTap});

  final String number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const whatsappGreen = Color(0xFF25D366);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: whatsappGreen,
              ),
              const SizedBox(width: 6),
              Text(
                prettyPeruNumber(number),
                style: const TextStyle(
                  color: whatsappGreen,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: whatsappGreen,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_new, size: 13, color: whatsappGreen),
            ],
          ),
        ),
      ),
    );
  }
}
