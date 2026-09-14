import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

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

  /// [whatsapp] is expected already normalized to `+51XXXXXXXXX`
  /// (see [toPeruE164]). Merged rather than overwritten so the profile fields
  /// Google fills in — and the order lock — survive the edit.
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String whatsapp,
  }) async {
    await _db.collection('users').doc(uid).set({
      'displayName': displayName,
      'whatsapp': whatsapp,
      'profileUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
