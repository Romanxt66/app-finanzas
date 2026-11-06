import { Suspense, useMemo } from 'react'
import { Link, Navigate, Outlet } from 'react-router-dom'
import { useRunDueRecurring } from '../api/hooks'
import {
  Backdrop,
  Button,
  CommandPalette,
  Glass,
  Icon,
  Skeleton,
  TabBar,
  TopNav,
  useOnline,
  useTheme,
  type Command,
  type NavItem,
  BrandLogo,
} from '../design'
import { useAuth } from '../features/authContext'
import { LegalNotice } from '../features/LegalNotice'
import { APP_NAME } from '../lib/brand'

const DESKTOP_NAV: NavItem[] = [
  { to: '/', label: 'Inicio', icon: 'home', end: true },
  { to: '/transactions', label: 'Movimientos', icon: 'list' },
  { to: '/analytics', label: 'Análisis', icon: 'chart' },
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
  { to: '/more', label: 'Más', icon: 'dots' },
]

/** Iniciales para el avatar («Ana María Pérez» → «AP»). */
function initials(name: string): string {
  const words = name.trim().split(/\s+/).filter(Boolean)
  if (!words.length) return '·'
  const first = words[0][0]
  const last = words.length > 1 ? words[words.length - 1][0] : (words[0][1] ?? '')
  return (first + last).toUpperCase()
}

export function Layout() {
  const { user, loading, logout } = useAuth()
  const theme = useTheme()
  const online = useOnline()
  useRunDueRecurring(!!user)
  const actions = useMemo<Command[]>(
    () => [
      { id: 'profile', label: 'Perfil', icon: 'user', group: 'Cuenta', to: '/profile' },
      { id: 'theme', label: 'Cambiar tema', icon: 'sun', group: 'Cuenta', run: theme.cycle },
      { id: 'logout', label: 'Cerrar sesión', icon: 'logout', group: 'Cuenta', run: logout },
    ],
    [theme.cycle, logout],
  )
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
            <BrandLogo />
            {APP_NAME}
          </span>
          <TopNav items={DESKTOP_NAV} />
          <span className="cr-spacer" />
          <CommandPalette items={DESKTOP_NAV} actions={actions} />
          <Link to="/profile" className="label cr-muted cr-user" title="Perfil">
            <span className="cr-avatar" aria-hidden="true">
              {initials(user.full_name)}
            </span>
            <span className="cr-sr-only">Perfil de </span>
            <span className="cr-user-name">{user.full_name}</span>
          </Link>
          <Button
            variant="ghost"
            size="sm"
            icon={theme.choice === 'dark' ? 'moon' : 'sun'}
            aria-label={`Tema: ${{ system: 'automático', light: 'claro', dark: 'oscuro' }[theme.choice]}. Cambiar`}
            onClick={theme.cycle}
          />
          {/* En el móvil «Salir» vive en Más y en Perfil (el avatar lleva a Perfil), como en la app */}
          <Button variant="ghost" size="sm" icon="logout" onClick={logout} className="cr-wide-only">
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
          <LegalNotice />
          <Suspense fallback={<Skeleton lines={3} height={96} />}>
            <Outlet />
          </Suspense>
        </main>
        <div className="cr-bottom">
          <TabBar
            items={MOBILE_NAV}
            center={
              <Link
                to="/transactions"
                state={{ nuevo: true }}
                className="cr-tab-add"
                aria-label="Anotar un movimiento"
              >
                <Icon name="plus" />
              </Link>
            }
          />
        </div>
      </div>
    </Backdrop>
  )
}
