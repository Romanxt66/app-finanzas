import { useState } from 'react'
import { useDeleteMyAccount } from '../api/hooks'
import { Button, Card, ErrorText, Input, useToast } from '../design'
import { useAuth } from './authContext'

/** Perfil → Eliminar cuenta (lo exige Google Play). Pide la contraseña y escribir «ELIMINAR». */
export function DeleteAccountCard() {
  const { user, logout } = useAuth()
  const toast = useToast()
  const remove = useDeleteMyAccount()
  const [open, setOpen] = useState(false)
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const withPassword = user?.email_login !== false
  const ready =
    confirm.trim().toUpperCase() === 'ELIMINAR' && (!withPassword || password.length > 0)
  return (
    <Card title="Eliminar cuenta">
      <p className="cr-muted">
        Borra tu cuenta y todos tus datos (cuentas, movimientos, metas y ajustes) de forma
        permanente. Si quieres conservarlos, exporta antes tus movimientos en CSV.
      </p>
      {!open ? (
        <div>
          <Button variant="danger" icon="trash" onClick={() => setOpen(true)}>
            Eliminar mi cuenta
          </Button>
        </div>
      ) : (
        <form
          className="cr-stack"
          onSubmit={(e) => {
            e.preventDefault()
            if (!ready) return
            remove.mutate(withPassword ? { password } : {}, {
              onSuccess: () => {
                toast.success('Tu cuenta y tus datos se eliminaron')
                logout()
              },
            })
          }}
        >
          <p className="cr-muted">
            Esto no se puede deshacer. Se borrarán todos tus datos del servidor y se cerrará la
            sesión.
          </p>
          {withPassword ? (
            <Input
              label="Tu contraseña"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          ) : (
            <p className="cr-muted">
              Entraste con Google: para confirmar, crea antes una contraseña en esta misma página o
              elimínala desde la app Android.
            </p>
          )}
          <Input
            label="Escribe ELIMINAR para confirmar"
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
          />
          <ErrorText error={remove.error} />
          <div className="cr-row">
            <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
              Cancelar
            </Button>
            <Button type="submit" variant="danger" disabled={!ready || remove.isPending}>
              Eliminar para siempre
            </Button>
          </div>
        </form>
      )}
    </Card>
  )
}
