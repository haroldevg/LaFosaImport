import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

/// The customer's own data: the name the staff will see on their orders and
/// the WhatsApp used to coordinate payment and delivery. The email comes from
/// the Google account and isn't editable here.
///
/// Pops with `true` once the profile was saved, so a caller that sent the
/// user here to complete a missing number can tell whether to retry.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = AuthService.instance.currentUser!;
    try {
      final profile = await ProfileService.instance.fetchProfile(user.uid);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nameCtrl.text = (profile?.displayName.isNotEmpty ?? false)
            ? profile!.displayName
            : (user.displayName ?? '');
        _phoneCtrl.text = profile?.whatsappNationalDigits ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar tu perfil: $e';
      });
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ProfileService.instance.updateProfile(
        uid: AuthService.instance.currentUser!.uid,
        displayName: _nameCtrl.text.trim(),
        whatsapp: toPeruE164(peruMobileDigits(_phoneCtrl.text)),
      );
      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Perfil actualizado.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser!;
    final photoUrl = _profile?.photoUrl ?? user.photoURL;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage:
                            (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        user.email ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        helperText: 'Así te identifica el staff en tus pedidos.',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      // Digits only, with room for a pasted "51…" that
                      // peruMobileDigits then strips back to nine.
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp',
                        prefixText: '$peruDialCode ',
                        hintText: '987654321',
                        helperText:
                            'Solo Perú: 9 dígitos que empiezan con 9. '
                            'El $peruDialCode se agrega solo.',
                      ),
                      validator: (v) {
                        final digits = peruMobileDigits(v ?? '');
                        if (digits.isEmpty) return 'Requerido';
                        if (!isValidPeruMobile(digits)) {
                          return 'Debe tener 9 dígitos y empezar con 9';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Necesitamos tu WhatsApp para coordinar el pago y la '
                      'entrega de tu pedido.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
