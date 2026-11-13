import { useState } from 'react'
import { encode } from 'uqr'
import {
  useNewRecoveryCodes,
  useTwoFactorDisable,
  useTwoFactorEnable,
  useTwoFactorSetup,
} from '../api/hooks'
import { Badge, Button, Card, ErrorText, Input } from '../design'
import { useAuth } from './authContext'

/** Código QR en SVG (módulos oscuros sobre blanco, como lo esperan las cámaras). */
function QrCode({ value, label }: { value: string; label: string }) {
  const { data, size } = encode(value, { ecc: 'M', border: 2 })
  let d = ''
  data.forEach((row, y) =>
    row.forEach((on, x) => {
      if (on) d += `M${x} ${y}h1v1h-1z`
    }),
  )
  return (
    <svg
      className="cr-2fa-qr"
      viewBox={`0 0 ${size} ${size}`}
      role="img"
      aria-label={label}
      shapeRendering="crispEdges"
    >
      <rect width={size} height={size} fill="#fff" />
      <path d={d} fill="#000" />
    </svg>
  )
}

/** La clave en grupos de 4 para copiarla a mano sin perderse. */
const groups = (secret: string) => secret.match(/.{1,4}/g)?.join(' ') ?? secret
const clean = (code: string) => code.replace(/\s/g, '')

function RecoveryCodesList({ codes, onDone }: { codes: string[]; onDone: () => void }) {
  const [copied, setCopied] = useState(false)
  return (
    <div className="cr-stack">
      <p className="body">
        Guarda estos códigos de recuperación en un lugar seguro. Cada uno sirve{' '}
        <strong>una sola vez</strong> para entrar si pierdes el teléfono. No volverás a verlos.
      </p>
      <ul className="cr-2fa-codes" aria-label="Códigos de recuperación">
        {codes.map((c) => (
          <li key={c}>{c}</li>
        ))}
      </ul>
      <div className="cr-row">
        <Button
          variant="ghost"
          icon={copied ? 'check' : undefined}
          onClick={() =>
            navigator.clipboard
              ?.writeText(codes.join('\n'))
              .then(() => setCopied(true))
              .catch(() => {})
          }
        >
          {copied ? 'Copiados' : 'Copiar'}
        </Button>
        <Button variant="primary" onClick={onDone}>
          Ya los guardé
        </Button>
      </div>
    </div>
  )
}

type Step = 'idle' | 'setup' | 'disable' | 'regen'

/** Perfil: activar, renovar los códigos de recuperación o desactivar la verificación en dos pasos. */
export function TwoFactorCard() {
  const { user } = useAuth()
  const setup = useTwoFactorSetup()
  const enable = useTwoFactorEnable()
  const disable = useTwoFactorDisable()
  const regen = useNewRecoveryCodes()
  const [step, setStep] = useState<Step>('idle')
  const [code, setCode] = useState('')
  const [password, setPassword] = useState('')
  const [codes, setCodes] = useState<string[] | null>(null)
  const enabled = !!user?.two_factor_enabled

  const reset = () => {
    setStep('idle')
    setCode('')
    setPassword('')
    for (const m of [setup, enable, disable, regen]) m.reset()
  }

  const codeInput = (
    <Input
      label="Código de 6 dígitos"
      icon="lock"
      inputMode="numeric"
      autoComplete="one-time-code"
      maxLength={step === 'setup' ? 7 : 32}
      value={code}
      onChange={(e) => setCode(e.target.value)}
    />
  )

  let body
  if (codes) {
    body = (
      <RecoveryCodesList
        codes={codes}
        onDone={() => {
          setCodes(null)
          reset()
        }}
      />
    )
  } else if (step === 'setup' && setup.data) {
    body = (
      <form
        className="cr-stack"
        onSubmit={(e) => {
          e.preventDefault()
          enable.mutate(clean(code), { onSuccess: (r) => setCodes(r.recovery_codes) })
        }}
      >
        <p className="body">
          1. Escanea el código con tu app de autenticación (Google Authenticator, Microsoft
          Authenticator, 1Password…).
        </p>
        <div className="cr-2fa-setup">
          <QrCode value={setup.data.otpauth_uri} label="Código QR para la app de autenticación" />
          <p className="caption cr-muted">
            ¿No puedes escanearlo? Escribe esta clave:
            <br />
            <code className="cr-2fa-secret">{groups(setup.data.secret)}</code>
          </p>
        </div>
        <p className="body">2. Escribe el código que muestra la app para confirmar.</p>
        {codeInput}
        <ErrorText error={enable.error} />
        <div className="cr-dialog-actions">
          <Button variant="ghost" onClick={reset}>
            Cancelar
          </Button>
          <Button type="submit" variant="primary" disabled={enable.isPending || !clean(code)}>
            Activar
          </Button>
        </div>
      </form>
    )
  } else if (step === 'disable' || step === 'regen') {
    const disabling = step === 'disable'
    const pending = disabling ? disable.isPending : regen.isPending
    body = (
      <form
        className="cr-stack"
        onSubmit={(e) => {
          e.preventDefault()
          if (disabling) disable.mutate({ password, code: clean(code) }, { onSuccess: reset })
          else regen.mutate(clean(code), { onSuccess: (r) => setCodes(r.recovery_codes) })
        }}
      >
        <p className="body">
          {disabling
            ? 'Para desactivarla confirma que eres tú.'
            : 'Los códigos anteriores dejarán de valer. Confirma con un código de tu app.'}
        </p>
        {disabling && user?.email_login !== false && (
          <Input
            label="Contraseña"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        )}
        {codeInput}
        <ErrorText error={disabling ? disable.error : regen.error} />
        <div className="cr-dialog-actions">
          <Button variant="ghost" onClick={reset}>
            Cancelar
          </Button>
          <Button
            type="submit"
            variant={disabling ? 'danger' : 'primary'}
            disabled={pending || !clean(code)}
          >
            {disabling ? 'Desactivar' : 'Generar códigos nuevos'}
          </Button>
        </div>
      </form>
    )
  } else if (enabled) {
    body = (
      <div className="cr-stack">
        <p className="body">
          Al entrar te pediremos, además de la contraseña, un código de tu app de autenticación.
        </p>
        <div className="cr-row">
          <Button variant="ghost" onClick={() => setStep('regen')}>
            Nuevos códigos de recuperación
          </Button>
          <Button variant="danger" onClick={() => setStep('disable')}>
            Desactivar
          </Button>
        </div>
      </div>
    )
  } else {
    body = (
      <div className="cr-stack">
        <p className="body">
          Protege tu cuenta aunque alguien sepa tu contraseña: al entrar se pedirá también un código
          que cambia cada 30 segundos en tu teléfono.
        </p>
        <ErrorText error={setup.error} />
        <div>
          <Button
            variant="primary"
            icon="shield"
            disabled={setup.isPending}
            onClick={() => setup.mutate(undefined, { onSuccess: () => setStep('setup') })}
          >
            Activar
          </Button>
        </div>
      </div>
    )
  }

  return (
    <Card
      title="Verificación en dos pasos"
      action={enabled && !codes ? <Badge tone="positive">Activa</Badge> : undefined}
    >
      {body}
    </Card>
  )
}
