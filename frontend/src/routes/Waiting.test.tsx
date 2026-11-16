import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, expect, test, vi } from 'vitest'
import { mockApi, renderApp, user } from '../test-utils'
import { timeLeft, WaitingRoomPage } from './Waiting'

afterEach(() => vi.restoreAllMocks())

const item = (over = {}) => ({
  id: 'w1',
  created_at: new Date(Date.now() - 3_600_000).toISOString(),
  name: 'Audífonos',
  amount: '300000.00',
  currency: 'COP',
  wait_hours: 72,
  ready_at: new Date(Date.now() + 71 * 3_600_000).toISOString(),
  status: 'waiting',
  decided_at: null,
  ready: false,
  ...over,
})

const room = (items: unknown[], extra = {}) => ({
  items,
  waiting: 1,
  ready: 0,
  skipped: 0,
  bought: 0,
  not_spent: [],
  ...extra,
})

test('timeLeft resume lo que falta', () => {
  expect(timeLeft(30_000)).toBe('menos de un minuto')
  expect(timeLeft(40 * 60_000)).toBe('40 min')
  expect(timeLeft((2 * 24 + 5) * 3_600_000)).toBe('2 d 5 h')
})

test('muestra la cuenta atrás y deja descartar la compra', async () => {
  const calls = mockApi({
    'GET /auth/me': user,
    'GET /waiting-room': room([item()]),
    'POST /waiting-room/w1/decide': { ...item(), status: 'skipped' },
    'GET /goals': [
      {
        id: 'g1',
        created_at: '2026-01-01T00:00:00Z',
        name: 'Viaje',
        target_amount: '3000000.00',
        currency: 'COP',
        deadline: null,
        saved: '0.00',
        remaining: '3000000.00',
        achieved: false,
      },
    ],
    'POST /goals/g1/contributions': { status: 201, body: {} },
  })
  renderApp(<WaitingRoomPage />)
  const list = await screen.findByRole('list', { name: 'En espera' })
  expect(within(list).getByText('Audífonos')).toBeInTheDocument()
  expect(within(list).getByText(/Faltan 2 d \d+ h para decidir/)).toBeInTheDocument()
  // Antes del plazo no se puede marcar como comprada
  expect(within(list).queryByRole('button', { name: 'La compré' })).not.toBeInTheDocument()
  await userEvent.click(within(list).getByRole('button', { name: 'Ya no la quiero' }))
  await vi.waitFor(() =>
    expect(calls.find((c) => c.path === '/waiting-room/w1/decide')?.body).toEqual({
      decision: 'skipped',
    }),
  )
  // Ofrece apartar lo que no gastó en una meta de la misma moneda
  const dialog = await screen.findByRole('dialog', { name: '¿Lo mandas a una meta?' })
  await userEvent.click(within(dialog).getByRole('button', { name: 'Viaje' }))
  await vi.waitFor(() =>
    expect(calls.find((c) => c.path === '/goals/g1/contributions')?.body).toMatchObject({
      amount: '300000',
    }),
  )
})

test('añade una compra en espera con el plazo elegido', async () => {
  const calls = mockApi({
    'GET /auth/me': user,
    'GET /waiting-room': room([], { waiting: 0 }),
    'GET /currencies': ['COP', 'USD'],
    'POST /waiting-room': { status: 201, body: item() },
  })
  renderApp(<WaitingRoomPage />)
  expect(await screen.findByText('Aún nada… ¡pero pronto!')).toBeInTheDocument()
  await userEvent.type(screen.getByLabelText('Qué quieres comprar'), 'Audífonos')
  await userEvent.type(screen.getByLabelText('Precio'), '300000')
  await userEvent.selectOptions(screen.getByLabelText('Moneda'), 'COP')
  await userEvent.click(screen.getByRole('button', { name: '1 semana' }))
  await userEvent.click(screen.getByRole('button', { name: 'Dejar en espera' }))
  await vi.waitFor(() =>
    expect(calls.find((c) => c.method === 'POST')?.body).toEqual({
      name: 'Audífonos',
      amount: '300000',
      currency: 'COP',
      wait_hours: 168,
    }),
  )
})
