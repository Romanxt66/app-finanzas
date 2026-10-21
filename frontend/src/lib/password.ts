// Misma política que el backend (app/schemas/auth.py): cualquier cambio debe hacerse en ambos lados.
export const PASSWORD_MIN = 8
export const PASSWORD_MAX = 128

export interface PasswordRule {
  id: string
  label: string
  ok: (password: string) => boolean
  /** Mensaje cuando la regla no se cumple */
  error: string
}

export const PASSWORD_RULES: PasswordRule[] = [
  {
    id: 'min',
    label: `Al menos ${PASSWORD_MIN} caracteres`,
    ok: (p) => p.length >= PASSWORD_MIN,
    error: `La contraseña debe tener al menos ${PASSWORD_MIN} caracteres`,
  },
  {
    id: 'letter',
    label: 'Una letra',
    ok: (p) => /\p{L}/u.test(p),
    error: 'La contraseña debe incluir al menos una letra',
  },
  {
    id: 'digit',
    label: 'Un número',
    ok: (p) => /\d/.test(p),
    error: 'La contraseña debe incluir al menos un número',
  },
  {
    id: 'max',
    label: `Máximo ${PASSWORD_MAX} caracteres`,
    ok: (p) => p.length <= PASSWORD_MAX,
    error: `La contraseña no puede superar ${PASSWORD_MAX} caracteres`,
  },
]

/** Primer motivo por el que la contraseña no es válida, o null si lo es. */
export function passwordProblem(password: string): string | null {
  return PASSWORD_RULES.find((r) => !r.ok(password))?.error ?? null
}
