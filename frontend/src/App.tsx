import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './features/auth'
import { AccountsPage } from './routes/Accounts'
import { LoginPage, RegisterPage } from './routes/AuthPages'
import { BudgetsPage } from './routes/Budgets'
import { CategoriesPage } from './routes/Categories'
import { DashboardPage } from './routes/Dashboard'
import { Layout } from './routes/Layout'
import { TransactionsPage } from './routes/Transactions'

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false } },
})

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
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
            </Route>
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  )
}
