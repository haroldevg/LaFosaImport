import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/app_closed_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/order_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'La Fosa Store',
      theme: buildAppTheme(),
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

/// Sits between login and [HomeScreen]: admins always get the app; everyone
/// else sees [AppClosedScreen] while `config/settings.closed` is true.
class _AccessGate extends StatelessWidget {
  const _AccessGate({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OrderService.instance.isAdmin(uid),
      builder: (context, adminSnap) {
        if (adminSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (adminSnap.data == true) return const HomeScreen();

        return StreamBuilder<bool>(
          stream: OrderService.instance.appClosed(),
          builder: (context, closedSnap) {
            if (closedSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return closedSnap.data == true
                ? const AppClosedScreen()
                : const HomeScreen();
          },
        );
      },
    );
  }
}
