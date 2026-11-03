import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render } from '@testing-library/react'
import type { ReactElement } from 'react'
import { MemoryRouter } from 'react-router-dom'
import { vi } from 'vitest'
import type { Schemas } from './api/client'
import { AuthProvider } from './features/auth'

type Handler = unknown | ((req: { url: URL; body: unknown }) => unknown)
export type Routes = Record<string, Handler | { status: number; body: unknown }>

export interface Call {
  method: string
  path: string
  query: URLSearchParams
  body: unknown
}

/** Sustituye fetch por un router en memoria: clave = "MÉTODO /ruta" (sin /api/v1). */
export function mockApi(routes: Routes) {
  const calls: Call[] = []
  vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
    const url = new URL(String(input), 'http://localhost')
    const method = init?.method ?? 'GET'
    const path = url.pathname.replace('/api/v1', '')
    const body = init?.body ? JSON.parse(String(init.body)) : undefined
    calls.push({ method, path, query: url.searchParams, body })
    const route = routes[`${method} ${path}`]
    if (route === undefined) {
      return new Response(
        JSON.stringify({ error: { code: 'not_found', message: `Sin mock: ${method} ${path}` } }),
        { status: 404 },
      )
    }
    const result = typeof route === 'function' ? route({ url, body }) : route
    const { status, body: payload } =
      result && typeof result === 'object' && 'status' in result && 'body' in result
        ? (result as { status: number; body: unknown })
        : { status: 200, body: result }
    if (status === 204) return new Response(null, { status })
    return new Response(JSON.stringify(payload), {
      status,
      headers: { 'Content-Type': 'application/json' },
    })
  })
  return calls
}

export function renderApp(ui: ReactElement, { route = '/', authed = true } = {}) {
  localStorage.clear()
  if (authed) {
    localStorage.setItem('access_token', 'a')
    localStorage.setItem('refresh_token', 'r')
  }
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(
    <QueryClientProvider client={client}>
      <AuthProvider>
        <MemoryRouter initialEntries={[route]}>{ui}</MemoryRouter>
      </AuthProvider>
    </QueryClientProvider>,
  )
}

// Fábricas de datos de prueba (solo para tests)
export const user: Schemas['UserOut'] = {
  id: 'u1',
  email: 'x@example.com',
  full_name: 'Ana Test',
  two_factor_enabled: false,
}

export const account = (over: Partial<Schemas['AccountOut']> = {}): Schemas['AccountOut'] => ({
  id: 'a1',
  created_at: '2026-01-01T00:00:00Z',
  name: 'Banco',
  type: 'bank',
  currency: 'EUR',
  initial_balance: '100.00',
  archived: false,
  balance: '150.00',
  ...over,
})

export const category = (over: Partial<Schemas['CategoryOut']> = {}): Schemas['CategoryOut'] => ({
  id: 'c1',
  created_at: '2026-01-01T00:00:00Z',
  name: 'Comida',
  kind: 'expense',
  ...over,
})

export const transaction = (
  over: Partial<Schemas['TransactionOut']> = {},
): Schemas['TransactionOut'] => ({
  id: 't1',
  created_at: '2026-01-01T00:00:00Z',
  type: 'expense',
  account_id: 'a1',
  transfer_account_id: null,
  category_id: 'c1',
  amount: '12.50',
  description: 'Almuerzo',
  occurred_on: '2026-03-10',
  ...over,
})

export const page = (items: Schemas['TransactionOut'][], total = items.length) => ({
  items,
  total,
  limit: 20,
  offset: 0,
})
