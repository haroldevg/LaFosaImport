import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

// No explicit locale: the app never calls initializeDateFormatting, so only
// the default locale's symbols are loaded. A numeric pattern reads the same
// either way (same choice as OrderExportService).
final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

/// The customer's own data: the name the staff will see on their orders and
/// the WhatsApp used to coordinate payment and delivery. The email comes from
/// the Google account and isn't editable here.
///
/// Both editable fields are rate-limited to one change every
/// [profileEditCooldown] — the staff works off them, so they can't change
/// under their feet. The same window is enforced by the security rules; this
/// screen just makes the wait visible instead of letting someone hit a
/// permission error.
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

  bool get _canEdit => _profile?.canEditNow ?? true;

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

    final digits = peruMobileDigits(_phoneCtrl.text);
    // Warn before, not after: one save locks both fields for a day, and a
    // typo in the number would leave the customer unable to order until the
    // cooldown passes.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar tus datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre: ${_nameCtrl.text.trim()}'),
            Text('WhatsApp: ${prettyPeruNumber(toPeruE164(digits))}'),
            const SizedBox(height: 12),
            const Text(
              'Revisa que el número esté correcto: solo podrás volver a '
              'editar estos datos dentro de 24 horas.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ProfileService.instance.updateProfile(
        uid: AuthService.instance.currentUser!.uid,
        displayName: _nameCtrl.text.trim(),
        whatsapp: toPeruE164(digits),
      );
      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Perfil actualizado. Podrás volver a editarlo en 24 horas.',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      // The rules enforce the same window server-side; landing here means
      // this screen's copy of the profile was out of date (another device,
      // or a clock that disagrees).
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.code == 'permission-denied'
            ? 'Ya editaste tus datos hace poco. Intenta de nuevo más tarde.'
            : 'No se pudo guardar: ${e.message ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar: $e';
      });
    }
  }

  Widget _buildCooldownNotice(BuildContext context) {
    final profile = _profile!;
    final scheme = Theme.of(context).colorScheme;
    final next = profile.nextEditAllowedAt!;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.lock_clock, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ya actualizaste tus datos. Podrás volver a editarlos en '
                '${formatCooldownRemaining(profile.remainingCooldown)} '
                '(el ${_dateFmt.format(next)}).',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
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
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        'El correo no se puede modificar: viene de tu cuenta '
                        'de Google.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!_canEdit) ...[
                      _buildCooldownNotice(context),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _nameCtrl,
                      enabled: _canEdit,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        helperText:
                            'Así te identifica el staff en tus pedidos.',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneCtrl,
                      enabled: _canEdit,
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
                      'entrega de tu pedido. Solo se puede cambiar una vez '
                      'cada 24 horas.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: (_saving || !_canEdit) ? null : _save,
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
