import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../services/google_sign_in_web_button.dart';
import '../theme.dart';
import '../widgets/app_version_badge.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _error;
  bool _signingIn = false;

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        setState(
          () =>
              _error = 'No se pudo iniciar sesión: ${e.description ?? e.code}',
        );
      }
    } catch (e) {
      setState(() => _error = 'No se pudo iniciar sesión: $e');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

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
                    Container(
                      width: 148,
                      height: 148,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: brand.violet.withValues(alpha: 0.45),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.style, size: 72, color: brand.violet),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'LA FOSA STORE',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Inicia sesión para solicitar tus cartas.'),
                    const SizedBox(height: 32),
                    if (_signingIn)
                      const CircularProgressIndicator()
                    else if (AuthService.instance.supportsExplicitAuthenticate)
                      ElevatedButton.icon(
                        onPressed: _signIn,
                        icon: const Icon(Icons.login),
                        label: const Text('Iniciar sesión con Google'),
                      )
                    else if (kIsWeb)
                      renderGoogleSignInButton()
                    else
                      const Text(
                        'Este dispositivo no soporta el inicio de sesión con Google.',
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
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
