import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { Link, Navigate } from 'react-router-dom'
import { z } from 'zod'
import { Button, Card, ErrorText, Input } from '../components/ui'
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
    <main className="mx-auto mt-16 max-w-sm px-4">
      <h1 className="mb-4 text-2xl font-bold">{title}</h1>
      <Card>{children}</Card>
    </main>
  )
}

export function LoginPage() {
  const { user, login } = useAuth()
  const [error, setError] = useState<unknown>(null)
  const form = useForm({ resolver: zodResolver(loginSchema) })
  if (user) return <Navigate to="/" replace />
  const { register, handleSubmit, formState } = form
  return (
    <Shell title="Iniciar sesión">
      <form
        className="space-y-3"
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
        <Button type="submit" className="w-full" disabled={formState.isSubmitting}>
          Entrar
        </Button>
      </form>
      <p className="mt-3 text-center text-sm">
        ¿Sin cuenta?{' '}
        <Link className="text-emerald-700 underline" to="/register">
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
      <form className="space-y-3" onSubmit={handleSubmit((d) => signUp(d).catch(setError))}>
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
        <Button type="submit" className="w-full" disabled={formState.isSubmitting}>
          Crear cuenta
        </Button>
      </form>
      <p className="mt-3 text-center text-sm">
        ¿Ya tienes cuenta?{' '}
        <Link className="text-emerald-700 underline" to="/login">
          Inicia sesión
        </Link>
      </p>
    </Shell>
  )
}
