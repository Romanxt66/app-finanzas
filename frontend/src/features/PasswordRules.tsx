import { PASSWORD_RULES } from '../lib/password'

/** Requisitos de contraseña que se marcan a medida que se escribe. */
export function PasswordRules({ value }: { value: string }) {
  return (
    <ul className="cr-rules" aria-label="Requisitos de la contraseña">
      {PASSWORD_RULES.map((r) => {
        const ok = r.ok(value) && value.length > 0
        return (
          <li key={r.id} data-ok={ok}>
            <span aria-hidden="true">{ok ? '✓' : '○'}</span> {r.label}
            <span className="cr-sr">{ok ? ' (cumplido)' : ' (pendiente)'}</span>
          </li>
        )
      })}
    </ul>
  )
}
