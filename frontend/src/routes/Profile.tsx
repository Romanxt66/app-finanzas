import { zodResolver } from '@hookform/resolvers/zod'
import { useForm, useWatch } from 'react-hook-form'
import { z } from 'zod'
import { useChangePassword, useUpdateProfile } from '../api/hooks'
import { Button, Card, ErrorText, Input, Segmented, useTheme, type ThemeChoice } from '../design'
import { useAuth } from '../features/authContext'
import { PasswordRules } from '../features/PasswordRules'
import { passwordProblem } from '../lib/password'

const nameSchema = z.object({ full_name: z.string().min(1, 'Requerido').max(120) })
const passwordSchema = z.object({
  current_password: z.string().min(1, 'Requerida'),
  new_password: z.string().superRefine((value, ctx) => {
    const problem = passwordProblem(value)
    if (problem) ctx.addIssue({ code: 'custom', message: problem })
  }),
})

const THEMES: { value: ThemeChoice; label: string }[] = [
  { value: 'system', label: 'Automático' },
  { value: 'light', label: 'Claro' },
  { value: 'dark', label: 'Oscuro' },
]

export function ProfilePage() {
  const { user, logout } = useAuth()
  const theme = useTheme()
  const update = useUpdateProfile()
  const change = useChangePassword()
  const nameForm = useForm({
    resolver: zodResolver(nameSchema),
    // `values` (no defaultValues): el usuario puede llegar después del primer render
    values: { full_name: user?.full_name ?? '' },
  })
  const pwForm = useForm({ resolver: zodResolver(passwordSchema) })
  const newPassword = useWatch({ control: pwForm.control, name: 'new_password', defaultValue: '' })

  return (
    <>
      <h1 className="title">Perfil</h1>
      <Card title="Datos personales">
        <form
          className="cr-stack"
          onSubmit={nameForm.handleSubmit((d) => update.mutate(d.full_name))}
        >
          <Input
            label="Nombre"
            error={nameForm.formState.errors.full_name?.message}
            {...nameForm.register('full_name')}
          />
          <p className="label cr-muted">Correo: {user?.email}</p>
          <div>
            <Button type="submit" variant="primary" disabled={update.isPending}>
              Guardar
            </Button>
          </div>
          <ErrorText error={update.error} />
        </form>
      </Card>

      <Card title="Cambiar contraseña">
        <form
          className="cr-stack"
          onSubmit={pwForm.handleSubmit((d) =>
            change.mutate(d, { onSuccess: () => pwForm.reset() }),
          )}
        >
          <Input
            label="Contraseña actual"
            type="password"
            autoComplete="current-password"
            error={pwForm.formState.errors.current_password?.message}
            {...pwForm.register('current_password')}
          />
          <Input
            label="Contraseña nueva"
            type="password"
            autoComplete="new-password"
            error={pwForm.formState.errors.new_password?.message}
            {...pwForm.register('new_password')}
          />
          <PasswordRules value={newPassword ?? ''} />
          <div>
            <Button type="submit" variant="primary" disabled={change.isPending}>
              Cambiar contraseña
            </Button>
          </div>
          <ErrorText error={change.error} />
        </form>
      </Card>

      <Card title="Apariencia">
        <Segmented label="Tema" options={THEMES} value={theme.choice} onChange={theme.set} />
      </Card>

      <div>
        <Button variant="ghost" icon="logout" onClick={logout}>
          Cerrar sesión
        </Button>
      </div>
    </>
  )
}
