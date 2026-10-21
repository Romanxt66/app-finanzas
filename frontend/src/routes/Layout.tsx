import { Navigate, Outlet } from 'react-router-dom'
import { Backdrop, Button, Glass, Icon, TabBar, TopNav, type NavItem } from '../design'
import { useAuth } from '../features/auth'

const NAV: NavItem[] = [
  { to: '/', label: 'Inicio', icon: 'home', end: true },
  { to: '/transactions', label: 'Movimientos', icon: 'list' },
  { to: '/accounts', label: 'Cuentas', icon: 'wallet' },
  { to: '/budgets', label: 'Presupuestos', icon: 'target' },
  { to: '/categories', label: 'Categorías', icon: 'tag' },
]

export function Layout() {
  const { user, loading, logout } = useAuth()
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
          <TopNav items={NAV} />
          <span className="cr-spacer" />
          <span className="label cr-muted cr-user">{user.full_name}</span>
          <Button variant="ghost" size="sm" icon="logout" onClick={logout}>
            Salir
          </Button>
        </Glass>
        <main className="cr-main">
          <Outlet />
        </main>
        <div className="cr-bottom">
          <TabBar items={NAV} />
        </div>
      </div>
    </Backdrop>
  )
}
