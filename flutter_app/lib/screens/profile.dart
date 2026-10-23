import 'package:flutter/material.dart';

import '../core/password.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/inputs.dart';
import '../ui/page.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'auth_screens.dart' show PasswordRules;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _name = TextEditingController(text: context.app.user?.fullName ?? '');
  final _current = TextEditingController();
  final _new = TextEditingController();
  bool _nameSubmitted = false;
  bool _pwSubmitted = false;
  bool _nameBusy = false;
  bool _pwBusy = false;
  bool _allBusy = false;
  Object? _nameError;
  Object? _pwError;
  Object? _allError;

  String? get _nameProblem => _nameSubmitted && (_name.text.trim().isEmpty ? true : _name.text.trim().length > 120)
      ? (_name.text.trim().isEmpty ? 'Requerido' : 'Máximo 120 caracteres')
      : null;
  String? get _currentProblem => _pwSubmitted && _current.text.isEmpty ? 'Requerida' : null;
  String? get _newProblem => _pwSubmitted ? passwordProblem(_new.text) : null;

  Future<void> _saveName() async {
    setState(() {
      _nameSubmitted = true;
      _nameError = null;
    });
    if (_nameProblem != null || _nameBusy) return;
    final app = context.app;
    setState(() => _nameBusy = true);
    try {
      await app.updateName(_name.text.trim());
      app.onToast?.call('Perfil actualizado');
    } catch (e) {
      if (mounted) setState(() => _nameError = e);
    } finally {
      if (mounted) setState(() => _nameBusy = false);
    }
  }

  Future<void> _changePassword() async {
    setState(() {
      _pwSubmitted = true;
      _pwError = null;
    });
    if (_currentProblem != null || _newProblem != null || _pwBusy) return;
    final app = context.app;
    setState(() => _pwBusy = true);
    try {
      // El servidor cierra las demás sesiones y entrega tokens nuevos para esta
      final pair = await app.api.post(
        '/auth/change-password',
        body: {'current_password': _current.text, 'new_password': _new.text},
      ) as Map<String, dynamic>;
      await app.api.saveTokens(pair);
      app.onToast?.call('Contraseña cambiada. Se cerraron las demás sesiones');
      if (mounted) {
        setState(() {
          _current.clear();
          _new.clear();
          _pwSubmitted = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _pwError = e);
    } finally {
      if (mounted) setState(() => _pwBusy = false);
    }
  }

  Future<void> _logoutAll() async {
    final app = context.app;
    setState(() {
      _allBusy = true;
      _allError = null;
    });
    try {
      await app.api.post('/auth/logout-all');
      await app.logout();
    } catch (e) {
      if (mounted) setState(() => _allError = e);
    } finally {
      if (mounted) setState(() => _allBusy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _new.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return PageScaffold(
      children: [
        PageHead('Perfil'),
        CrCard(
          title: 'Datos personales',
          child: Stack12(
            children: [
              CrTextField(label: 'Nombre', controller: _name, error: _nameProblem, onChanged: (_) => setState(() {})),
              Text('Correo: ${app.user?.email ?? ''}', style: CrText.label(c.inkMuted)),
              Align(
                alignment: Alignment.centerLeft,
                child: CrButton(variant: CrButtonVariant.primary, label: 'Guardar', onPressed: _nameBusy ? null : _saveName),
              ),
              ErrorText(_nameError),
            ],
          ),
        ),
        CrCard(
          title: 'Cambiar contraseña',
          child: Stack12(
            children: [
              CrPasswordField(
                label: 'Contraseña actual',
                controller: _current,
                error: _currentProblem,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
              ),
              CrPasswordField(
                label: 'Contraseña nueva',
                controller: _new,
                error: _newProblem,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
              ),
              PasswordRules(_new.text),
              Align(
                alignment: Alignment.centerLeft,
                child: CrButton(variant: CrButtonVariant.primary, label: 'Cambiar contraseña', onPressed: _pwBusy ? null : _changePassword),
              ),
              ErrorText(_pwError),
            ],
          ),
        ),
        CrCard(
          title: 'Apariencia',
          child: Align(
            alignment: Alignment.centerLeft,
            child: CrSegmented<ThemeMode>(
              options: const [(ThemeMode.system, 'Automático'), (ThemeMode.light, 'Claro'), (ThemeMode.dark, 'Oscuro')],
              value: app.themeMode,
              onChanged: app.setTheme,
            ),
          ),
        ),
        Wrap(
          spacing: space3,
          runSpacing: space3,
          children: [
            CrButton(variant: CrButtonVariant.ghost, icon: 'logout', label: 'Cerrar sesión', onPressed: () => app.logout()),
            CrButton(
              variant: CrButtonVariant.ghost,
              label: 'Cerrar sesión en todos los dispositivos',
              onPressed: _allBusy ? null : _logoutAll,
            ),
          ],
        ),
        ErrorText(_allError),
      ],
    );
  }
}
