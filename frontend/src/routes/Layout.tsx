import { Suspense } from 'react'
import { Link, Navigate, Outlet } from 'react-router-dom'
import { useRunDueRecurring } from '../api/hooks'
import {
  Backdrop,
  Button,
  Glass,
  Icon,
  Skeleton,
  TabBar,
  TopNav,
  useOnline,
  useTheme,
  type NavItem,
} from '../design'
import { useAuth } from '../features/authContext'
import { APP_NAME } from '../lib/brand'

const DESKTOP_NAV: NavItem[] = [
  { to: '/', label: 'Inicio', icon: 'home', end: true },
  { to: '/transactions', label: 'Movimientos', icon: 'list' },
  { to: '/accounts', label: 'Cuentas', icon: 'wallet' },
  { to: '/budgets', label: 'Presupuestos', icon: 'target' },
  { to: '/goals', label: 'Metas', icon: 'chart' },
  { to: '/recurring', label: 'Recurrentes', icon: 'swap' },
  { to: '/categories', label: 'Categorías', icon: 'tag' },
]

// En móvil caben cinco pestañas: lo demás vive en "Más"
const MOBILE_NAV: NavItem[] = [
  { to: '/', label: 'Inicio', icon: 'home', end: true },
  { to: '/transactions', label: 'Movimientos', icon: 'list' },
  { to: '/accounts', label: 'Cuentas', icon: 'wallet' },
  { to: '/goals', label: 'Metas', icon: 'chart' },
  { to: '/more', label: 'Más', icon: 'plus' },
]

export function Layout() {
  const { user, loading, logout } = useAuth()
  const theme = useTheme()
  const online = useOnline()
  useRunDueRecurring(!!user)
  if (loading)
    return (
      <Backdrop>
        <p className="cr-empty" role="status">
          Cargando…
        </p>
      </Backdrop>
    )
  if (!user) return <Navigate to="/login" replace />
  return (
    <Backdrop>
      <div className="cr-shell">
        <Glass as="header" className="cr-topbar">
          <span className="cr-brand">
            <span className="cr-brand-mark">
              <Icon name="wallet" />
            </span>
            {APP_NAME}
          </span>
          <TopNav items={DESKTOP_NAV} />
          <span className="cr-spacer" />
          <Link to="/profile" className="label cr-muted cr-user" title="Perfil">
            <Icon name="user" />
            <span className="cr-user-name">{user.full_name}</span>
          </Link>
          <Button
            variant="ghost"
            size="sm"
            icon={theme.choice === 'dark' ? 'moon' : 'sun'}
            aria-label={`Tema: ${{ system: 'automático', light: 'claro', dark: 'oscuro' }[theme.choice]}. Cambiar`}
            onClick={theme.cycle}
          />
          <Button variant="ghost" size="sm" icon="logout" onClick={logout}>
            Salir
          </Button>
        </Glass>
        {!online && (
          <p className="cr-offline" role="status">
            Sin conexión: puedes ver lo ya cargado, pero los cambios no se guardarán hasta volver a
            conectarte.
          </p>
        )}
        <main className="cr-main">
          <Suspense fallback={<Skeleton lines={3} height={96} />}>
            <Outlet />
          </Suspense>
        </main>
        <div className="cr-bottom">
          <TabBar items={MOBILE_NAV} />
        </div>
      </div>
    </Backdrop>
  )
}
