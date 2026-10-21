import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { lazy } from 'react'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { ToastProvider } from './design'
import { AuthProvider } from './features/auth'
import { LoginPage, RegisterPage } from './routes/AuthPages'
import { Layout } from './routes/Layout'

// Cada pantalla se descarga al visitarla; recharts solo viaja con el resumen
const lazyPage = <K extends string>(load: () => Promise<Record<K, React.ComponentType>>, name: K) =>
  lazy(async () => ({ default: (await load())[name] }))
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
  defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false } },
})

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <AuthProvider>
          <BrowserRouter>
            <Routes>
              <Route path="/login" element={<LoginPage />} />
              <Route path="/register" element={<RegisterPage />} />
              <Route element={<Layout />}>
                <Route index element={<DashboardPage />} />
                <Route path="transactions" element={<TransactionsPage />} />
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
          </BrowserRouter>
        </AuthProvider>
      </ToastProvider>
    </QueryClientProvider>
  )
}
