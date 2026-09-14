import 'package:cloud_firestore/cloud_firestore.dart';

/// Peru's country calling code. The store only imports into Peru, so every
/// WhatsApp number is stored with this prefix and the customer only ever
/// types the nine national digits.
const peruDialCode = '+51';

/// Keeps only the digits of whatever was typed or pasted, and drops a leading
/// country code — so "+51 987 654 321", "51987654321" and "987654321" all end
/// up as the same nine digits.
String peruMobileDigits(String input) {
  var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length > 9 && digits.startsWith('51')) {
    digits = digits.substring(2);
  }
  return digits;
}

/// Peruvian mobile lines — the only ones that can have WhatsApp — are nine
/// digits long and always start with 9.
bool isValidPeruMobile(String digits) =>
    digits.length == 9 && digits.startsWith('9');

/// The nine national [digits] as a full international number.
String toPeruE164(String digits) => '$peruDialCode$digits';

/// Click-to-chat link for a stored number, or null when there's nothing to
/// call. WhatsApp wants the full international number with no plus sign or
/// separators; numbers saved before the `+51` prefix existed are assumed
/// Peruvian and get the country code added.
String? whatsappChatUrl(String storedNumber) {
  final digits = storedNumber.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  final international = digits.length == 9 ? '51$digits' : digits;
  return 'https://wa.me/$international';
}

/// A stored number as `+51 987 654 321` — grouped in threes so it can be read
/// off the screen out loud. Anything that isn't a nine-digit Peruvian mobile
/// is returned untouched rather than mangled into the wrong shape.
String prettyPeruNumber(String storedNumber) {
  final national = peruMobileDigits(storedNumber);
  if (national.length != 9) return storedNumber;
  return '$peruDialCode ${national.substring(0, 3)} '
      '${national.substring(3, 6)} ${national.substring(6)}';
}

/// The `users/{uid}` document: what Google gave us at sign-in plus whatever
/// the customer edited themselves on the profile screen.
class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  /// Full international number (`+51XXXXXXXXX`), or empty when the customer
  /// hasn't registered one yet — which is what blocks placing an order.
  final String whatsapp;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.whatsapp,
    this.photoUrl,
  });

  bool get hasWhatsapp => whatsapp.isNotEmpty;

  /// Just the nine national digits, for prefilling the input that renders
  /// `+51` as a fixed prefix.
  String get whatsappNationalDigits => peruMobileDigits(whatsapp);

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      whatsapp: data['whatsapp'] as String? ?? '',
    );
  }
}
