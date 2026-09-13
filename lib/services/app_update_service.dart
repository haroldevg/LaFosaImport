import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Gates order submission on a minimum app version, so a breaking change to
/// the order flow (a field the server side now expects, a pricing rule the
/// old client would compute wrong) can be rolled out without stale clients —
/// especially the web build, whose users can be stuck on a cached old bundle
/// — silently submitting orders it shouldn't.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  final _db = FirebaseFirestore.instance;

  /// The running app's own version, as declared by `version:` in
  /// pubspec.yaml (the build number after the `+` is not part of this).
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// The lowest app version still allowed to submit orders, set by staff at
  /// `config/settings.minAppVersion` in Firestore. Null (field or document
  /// absent) means no minimum is enforced.
  Future<String?> minRequiredVersion() async {
    final doc = await _db.collection('config').doc('settings').get();
    final value = doc.data()?['minAppVersion'] as String?;
    return (value == null || value.trim().isEmpty) ? null : value.trim();
  }

  /// Whether the running app is allowed to submit orders right now. Never
  /// throws — a network hiccup or a malformed version string on either side
  /// fails open, since this is a rollout guard, not a security boundary.
  Future<bool> canSubmitOrders() async {
    try {
      final minVersion = await minRequiredVersion();
      if (minVersion == null) return true;
      final current = await currentVersion();
      return compareVersions(current, minVersion) >= 0;
    } catch (_) {
      return true;
    }
  }

  /// Compares two `major.minor.patch`-style version strings numerically
  /// (never as plain text — "1.9.0" must count as older than "1.10.0", which
  /// a string comparison gets backwards). Returns <0, 0 or >0 the way
  /// [Comparable.compareTo] does. Missing or non-numeric segments read as 0,
  /// so "1.2" and "1.2.0" compare equal.
  static int compareVersions(String a, String b) {
    final partsA = a.split('.');
    final partsB = b.split('.');
    final length = partsA.length > partsB.length
        ? partsA.length
        : partsB.length;
    for (var i = 0; i < length; i++) {
      final segA = i < partsA.length ? (int.tryParse(partsA[i]) ?? 0) : 0;
      final segB = i < partsB.length ? (int.tryParse(partsB[i]) ?? 0) : 0;
      if (segA != segB) return segA.compareTo(segB);
    }
    return 0;
  }
}
