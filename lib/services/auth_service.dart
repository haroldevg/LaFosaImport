import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// The "Web client (auto created by Google Service)" OAuth client id from
/// Firebase — required on web only (Android/iOS auto-detect it from
/// google-services.json / GoogleService-Info.plist). OAuth client ids are not
/// secrets; they're meant to be embedded in client-side code.
const _webGoogleClientId =
    '656679731995-mokk1napdq8jt0qsnc69assndmv8rvpv.apps.googleusercontent.com';

/// Wraps Google Sign-In (v7, event-based API) + Firebase Auth.
///
/// Firebase Auth is the source of truth for "is the user logged in" — its own
/// session persists across app restarts. GoogleSignIn is only used to obtain a
/// fresh Google ID token when the user explicitly signs in; every sign-in
/// event it emits (whether triggered by the mobile `authenticate()` call or by
/// the rendered web button) is forwarded here to exchange it for a Firebase
/// credential.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _eventSub;
  bool _initialized = false;

  Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();

  User? get currentUser => FirebaseAuth.instance.currentUser;

  bool get supportsExplicitAuthenticate => _googleSignIn.supportsAuthenticate();

  Future<void> init() async {
    if (_initialized) return;
    await _googleSignIn.initialize(
      clientId: kIsWeb ? _webGoogleClientId : null,
    );
    _eventSub = _googleSignIn.authenticationEvents.listen(
      _onAuthenticationEvent,
      onError: (Object e) {
        // Swallow here; UI-level sign-in actions surface their own errors.
      },
    );
    _initialized = true;
  }

  Future<void> _onAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        final idToken = event.user.authentication.idToken;
        if (idToken != null) {
          final credential = GoogleAuthProvider.credential(idToken: idToken);
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          await _syncUserProfile(userCredential.user);
        }
      case GoogleSignInAuthenticationEventSignOut():
        // GoogleSignIn-side sign-out; Firebase sign-out is driven separately
        // by signOut() below so we don't fight user-initiated flows.
        break;
    }
  }

  Future<void> _syncUserProfile(User? user) async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoURL,
    }, SetOptions(merge: true));
  }

  /// Triggers the mobile/desktop explicit sign-in flow. On web, use the
  /// rendered Google button (see google_sign_in_web_button.dart) instead —
  /// check [supportsExplicitAuthenticate] first.
  Future<void> signInWithGoogle() async {
    await _googleSignIn.authenticate();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Not fatal — Firebase sign-out already happened.
    }
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
  }
}
