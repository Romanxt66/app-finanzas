import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { lazy, Suspense } from 'react'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { ApiError } from './api/client'
import { ToastProvider } from './design'
import { AuthProvider } from './features/auth'
import { Layout } from './routes/Layout'

// Cada pantalla se descarga al visitarla; recharts solo viaja con el resumen
const lazyPage = <K extends string>(load: () => Promise<Record<K, React.ComponentType>>, name: K) =>
  lazy(async () => ({ default: (await load())[name] }))
// Inicio de sesión y textos legales también aparte: los formularios (zod, react-hook-form) no viajan con la portada
const LoginPage = lazyPage(() => import('./routes/AuthPages'), 'LoginPage')
const RegisterPage = lazyPage(() => import('./routes/AuthPages'), 'RegisterPage')
const LegalPage = lazy(async () => ({ default: (await import('./routes/Legal')).LegalPage }))
const AnalyticsPage = lazyPage(() => import('./routes/Analytics'), 'AnalyticsPage')
const AccountsPage = lazyPage(() => import('./routes/Accounts'), 'AccountsPage')
const BudgetsPage = lazyPage(() => import('./routes/Budgets'), 'BudgetsPage')
const CategoriesPage = lazyPage(() => import('./routes/Categories'), 'CategoriesPage')
const DashboardPage = lazyPage(() => import('./routes/Dashboard'), 'DashboardPage')
const GoalsPage = lazyPage(() => import('./routes/Goals'), 'GoalsPage')
const MorePage = lazyPage(() => import('./routes/More'), 'MorePage')
const RecurringPage = lazyPage(() => import('./routes/Recurring'), 'RecurringPage')
const ImportPage = lazyPage(() => import('./routes/Import'), 'ImportPage')
const ProfilePage = lazyPage(() => import('./routes/Profile'), 'ProfilePage')
const SubscriptionsPage = lazyPage(() => import('./routes/Subscriptions'), 'SubscriptionsPage')
const TransactionsPage = lazyPage(() => import('./routes/Transactions'), 'TransactionsPage')

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // El cliente ya reintenta los fallos pasajeros; aquí solo un intento más para errores del servidor
      retry: (count, error) =>
        count < 1 && error instanceof ApiError && (error.status === 0 || error.status >= 500),
      // Al volver a la pestaña o recuperar la conexión, lo que falló se vuelve a pedir
      refetchOnWindowFocus: (query) => query.state.status === 'error',
      refetchOnReconnect: true,
    },
  },
})

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <AuthProvider>
          <BrowserRouter>
            <Suspense fallback={null}>
              <Routes>
                <Route path="/login" element={<LoginPage />} />
                <Route path="/register" element={<RegisterPage />} />
                <Route path="/terminos" element={<LegalPage kind="terms" />} />
                <Route path="/privacidad" element={<LegalPage kind="privacy" />} />
                <Route element={<Layout />}>
                  <Route index element={<DashboardPage />} />
                  <Route path="transactions" element={<TransactionsPage />} />
                  <Route path="analytics" element={<AnalyticsPage />} />
                  <Route path="accounts" element={<AccountsPage />} />
                  <Route path="categories" element={<CategoriesPage />} />
                  <Route path="budgets" element={<BudgetsPage />} />
                  <Route path="goals" element={<GoalsPage />} />
                  <Route path="recurring" element={<RecurringPage />} />
                  <Route path="subscriptions" element={<SubscriptionsPage />} />
                  <Route path="import" element={<ImportPage />} />
                  <Route path="profile" element={<ProfilePage />} />
                  <Route path="more" element={<MorePage />} />
                </Route>
              </Routes>
            </Suspense>
          </BrowserRouter>
        </AuthProvider>
      </ToastProvider>
    </QueryClientProvider>
  )
}
