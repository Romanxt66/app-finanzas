import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import { Link, Navigate } from 'react-router-dom'
import { z } from 'zod'
import { Backdrop, Button, Checkbox, ErrorText, Icon, Input, PasswordInput } from '../design'
import { useAuth } from '../features/authContext'
import { PasswordRules } from '../features/PasswordRules'
import { APP_NAME } from '../lib/brand'
import { passwordProblem } from '../lib/password'

const loginSchema = z.object({
  email: z.email('Correo inválido'),
  password: z.string().min(1, 'Requerida'),
  remember: z.boolean(),
})
const registerSchema = loginSchema.omit({ remember: true }).extend({
  full_name: z.string().min(1, 'Requerido').max(120),
  password: z.string().superRefine((value, ctx) => {
    const problem = passwordProblem(value)
    if (problem) ctx.addIssue({ code: 'custom', message: problem })
  }),
})

/** Adorno de la columna izquierda: formas de vidrio sin cifras, solo para dar contexto visual. */
function HeroPreview() {
  return (
    <div className="cr-hero-art" aria-hidden="true">
      <div className="cr-hero-card cr-hero-balance">
        <span className="cr-hero-label">Saldo total</span>
        <span className="cr-ph cr-ph-lg" />
        <svg viewBox="0 0 120 32" className="cr-hero-spark">
          <path d="M2 26 C18 24 22 12 38 15 S62 28 78 14 S104 6 118 4" />
        </svg>
      </div>
      <div className="cr-hero-card cr-hero-secure">
        <span className="cr-chip cr-chip-brand">
          <Icon name="shield" />
        </span>
        <span>
          <strong>Sesión protegida</strong>
          <span className="cr-hero-label">Tus datos son solo tuyos</span>
        </span>
      </div>
    </div>
  )
}

function Shell({
  title,
  subtitle,
  children,
  footer,
}: {
  title: string
  subtitle: string
  children: React.ReactNode
  footer: React.ReactNode
}) {
  return (
    <Backdrop>
      <main className="cr-login">
        <section className="cr-login-hero">
          <span className="cr-brand cr-brand-lg">
            <span className="cr-brand-mark">
              <Icon name="wallet" />
            </span>
            {APP_NAME}
          </span>
          <p className="cr-hero-title">
            Tu dinero, <em>claro</em> como el cristal.
          </p>
          <p className="cr-hero-copy">
            Saldo, gastos y metas en un solo lugar. Entra para ver cómo va tu mes.
          </p>
          <HeroPreview />
        </section>
        <section className="cr-login-card cr-glass cr-glass-strong">
          <h1 className="cr-login-title">{title}</h1>
          <p className="cr-login-sub">{subtitle}</p>
          {children}
          <p className="cr-login-foot">{footer}</p>
        </section>
      </main>
    </Backdrop>
  )
}

export function LoginPage() {
  const { user, login } = useAuth()
  const [error, setError] = useState<unknown>(null)
  const { register, handleSubmit, formState } = useForm({
    resolver: zodResolver(loginSchema),
    defaultValues: { remember: true },
  })
  if (user) return <Navigate to="/" replace />
  return (
    <Shell
      title="Iniciar sesión"
      subtitle="Bienvenido de nuevo. Ingresa tus datos para continuar."
      footer={
        <>
          ¿Aún no tienes cuenta? <Link to="/register">Regístrate gratis</Link>
        </>
      }
    >
      <form
        className="cr-stack"
        onSubmit={handleSubmit((d) => {
          setError(null)
          return login(d.email, d.password, d.remember).catch(setError)
        })}
      >
        <Input
          label="Correo"
          type="email"
          icon="mail"
          placeholder="nombre@correo.com"
          autoComplete="email"
          error={formState.errors.email?.message}
          {...register('email')}
        />
        <PasswordInput
          label="Contraseña"
          autoComplete="current-password"
          error={formState.errors.password?.message}
          {...register('password')}
        />
        <Checkbox label="Mantener sesión iniciada" {...register('remember')} />
        <ErrorText error={error} />
        <Button type="submit" variant="primary" disabled={formState.isSubmitting}>
          Entrar
          <Icon name="arrow" />
        </Button>
      </form>
      <div className="cr-login-or">
        <span>o entra con</span>
      </div>
      <div className="cr-login-alt">
        <Button disabled title="Próximamente" aria-label="Huella (próximamente)">
          <Icon name="fingerprint" />
          Huella
        </Button>
        <Button disabled title="Próximamente" aria-label="Passkey (próximamente)">
          <Icon name="key" />
          Passkey
        </Button>
      </div>
    </Shell>
  )
}

export function RegisterPage() {
  const { user, register: signUp } = useAuth()
  const [error, setError] = useState<unknown>(null)
  const { register, handleSubmit, formState, control } = useForm({
    resolver: zodResolver(registerSchema),
  })
  const password = useWatch({ control, name: 'password', defaultValue: '' })
  if (user) return <Navigate to="/" replace />
  return (
    <Shell
      title="Crear cuenta"
      subtitle="Empieza a ver tu dinero con claridad."
      footer={
        <>
          ¿Ya tienes cuenta? <Link to="/login">Inicia sesión</Link>
        </>
      }
    >
      <form
        className="cr-stack"
        onSubmit={handleSubmit((d) => {
          setError(null)
          return signUp(d).catch(setError)
        })}
      >
        <Input
          label="Nombre"
          icon="user"
          autoComplete="name"
          error={formState.errors.full_name?.message}
          {...register('full_name')}
        />
        <Input
          label="Correo"
          type="email"
          icon="mail"
          placeholder="nombre@correo.com"
          autoComplete="email"
          error={formState.errors.email?.message}
          {...register('email')}
        />
        <PasswordInput
          label="Contraseña"
          autoComplete="new-password"
          error={formState.errors.password?.message}
          {...register('password')}
        />
        <PasswordRules value={password ?? ''} />
        <ErrorText error={error} />
        <Button type="submit" variant="primary" disabled={formState.isSubmitting}>
          Crear cuenta
          <Icon name="arrow" />
        </Button>
      </form>
    </Shell>
  )
}
