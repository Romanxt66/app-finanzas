const passwordMin = 8;
const passwordMax = 128;

class PasswordRule {
  const PasswordRule(this.id, this.label, this.ok, this.error);
  final String id, label, error;
  final bool Function(String) ok;
}

// Misma política que el backend (app/schemas/auth.py).
final passwordRules = <PasswordRule>[
  PasswordRule(
    'min',
    'Al menos $passwordMin caracteres',
    (p) => p.length >= passwordMin,
    'La contraseña debe tener al menos $passwordMin caracteres',
  ),
  PasswordRule('letter', 'Una letra', (p) => RegExp(r'\p{L}', unicode: true).hasMatch(p), 'La contraseña debe incluir al menos una letra'),
  PasswordRule('digit', 'Un número', (p) => RegExp(r'\d').hasMatch(p), 'La contraseña debe incluir al menos un número'),
  PasswordRule(
    'max',
    'Máximo $passwordMax caracteres',
    (p) => p.length <= passwordMax,
    'La contraseña no puede superar $passwordMax caracteres',
  ),
];

String? passwordProblem(String password) {
  for (final r in passwordRules) {
    if (!r.ok(password)) return r.error;
  }
  return null;
}
