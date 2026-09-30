import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/user_profile.dart';
import 'screens/app_closed_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/terms_screen.dart';
import 'services/auth_service.dart';
import 'services/order_service.dart';
import 'services/profile_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService.instance.init();
  runApp(const MyApp());
}

/// Lets a screen pushed on top (e.g. "Mis pedidos") tell [HomeScreen] to
/// pause its active-order listener while it's hidden underneath, instead of
/// two Firestore listeners running at once for data one of them already has.
final RouteObserver<PageRoute<void>> routeObserver =
    RouteObserver<PageRoute<void>>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'La Fosa Store',
      theme: buildAppTheme(),
      navigatorObservers: [routeObserver],
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data == null
            ? const LoginScreen()
            : _AccessGate(uid: snap.data!.uid);
      },
    );
  }
}

/// Sits between login and [HomeScreen]. First barrier: nobody gets in without
/// having accepted the current terms. After that, admins always get the app;
/// everyone else sees [AppClosedScreen] while `config/settings.closed` is
/// true.
class _AccessGate extends StatefulWidget {
  const _AccessGate({required this.uid});

  final String uid;

  @override
  State<_AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<_AccessGate> {
  // Created once per uid instead of inline in build(): the profile doc is
  // rewritten on every order (activeOrderId), lock release, or profile save,
  // and re-creating these streams on each of those emissions would drop the
  // isAdmin/appClosed subscriptions, flash the loading spinner, and tear down
  // HomeScreen's state along with it.
  late Stream<UserProfile?> _profileStream;
  late Stream<bool> _isAdminStream;
  late Stream<bool> _appClosedStream;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_AccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _subscribe();
  }

  void _subscribe() {
    _profileStream = ProfileService.instance.profile(widget.uid);
    _isAdminStream = OrderService.instance.isAdmin(widget.uid);
    _appClosedStream = OrderService.instance.appClosed();
  }

  @override
  Widget build(BuildContext context) {
    // Nadie —cliente o admin— pasa de aquí sin una aceptación registrada de
    // la versión vigente de los términos. Publicar un texto nuevo (subir
    // termsVersion) vuelve a levantar esta barrera para todos.
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, profileSnap) {
        if (profileSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!(profileSnap.data?.hasAcceptedCurrentTerms ?? false)) {
          return const TermsScreen(requireAcceptance: true);
        }
        return _buildForAcceptedUser(context);
      },
    );
  }

  Widget _buildForAcceptedUser(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _isAdminStream,
      builder: (context, adminSnap) {
        if (adminSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (adminSnap.data == true) {
          return const HomeScreen(isAdmin: true);
        }

        return StreamBuilder<bool>(
          stream: _appClosedStream,
          builder: (context, closedSnap) {
            if (closedSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return closedSnap.data == true
                ? const AppClosedScreen()
                : const HomeScreen(isAdmin: false);
          },
        );
      },
    );
  }
}
