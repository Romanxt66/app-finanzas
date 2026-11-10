import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { mockApi, renderApp } from '../test-utils'
import { BudgetHomeCard } from './BudgetHomeCard'

const b = (over: Record<string, unknown>) => ({
  id: 'b1',
  created_at: '2026-01-01T00:00:00Z',
  category_id: null,
  period: 'day',
  month: '2026-11-10',
  start: '2026-11-10',
  end: '2026-11-10',
  starts_on: '2026-11-10',
  recurring: true,
  amount: '50000.00',
  spent: '20000.00',
  remaining: '30000.00',
  ...over,
})

describe('tarjeta de presupuesto del inicio', () => {
  beforeEach(() => localStorage.clear())

  it('elige Hoy / Semana / Mes, lo recuerda y prefiere el general', async () => {
    const calls = mockApi({
      'GET /accounts': [],
      'GET /budgets': ({ url }: { url: URL }) =>
        url.searchParams.get('period') === 'day'
          ? [b({}), b({ id: 'b2', category_id: 'c1', amount: '10000.00', spent: '9000.00' })]
          : [],
    })
    renderApp(<BudgetHomeCard />)
    expect(await screen.findByText(/Aún no tienes presupuesto para este mes/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Hoy' }))
    expect(await screen.findByText('Te queda hoy')).toBeInTheDocument()
    // Manda el general (50.000), no la suma con la categoría
    expect(screen.getByText(/20\.000 de .*50\.000/)).toBeInTheDocument()
    expect(localStorage.getItem('home_budget_period')).toBe('day')
    await waitFor(() =>
      expect(calls.some((c) => c.path === '/budgets' && c.query.get('period') === 'day')).toBe(
        true,
      ),
    )
  })
})
