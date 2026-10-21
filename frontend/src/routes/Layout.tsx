import { Link, Navigate, Outlet } from 'react-router-dom'
import { Backdrop, Button, Glass, Icon, TabBar, TopNav, useTheme, type NavItem } from '../design'
import { useAuth } from '../features/authContext'

const DESKTOP_NAV: NavItem[] = [
  { to: '/', label: 'Inicio', icon: 'home', end: true },
  { to: '/transactions', label: 'Movimientos', icon: 'list' },
  { to: '/accounts', label: 'Cuentas', icon: 'wallet' },
  { to: '/budgets', label: 'Presupuestos', icon: 'target' },
  { to: '/goals', label: 'Metas', icon: 'chart' },
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
            <Icon name="wallet" />
            Finanzas
          </span>
          <TopNav items={DESKTOP_NAV} />
          <span className="cr-spacer" />
          <Link to="/profile" className="label cr-muted cr-user" aria-label="Perfil">
            {user.full_name}
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
        <main className="cr-main">
          <Outlet />
        </main>
        <div className="cr-bottom">
          <TabBar items={MOBILE_NAV} />
        </div>
      </div>
    </Backdrop>
  )
}
