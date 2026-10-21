import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { vi } from 'vitest'
import { DailyAllowanceCard } from '../features/DailyAllowanceCard'
import { LifeHoursCard } from '../features/LifeHoursCard'
import { account, mockApi, renderApp } from '../test-utils'
import { SubscriptionsPage } from './Subscriptions'

afterEach(() => vi.restoreAllMocks())

const allowance = (over = {}) => ({
  day: '2026-10-21',
  currency: 'EUR',
  basis: 'budget',
  month_total: '1000.00',
  spent_before_today: '200.00',
  spent_today: '20.00',
  pending_committed: '100.00',
  days_remaining: 11,
  average_per_day: '63.64',
  allowance_today: '63.64',
  left_today: '43.64',
  pattern_used: true,
  status: 'ok',
  ...over,
})

describe('DailyAllowanceCard', () => {
  it('muestra lo que queda hoy y cómo se calculó', async () => {
    mockApi({ 'GET /daily-allowance': allowance() })
    renderApp(<DailyAllowanceCard />)
    expect(await screen.findByText('Disponible hoy')).toBeInTheDocument()
    expect(screen.getByText('Vas dentro de tu ritmo.')).toBeInTheDocument()
    expect(screen.getByText(/Quedan 11 días/)).toBeInTheDocument()
    expect(screen.getByText(/Según tu presupuesto del mes/)).toBeInTheDocument()
    expect(screen.getByText(/ajustado a tus hábitos/)).toBeInTheDocument()
  })

  it('avisa cuando hoy ya se pasó del ritmo', async () => {
    mockApi({ 'GET /daily-allowance': allowance({ status: 'tight', left_today: '-10.00' }) })
    renderApp(<DailyAllowanceCard />)
    expect(await screen.findByText('Hoy ya superaste lo que te tocaba.')).toBeInTheDocument()
  })

  it('explica qué falta cuando no hay base de cálculo', async () => {
    mockApi({
      'GET /daily-allowance': allowance({
        status: 'no_data',
        month_total: '0.00',
        left_today: '0.00',
      }),
    })
    renderApp(<DailyAllowanceCard />)
    expect(await screen.findByText(/Define un presupuesto del mes/)).toBeInTheDocument()
    expect(screen.queryByText(/Quedan/)).not.toBeInTheDocument()
  })

  it('no muestra nada si aún no hay cuentas (404)', async () => {
    mockApi({})
    const { container } = renderApp(<DailyAllowanceCard />)
    await waitFor(() => expect(container.querySelector('.cr-skeleton')).toBeNull())
    expect(screen.queryByText('Disponible hoy')).not.toBeInTheDocument()
  })
})

describe('LifeHoursCard', () => {
  it('invita a configurar el valor de la hora y lo guarda con vista previa', async () => {
    const calls = mockApi({
      'GET /life-hours/profile': {
        status: 404,
        body: { error: { code: 'not_found', message: 'x' } },
      },
      'GET /accounts': [account({ currency: 'EUR' })],
      'GET /categories': [],
      'PUT /life-hours/profile': {
        monthly_net_income: '2000.00',
        weekly_hours: '40',
        hourly_rate: '11.54',
      },
    })
    renderApp(<LifeHoursCard month="2026-10-01" />)
    await userEvent.click(await screen.findByRole('button', { name: 'Configurar' }))
    await userEvent.type(screen.getByLabelText('Ingreso neto mensual'), '2000')
    expect(await screen.findByText(/Tu hora vale ≈/)).toHaveTextContent('11,54')
    await userEvent.click(screen.getByRole('button', { name: 'Guardar' }))
    await waitFor(() => expect(calls.some((c) => c.method === 'PUT')).toBe(true))
    expect(calls.find((c) => c.method === 'PUT')?.body).toEqual({
      monthly_net_income: '2000',
      weekly_hours: '40',
    })
  })

  it('rechaza horas semanales imposibles', async () => {
    mockApi({
      'GET /life-hours/profile': {
        status: 404,
        body: { error: { code: 'not_found', message: 'x' } },
      },
      'GET /accounts': [],
      'GET /categories': [],
    })
    renderApp(<LifeHoursCard month="2026-10-01" />)
    await userEvent.click(await screen.findByRole('button', { name: 'Configurar' }))
    await userEvent.type(screen.getByLabelText('Ingreso neto mensual'), '2000')
    await userEvent.clear(screen.getByLabelText('Horas de trabajo por semana'))
    await userEvent.type(screen.getByLabelText('Horas de trabajo por semana'), '200')
    await userEvent.click(screen.getByRole('button', { name: 'Guardar' }))
    expect(await screen.findByText('Entre 1 y 168 horas')).toBeInTheDocument()
  })

  it('con perfil muestra las horas del mes y las categorías que más cuestan', async () => {
    mockApi({
      'GET /life-hours/profile': {
        monthly_net_income: '2000.00',
        weekly_hours: '40.00',
        hourly_rate: '11.54',
      },
      'GET /life-hours/summary': {
        month: '2026-10-01',
        hourly_rate: '11.54',
        total: '46.16',
        total_hours: '4.00',
        by_category: [{ category_id: 'c1', total: '46.16', hours: '4.00' }],
      },
      'GET /accounts': [account({ currency: 'EUR' })],
      'GET /categories': [{ id: 'c1', created_at: '', name: 'Comida', kind: 'expense' }],
    })
    renderApp(<LifeHoursCard month="2026-10-01" />)
    // total del mes y fila de la categoría
    expect(await screen.findAllByText('4 h')).toHaveLength(2)
    expect(screen.getByText('Comida')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Editar' })).toBeInTheDocument()
  })
})

const report = {
  subscriptions: [
    {
      name: 'Netflix',
      currency: 'EUR',
      cadence: 'monthly',
      typical_amount: '10.99',
      last_amount: '12.99',
      last_date: '2026-10-05',
      next_expected: '2026-11-05',
      occurrences: 4,
      monthly_cost: '10.99',
      tracked: false,
    },
    {
      name: 'Gimnasio',
      currency: 'EUR',
      cadence: 'monthly',
      typical_amount: '30.00',
      last_amount: '30.00',
      last_date: '2026-10-01',
      next_expected: '2026-11-01',
      occurrences: 6,
      monthly_cost: '30.00',
      tracked: true,
    },
  ],
  alerts: [
    {
      kind: 'price_increase',
      name: 'Netflix',
      currency: 'EUR',
      date: '2026-10-05',
      amount: '12.99',
      previous_amount: '10.99',
      change_percent: '18.20',
    },
  ],
  untracked_monthly: [{ currency: 'EUR', total: '10.99' }],
}

describe('SubscriptionsPage', () => {
  it('separa los cobros fantasma de los ya registrados y lista las alertas', async () => {
    mockApi({ 'GET /ghost-subscriptions': report })
    renderApp(<SubscriptionsPage />)
    expect(await screen.findByRole('list', { name: 'Cobros sin registrar' })).toHaveTextContent(
      'Netflix',
    )
    expect(screen.getByRole('list', { name: 'Cobros ya registrados' })).toHaveTextContent(
      'Gimnasio',
    )
    expect(screen.getByRole('list', { name: 'Alertas' })).toHaveTextContent(
      /subió de .* a .*18,2 %/,
    )
    expect(screen.getByRole('link', { name: 'Recurrentes' })).toHaveAttribute('href', '/recurring')
  })

  it('pide los datos con la fecha local del navegador', async () => {
    const calls = mockApi({ 'GET /ghost-subscriptions': report })
    renderApp(<SubscriptionsPage />)
    await screen.findByText('Alertas')
    expect(calls[0].query.get('today')).toMatch(/^\d{4}-\d{2}-\d{2}$/)
  })

  it('estado vacío cuando no se detecta nada', async () => {
    mockApi({
      'GET /ghost-subscriptions': { subscriptions: [], alerts: [], untracked_monthly: [] },
    })
    renderApp(<SubscriptionsPage />)
    expect(await screen.findByText(/Aún no detectamos cobros recurrentes/)).toBeInTheDocument()
  })
})
