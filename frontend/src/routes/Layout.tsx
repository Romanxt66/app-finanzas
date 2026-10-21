import { Navigate, NavLink, Outlet } from 'react-router-dom'
import { Button } from '../components/ui'
import { useAuth } from '../features/auth'

const links = [
  ['/', 'Resumen'],
  ['/transactions', 'Transacciones'],
  ['/accounts', 'Cuentas'],
  ['/categories', 'Categorías'],
  ['/budgets', 'Presupuestos'],
] as const

export function Layout() {
  const { user, loading, logout } = useAuth()
  if (loading) return <p className="p-8 text-center text-slate-500">Cargando…</p>
  if (!user) return <Navigate to="/login" replace />
  return (
    <div className="min-h-screen">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center gap-4 px-4 py-3">
          <strong className="text-emerald-700">Finanzas</strong>
          <nav className="flex flex-1 flex-wrap gap-1" aria-label="Principal">
            {links.map(([to, label]) => (
              <NavLink
                key={to}
                to={to}
                end={to === '/'}
                className={({ isActive }) =>
                  `rounded-md px-3 py-1.5 text-sm ${isActive ? 'bg-emerald-50 font-medium text-emerald-800' : 'text-slate-600 hover:bg-slate-100'}`
                }
              >
                {label}
              </NavLink>
            ))}
          </nav>
          <span className="text-sm text-slate-500">{user.full_name}</span>
          <Button variant="ghost" onClick={logout}>
            Salir
          </Button>
        </div>
      </header>
      <main className="mx-auto max-w-5xl space-y-4 px-4 py-6">
        <Outlet />
      </main>
    </div>
  )
}
