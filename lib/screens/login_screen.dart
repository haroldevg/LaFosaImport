import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../services/google_sign_in_web_button.dart';
import '../theme.dart';
import '../widgets/app_version_badge.dart';
import 'terms_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _error;
  bool _signingIn = false;

  /// Consentimiento previo: la Ley N.° 29733 pide que sea previo, expreso e
  /// informado, así que el ingreso queda deshabilitado hasta marcarlo, con el
  /// texto completo a un toque de distancia. La aceptación que queda
  /// registrada en el servidor es la de la pantalla posterior al ingreso
  /// (ver `_AccessGate`); esta casilla es la del momento del registro.
  bool _acceptedTerms = false;

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

  Widget _buildTermsConsent(BuildContext context) {
    final brand = Theme.of(context).extension<LaFosaColors>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _acceptedTerms,
          onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'He leído y acepto los ',
                  style: TextStyle(fontSize: 13),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  ),
                  child: Text(
                    'Términos y Condiciones',
                    style: TextStyle(
                      fontSize: 13,
                      color: brand.violet,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: brand.violet,
                    ),
                  ),
                ),
                const Text(
                  ' y el tratamiento de mis datos personales.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _buildTermsConsent(context),
                    ),
                    const SizedBox(height: 16),
                    if (_signingIn)
                      const CircularProgressIndicator()
                    else if (AuthService.instance.supportsExplicitAuthenticate)
                      ElevatedButton.icon(
                        onPressed: _acceptedTerms ? _signIn : null,
                        icon: const Icon(Icons.login),
                        label: const Text('Iniciar sesión con Google'),
                      )
                    else if (kIsWeb)
                      // El botón de Google en web lo dibuja su propio SDK y no
                      // admite un estado deshabilitado: se bloquea desde
                      // afuera hasta que la casilla esté marcada.
                      Opacity(
                        opacity: _acceptedTerms ? 1 : 0.4,
                        child: IgnorePointer(
                          ignoring: !_acceptedTerms,
                          child: renderGoogleSignInButton(),
                        ),
                      )
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
