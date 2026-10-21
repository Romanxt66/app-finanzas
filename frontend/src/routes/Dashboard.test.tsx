import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { vi } from 'vitest'
import { account, category, mockApi, page, renderApp, transaction } from '../test-utils'
import { DashboardPage } from './Dashboard'

afterEach(() => vi.restoreAllMocks())

const months = ['2025-10-01', '2025-11-01', '2025-12-01', '2026-01-01', '2026-02-01', '2026-03-01']
const summary = (over = {}) => ({
  month: '2026-03-01',
  currency: 'COP',
  currencies: ['COP'],
  income: '1000.00',
  expense: '250.00',
  net: '750.00',
  expense_by_category: [
    { category_id: 'c1', total: '150.00' },
    { category_id: null, total: '100.00' },
  ],
  trend: months.map((month) => ({ month, income: '0', expense: '0' })),
  ...over,
})
const base = {
  'GET /categories': [category()],
  'GET /transactions': page([transaction()]),
  'GET /recurring': [],
}

describe('DashboardPage · insights', () => {
  it('muestra la dona con su descripción accesible y porcentajes en la leyenda', async () => {
    mockApi({
      ...base,
      'GET /accounts': [account({ currency: 'COP' })],
      'GET /reports/summary': summary(),
    })
    renderApp(<DashboardPage />)
    const donut = await screen.findByRole('img', { name: /Distribución del gasto/ })
    expect(donut).toHaveAccessibleName('Distribución del gasto: Comida 60 %, Sin categoría 40 %')
    expect(donut.querySelectorAll('.cr-donut-seg')).toHaveLength(2)
    const legend = screen.getByRole('list', { name: 'Gasto por categoría' })
    expect(within(legend).getByText('60 %')).toBeInTheDocument()
    expect(within(legend).getByText('40 %')).toBeInTheDocument()
  })

  it('tasa de ahorro: positiva y en contra', async () => {
    mockApi({ ...base, 'GET /accounts': [account()], 'GET /reports/summary': summary() })
    const { unmount } = renderApp(<DashboardPage />)
    expect(await screen.findByText('Ahorraste el 75 % de tus ingresos')).toBeInTheDocument()
    unmount()
    mockApi({
      ...base,
      'GET /accounts': [account()],
      'GET /reports/summary': summary({ income: '100.00', expense: '150.00', net: '-50.00' }),
    })
    renderApp(<DashboardPage />)
    expect(await screen.findByText('Gastaste 50 % más de lo que ingresó')).toBeInTheDocument()
  })

  it('sin ingresos no inventa una tasa', async () => {
    mockApi({
      ...base,
      'GET /accounts': [account()],
      'GET /reports/summary': summary({ income: '0.00', net: '-250.00' }),
    })
    renderApp(<DashboardPage />)
    await screen.findByText('Neto del mes')
    expect(screen.queryByText(/Ahorraste|Gastaste \d/)).not.toBeInTheDocument()
  })

  it('con varias monedas ofrece selector, pide la elegida y suma solo sus cuentas', async () => {
    const calls = mockApi({
      ...base,
      'GET /accounts': [
        account({ id: 'a1', currency: 'COP', balance: '7000.00' }),
        account({ id: 'a2', currency: 'USD', balance: '55.00' }),
      ],
      'GET /reports/summary': ({ url }: { url: URL }) =>
        url.searchParams.get('currency') === 'USD'
          ? summary({
              currency: 'USD',
              currencies: ['COP', 'USD'],
              income: '300.00',
              expense: '0.00',
              net: '300.00',
              expense_by_category: [],
            })
          : summary({ currencies: ['COP', 'USD'] }),
    })
    renderApp(<DashboardPage />)
    const group = await screen.findByRole('group', { name: 'Moneda' })
    expect(await screen.findByText(/7\.000/)).toBeInTheDocument() // saldo COP; los 55 USD no se suman
    expect(screen.queryByText(/7\.055|55/)).not.toBeInTheDocument()
    await userEvent.click(within(group).getByRole('button', { name: 'USD' }))
    await waitFor(() =>
      expect(
        calls.some((c) => c.path === '/reports/summary' && c.query.get('currency') === 'USD'),
      ).toBe(true),
    )
    await waitFor(() => expect(screen.getByText(/US\$\s*55/)).toBeInTheDocument()) // ahora el saldo es el de USD
    expect(within(group).getByRole('button', { name: 'USD' })).toHaveAttribute(
      'aria-pressed',
      'true',
    )
  })

  it('con una sola moneda no muestra selector', async () => {
    mockApi({ ...base, 'GET /accounts': [account()], 'GET /reports/summary': summary() })
    renderApp(<DashboardPage />)
    await screen.findByText('Saldo total')
    expect(screen.queryByRole('group', { name: 'Moneda' })).not.toBeInTheDocument()
  })
})

describe('DashboardPage · primeros pasos', () => {
  const empty = {
    'GET /reports/summary': summary({
      currency: null,
      currencies: [],
      income: '0',
      expense: '0',
      net: '0',
      expense_by_category: [],
    }),
    'GET /recurring': [],
  }

  it('usuario nuevo: guía con los 3 pasos pendientes y acceso a importar', async () => {
    mockApi({ ...empty, 'GET /accounts': [], 'GET /categories': [], 'GET /transactions': page([]) })
    renderApp(<DashboardPage />)
    const steps = await screen.findByRole('list', { name: 'Primeros pasos' })
    expect(
      within(steps)
        .getAllByRole('link')
        .map((l) => l.getAttribute('href')),
    ).toEqual(['/accounts', '/categories', '/transactions'])
    expect(within(steps).getAllByText('(pendiente)')).toHaveLength(3)
    expect(screen.getByRole('link', { name: 'importar el CSV de tu banco' })).toHaveAttribute(
      'href',
      '/import',
    )
  })

  it('marca los pasos hechos y desaparece al completar todos', async () => {
    mockApi({
      ...empty,
      'GET /accounts': [account()],
      'GET /categories': [],
      'GET /transactions': page([]),
    })
    const { unmount } = renderApp(<DashboardPage />)
    const steps = await screen.findByRole('list', { name: 'Primeros pasos' })
    expect(within(steps).getAllByText('(hecho)')).toHaveLength(1)
    unmount()
    mockApi({
      ...empty,
      'GET /accounts': [account()],
      'GET /categories': [category()],
      'GET /transactions': page([transaction()]),
    })
    renderApp(<DashboardPage />)
    await screen.findByText('Saldo total')
    await waitFor(() =>
      expect(screen.queryByRole('list', { name: 'Primeros pasos' })).not.toBeInTheDocument(),
    )
  })
})
