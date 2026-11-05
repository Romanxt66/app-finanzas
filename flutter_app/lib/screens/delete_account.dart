import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/dialogs.dart';
import '../ui/inputs.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'legal.dart';

/// Perfil → Eliminar cuenta. Google Play exige que se pueda pedir desde la app. Se confirma con la
/// contraseña y escribiendo «ELIMINAR»; antes se sugiere exportar los movimientos.
class DeleteAccountCard extends StatelessWidget {
  const DeleteAccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CrCard(
      title: 'Eliminar cuenta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Borra tu cuenta y todos tus datos (cuentas, movimientos, metas y ajustes) de forma permanente. '
            'Si quieres conservarlos, exporta antes tus movimientos en CSV desde Historial.',
            style: CrText.body(c.inkMuted),
          ),
          const SizedBox(height: space3),
          CrButton(
            variant: CrButtonVariant.danger,
            small: true,
            icon: 'trash',
            label: 'Eliminar mi cuenta',
            onPressed: () => showCrDialog<void>(context, title: 'Eliminar tu cuenta', builder: (_) => const _DeleteForm()),
          ),
        ],
      ),
    );
  }
}

class _DeleteForm extends StatefulWidget {
  const _DeleteForm();

  @override
  State<_DeleteForm> createState() => _DeleteFormState();
}

class _DeleteFormState extends State<_DeleteForm> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  Object? _error;

  bool get _ready => _password.text.isNotEmpty && _confirm.text.trim().toUpperCase() == 'ELIMINAR';

  Future<void> _submit() async {
    if (!_ready || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = context.app;
    final navigator = Navigator.of(context);
    try {
      await app.deleteAccount(_password.text);
      navigator.pop();
    } on ApiError catch (e) {
      // Servidor anterior a esta función: se explica cómo pedirlo mientras tanto
      final unsupported = e.status == 404 || e.status == 405;
      if (mounted) {
        setState(
          () => _error = unsupported
              ? 'Por ahora la eliminación se gestiona a mano: ${supportEmail.isNotEmpty ? 'escríbenos a $supportEmail' : 'escríbenos al correo de la ficha de Alvea en Google Play'} desde el correo de tu cuenta y la borramos en menos de 15 días hábiles.'
              : e,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Esto no se puede deshacer. Se borrarán todos tus datos del servidor y se cerrará la sesión.', style: CrText.body(c.inkMuted)),
        const SizedBox(height: space3),
        CrPasswordField(
          label: 'Tu contraseña',
          controller: _password,
          autofillHints: const [AutofillHints.password],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: space3),
        CrTextField(
          label: 'Escribe ELIMINAR para confirmar',
          controller: _confirm,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: space3),
        if (_error is String) Text(_error as String, style: CrText.label(c.ink)) else ErrorText(_error),
        const SizedBox(height: space3),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: space2,
          runSpacing: space2,
          children: [
            CrButton(variant: CrButtonVariant.ghost, small: true, label: 'Cancelar', onPressed: () => Navigator.of(context).pop()),
            CrButton(
              variant: CrButtonVariant.danger,
              small: true,
              label: 'Eliminar para siempre',
              onPressed: _ready && !_busy ? _submit : null,
            ),
          ],
        ),
      ],
    );
  }
}
