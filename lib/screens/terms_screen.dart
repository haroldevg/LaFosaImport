import 'package:flutter/material.dart';

import '../legal/terms.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme.dart';

/// Los Términos y Condiciones / Política de Privacidad, en dos modos:
///
/// * lectura (`requireAcceptance: false`), accesible desde el login antes de
///   registrarse y desde el perfil en cualquier momento;
/// * aceptación (`requireAcceptance: true`), que es la barrera que se
///   interpone entre el usuario registrado y el resto de la aplicación
///   mientras no haya aceptado la versión vigente.
///
/// En modo aceptación no hay botón de retroceso: las únicas salidas son
/// aceptar o cerrar sesión, para que quedar dentro de la app implique siempre
/// una aceptación registrada.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, this.requireAcceptance = false});

  final bool requireAcceptance;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepting = false;
  bool _checked = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      await ProfileService.instance.acceptTerms(
        AuthService.instance.currentUser!.uid,
      );
      // El gate de main.dart escucha el perfil: al quedar registrada la
      // aceptación deja pasar solo, sin necesidad de navegar desde aquí.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = 'No se pudo registrar tu aceptación: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<LaFosaColors>()!;
    return PopScope(
      // En modo aceptación, el botón atrás del sistema no puede saltarse la
      // barrera; en modo lectura se comporta con normalidad.
      canPop: !widget.requireAcceptance,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Términos y Condiciones'),
          automaticallyImplyLeading: !widget.requireAcceptance,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  children: [
                    Text(
                      'Términos y Condiciones de Uso\ny Política de Privacidad',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: brand.violet,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Versión $termsVersion · Vigente desde el '
                      '$termsEffectiveDate',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text(termsIntro, style: const TextStyle(height: 1.5)),
                    const SizedBox(height: 8),
                    for (final section in termsSections) ...[
                      const SizedBox(height: 20),
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final paragraph in section.paragraphs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            paragraph,
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              if (widget.requireAcceptance) _buildAcceptanceBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptanceBar(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              value: _checked,
              onChanged: _accepting
                  ? null
                  : (v) => setState(() => _checked = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'He leído y acepto los Términos y Condiciones y el '
                'tratamiento de mis datos personales descrito en la Política '
                'de Privacidad.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                TextButton(
                  onPressed: _accepting
                      ? null
                      : () => AuthService.instance.signOut(),
                  child: const Text('Cerrar sesión'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: (!_checked || _accepting) ? null : _accept,
                    child: _accepting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Acepto'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
