import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { ToastProvider } from './design'
import { AuthProvider } from './features/auth'
import { AccountsPage } from './routes/Accounts'
import { LoginPage, RegisterPage } from './routes/AuthPages'
import { BudgetsPage } from './routes/Budgets'
import { CategoriesPage } from './routes/Categories'
import { DashboardPage } from './routes/Dashboard'
import { GoalsPage } from './routes/Goals'
import { Layout } from './routes/Layout'
import { MorePage } from './routes/More'
import { ProfilePage } from './routes/Profile'
import { TransactionsPage } from './routes/Transactions'

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
