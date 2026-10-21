import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useToast } from '../design/toastContext'
import { todayISO } from '../lib/format'
import { api, tokens, type Schemas } from './client'

export type Account = Schemas['AccountOut']
export type Category = Schemas['CategoryOut']
export type Transaction = Schemas['TransactionOut']
export type Budget = Schemas['BudgetOut']
export type Summary = Schemas['Summary']
export type TransactionInput = Schemas['TransactionCreate']
export type Recurring = Schemas['RecurringOut']
export type Goal = Schemas['GoalOut']
export type Contribution = Schemas['ContributionOut']

export interface TransactionFilters {
  account_id?: string
  category_id?: string
  type?: string
  date_from?: string
  date_to?: string
  search?: string
  limit: number
  offset: number
}

export const keys = {
  accounts: ['accounts'] as const,
  categories: ['categories'] as const,
  transactions: ['transactions'] as const,
  budgets: ['budgets'] as const,
  summary: ['summary'] as const,
  goals: ['goals'] as const,
  recurring: ['recurring'] as const,
}

/** Una transacción cambia saldos, presupuestos y reportes: se invalida todo lo derivado. */
function useInvalidate(...groups: (readonly string[])[]) {
  const qc = useQueryClient()
  return () => Promise.all(groups.map((queryKey) => qc.invalidateQueries({ queryKey })))
}

export const useAccounts = (includeArchived = false) =>
  useQuery({
    queryKey: [...keys.accounts, includeArchived],
    queryFn: () => api<Account[]>('/accounts', { query: { include_archived: includeArchived } }),
  })

export function useCreateAccount() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.accounts)
  return useMutation({
    mutationFn: (body: Schemas['AccountCreate']) =>
      api<Account>('/accounts', { method: 'POST', body }),
    onSuccess: () => {
      toast.success('Cuenta creada')
      return invalidate()
    },
  })
}

export function useUpdateAccount() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.accounts)
  return useMutation({
    mutationFn: ({ id, ...body }: { id: string } & Schemas['AccountUpdate']) =>
      api<Account>(`/accounts/${id}`, { method: 'PATCH', body }),
    onSuccess: () => {
      toast.success('Cuenta actualizada')
      return invalidate()
    },
  })
}

export const useCategories = () =>
  useQuery({ queryKey: keys.categories, queryFn: () => api<Category[]>('/categories') })

export function useCreateCategory() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.categories)
  return useMutation({
    mutationFn: (body: Schemas['CategoryCreate']) =>
      api<Category>('/categories', { method: 'POST', body }),
    onSuccess: () => {
      toast.success('Categoría creada')
      return invalidate()
    },
  })
}

export function useDeleteCategory() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.categories)
  return useMutation({
    mutationFn: (id: string) => api<void>(`/categories/${id}`, { method: 'DELETE' }),
    onSuccess: () => {
      toast.success('Categoría eliminada')
      return invalidate()
    },
  })
}

export const useTransactions = (filters: TransactionFilters) =>
  useQuery({
    queryKey: [...keys.transactions, filters],
    queryFn: () => api<Schemas['TransactionPage']>('/transactions', { query: { ...filters } }),
    placeholderData: keepPreviousData,
  })

export function useSaveTransaction() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.transactions, keys.accounts, keys.budgets, keys.summary)
  return useMutation({
    mutationFn: ({ id, body }: { id?: string; body: TransactionInput }) =>
      id
        ? api<Transaction>(`/transactions/${id}`, { method: 'PUT', body })
        : api<Transaction>('/transactions', { method: 'POST', body }),
    onSuccess: () => {
      toast.success('Movimiento guardado')
      return invalidate()
    },
  })
}

export function useDeleteTransaction() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.transactions, keys.accounts, keys.budgets, keys.summary)
  return useMutation({
    mutationFn: (id: string) => api<void>(`/transactions/${id}`, { method: 'DELETE' }),
    onSuccess: () => {
      toast.success('Movimiento eliminado')
      return invalidate()
    },
  })
}

export const useBudgets = (month: string) =>
  useQuery({
    queryKey: [...keys.budgets, month],
    queryFn: () => api<Budget[]>('/budgets', { query: { month } }),
  })

export function useCreateBudget() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.budgets)
  return useMutation({
    mutationFn: (body: Schemas['BudgetCreate']) =>
      api<Budget>('/budgets', { method: 'POST', body }),
    onSuccess: () => {
      toast.success('Presupuesto creado')
      return invalidate()
    },
  })
}

export function useDeleteBudget() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.budgets)
  return useMutation({
    mutationFn: (id: string) => api<void>(`/budgets/${id}`, { method: 'DELETE' }),
    onSuccess: () => {
      toast.success('Presupuesto eliminado')
      return invalidate()
    },
  })
}

export const useSummary = (month: string) =>
  useQuery({
    queryKey: [...keys.summary, month],
    queryFn: () => api<Summary>('/reports/summary', { query: { month } }),
  })

export function useDeleteAccount() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.accounts)
  return useMutation({
    mutationFn: (id: string) => api<void>(`/accounts/${id}`, { method: 'DELETE' }),
    onSuccess: () => {
      toast.success('Cuenta eliminada')
      return invalidate()
    },
  })
}

export function useRenameCategory() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.categories, keys.budgets, keys.summary)
  return useMutation({
    mutationFn: ({ id, name }: { id: string; name: string }) =>
      api<Category>(`/categories/${id}`, { method: 'PATCH', body: { name } }),
    onSuccess: () => {
      toast.success('Categoría renombrada')
      return invalidate()
    },
  })
}

export function useUpdateBudget() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.budgets)
  return useMutation({
    mutationFn: ({ id, amount }: { id: string; amount: string }) =>
      api<Budget>(`/budgets/${id}`, { method: 'PATCH', body: { amount } }),
    onSuccess: () => {
      toast.success('Presupuesto actualizado')
      return invalidate()
    },
  })
}

export const useGoals = () =>
  useQuery({ queryKey: keys.goals, queryFn: () => api<Goal[]>('/goals') })

export function useCreateGoal() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.goals)
  return useMutation({
    mutationFn: (body: Schemas['GoalCreate']) => api<Goal>('/goals', { method: 'POST', body }),
    onSuccess: () => {
      toast.success('Meta creada')
      return invalidate()
    },
  })
}

export function useDeleteGoal() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.goals)
  return useMutation({
    mutationFn: (id: string) => api<void>(`/goals/${id}`, { method: 'DELETE' }),
    onSuccess: () => {
      toast.success('Meta eliminada')
      return invalidate()
    },
  })
}

export function useContribute() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.goals)
  return useMutation({
    mutationFn: ({ goalId, ...body }: { goalId: string } & Schemas['ContributionCreate']) =>
      api<Contribution>(`/goals/${goalId}/contributions`, { method: 'POST', body }),
    onSuccess: (_data, vars) => {
      toast.success(Number(vars.amount) < 0 ? 'Retiro registrado' : 'Aporte registrado')
      return invalidate()
    },
  })
}

export function useUpdateProfile() {
  const toast = useToast()
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (full_name: string) =>
      api<Schemas['UserOut']>('/auth/me', { method: 'PATCH', body: { full_name } }),
    onSuccess: () => {
      toast.success('Perfil actualizado')
      return qc.invalidateQueries({ queryKey: ['me'] })
    },
  })
}

export function useChangePassword() {
  const toast = useToast()
  return useMutation({
    mutationFn: (body: Schemas['ChangePasswordIn']) =>
      api<Schemas['TokenPair']>('/auth/change-password', { method: 'POST', body }),
    onSuccess: (pair) => {
      // El servidor cierra las demás sesiones y entrega tokens nuevos para esta
      tokens.set(pair)
      toast.success('Contraseña cambiada. Se cerraron las demás sesiones')
    },
  })
}

export function useLogoutAll() {
  return useMutation({ mutationFn: () => api<void>('/auth/logout-all', { method: 'POST' }) })
}

export const useRecurring = () =>
  useQuery({ queryKey: keys.recurring, queryFn: () => api<Recurring[]>('/recurring') })

export function useCreateRecurring() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.recurring)
  return useMutation({
    mutationFn: (body: Schemas['RecurringCreate']) =>
      api<Recurring>('/recurring', { method: 'POST', body }),
    onSuccess: () => {
      toast.success('Movimiento recurrente creado')
      return invalidate()
    },
  })
}

export function useUpdateRecurring() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.recurring)
  return useMutation({
    mutationFn: ({ id, ...body }: { id: string } & Schemas['RecurringUpdate']) =>
      api<Recurring>(`/recurring/${id}`, { method: 'PATCH', body }),
    onSuccess: (_d, vars) => {
      toast.success(vars.active === false ? 'Recurrente pausado' : 'Recurrente actualizado')
      return invalidate()
    },
  })
}

export function useDeleteRecurring() {
  const toast = useToast()
  const invalidate = useInvalidate(keys.recurring)
  return useMutation({
    mutationFn: (id: string) => api<void>(`/recurring/${id}`, { method: 'DELETE' }),
    onSuccess: () => {
      toast.success('Recurrente eliminado')
      return invalidate()
    },
  })
}

/** Registra los movimientos recurrentes vencidos (una vez por sesión) y refresca lo derivado. */
export function useRunDueRecurring(enabled: boolean) {
  const qc = useQueryClient()
  const toast = useToast()
  return useQuery({
    queryKey: ['recurring-run'],
    enabled,
    staleTime: Infinity,
    retry: false,
    queryFn: async () => {
      const { created } = await api<Schemas['RunResult']>('/recurring/run', {
        method: 'POST',
        query: { today: todayISO() },
      })
      if (created > 0) {
        toast.success(
          created === 1
            ? 'Se registró 1 movimiento recurrente'
            : `Se registraron ${created} movimientos recurrentes`,
        )
        await Promise.all(
          [keys.transactions, keys.accounts, keys.budgets, keys.summary, keys.recurring].map(
            (queryKey) => qc.invalidateQueries({ queryKey }),
          ),
        )
      }
      return created
    },
  })
}
