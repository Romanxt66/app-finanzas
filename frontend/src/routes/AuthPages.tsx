import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { Link, Navigate } from 'react-router-dom'
import { z } from 'zod'
import { Backdrop, Button, ErrorText, Glass, Icon, Input } from '../design'
import { useAuth } from '../features/auth'

const loginSchema = z.object({
  email: z.email('Correo inválido'),
  password: z.string().min(1, 'Requerida'),
})
const registerSchema = loginSchema.extend({
  full_name: z.string().min(1, 'Requerido').max(120),
  password: z.string().min(8, 'Mínimo 8 caracteres'),
})

function Shell({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <Backdrop>
      <main className="cr-auth">
        <span className="cr-brand">
          <Icon name="wallet" />
          Finanzas
        </span>
        <h1 className="title">{title}</h1>
        <Glass strong padded>
          {children}
        </Glass>
      </main>
    </Backdrop>
  )
}

export function LoginPage() {
  const { user, login } = useAuth()
  const [error, setError] = useState<unknown>(null)
  const { register, handleSubmit, formState } = useForm({ resolver: zodResolver(loginSchema) })
  if (user) return <Navigate to="/" replace />
  return (
    <Shell title="Iniciar sesión">
      <form
        className="cr-stack"
        onSubmit={handleSubmit((d) => login(d.email, d.password).catch(setError))}
      >
        <Input
          label="Correo"
          type="email"
          autoComplete="email"
          error={formState.errors.email?.message}
          {...register('email')}
        />
        <Input
          label="Contraseña"
          type="password"
          autoComplete="current-password"
          error={formState.errors.password?.message}
          {...register('password')}
        />
        <ErrorText error={error} />
        <Button type="submit" variant="primary" disabled={formState.isSubmitting}>
          Entrar
        </Button>
      </form>
      <p className="label cr-muted" style={{ marginTop: 'var(--space-4)', textAlign: 'center' }}>
        ¿Sin cuenta?{' '}
        <Link to="/register" style={{ color: 'var(--mint)' }}>
          Regístrate
        </Link>
      </p>
    </Shell>
  )
}

export function RegisterPage() {
  const { user, register: signUp } = useAuth()
  const [error, setError] = useState<unknown>(null)
  const { register, handleSubmit, formState } = useForm({ resolver: zodResolver(registerSchema) })
  if (user) return <Navigate to="/" replace />
  return (
    <Shell title="Crear cuenta">
      <form className="cr-stack" onSubmit={handleSubmit((d) => signUp(d).catch(setError))}>
        <Input
          label="Nombre"
          autoComplete="name"
          error={formState.errors.full_name?.message}
          {...register('full_name')}
        />
        <Input
          label="Correo"
          type="email"
          autoComplete="email"
          error={formState.errors.email?.message}
          {...register('email')}
        />
        <Input
          label="Contraseña"
          type="password"
          autoComplete="new-password"
          error={formState.errors.password?.message}
          {...register('password')}
        />
        <ErrorText error={error} />
        <Button type="submit" variant="primary" disabled={formState.isSubmitting}>
          Crear cuenta
        </Button>
      </form>
      <p className="label cr-muted" style={{ marginTop: 'var(--space-4)', textAlign: 'center' }}>
        ¿Ya tienes cuenta?{' '}
        <Link to="/login" style={{ color: 'var(--mint)' }}>
          Inicia sesión
        </Link>
      </p>
    </Shell>
  )
}
