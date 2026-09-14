import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

/// Thrown by [ProfileService.updateProfile] when the name is blank or the
/// WhatsApp isn't a valid Peruvian mobile. The form catches these before they
/// happen; this is the guard that keeps a blank or whitespace-only number
/// from ever reaching Firestore through some other path.
class InvalidProfileException implements Exception {
  InvalidProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads and writes the customer's own `users/{uid}` document — the editable
/// half of it (name and WhatsApp). The `activeOrderId` lock living in the
/// same document is owned by [OrderService] and never touched from here; the
/// security rules reject any write from the owner that includes it.
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final _db = FirebaseFirestore.instance;

  Stream<UserProfile?> profile(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromDoc(doc) : null);
  }

  Future<UserProfile?> fetchProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserProfile.fromDoc(doc) : null;
  }

  /// Both fields are required and normalized here rather than by the caller,
  /// so this is the single place where what lands in Firestore is decided:
  /// the name trimmed and non-empty, the number as `+51XXXXXXXXX`.
  /// [whatsapp] is accepted in any shape the customer might type or paste —
  /// with spaces, with `+51`, with `51` — and is rejected outright if what's
  /// left isn't a nine-digit Peruvian mobile.
  ///
  /// Merged rather than overwritten so the profile fields Google fills in —
  /// and the order lock — survive the edit.
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String whatsapp,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw InvalidProfileException('El nombre no puede estar vacío.');
    }
    final digits = peruMobileDigits(whatsapp);
    if (!isValidPeruMobile(digits)) {
      throw InvalidProfileException(
        'El WhatsApp debe tener 9 dígitos y empezar con 9.',
      );
    }

    await _db.collection('users').doc(uid).set({
      'displayName': name,
      'whatsapp': toPeruE164(digits),
      'profileUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
