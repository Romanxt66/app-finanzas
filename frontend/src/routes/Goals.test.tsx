import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, expect, test, vi } from 'vitest'
import { mockApi, renderApp, user } from '../test-utils'
import { GoalsPage } from './Goals'

afterEach(() => vi.restoreAllMocks())

const goal = {
  id: 'g1',
  created_at: '2026-01-01T00:00:00Z',
  name: 'Viaje',
  target_amount: '3000000.00',
  currency: 'COP',
  deadline: '2027-06-01',
  saved: '0.00',
  remaining: '3000000.00',
  achieved: false,
}

test('editar una meta envía solo lo que cambió y vaciar la fecha la quita', async () => {
  const calls = mockApi({
    'GET /auth/me': user,
    'GET /goals': [goal],
    'PATCH /goals/g1': (req: { body: unknown }) => ({ ...goal, ...(req.body as object) }),
  })
  renderApp(<GoalsPage />)
  await userEvent.click(await screen.findByRole('button', { name: 'Editar Viaje' }))
  const dialog = await screen.findByRole('dialog')
  const target = within(dialog).getByLabelText('Monto objetivo (COP)')
  await userEvent.clear(target)
  await userEvent.type(target, '4000000')
  await userEvent.clear(within(dialog).getByLabelText('Fecha límite (vacía: sin fecha)'))
  await userEvent.click(within(dialog).getByRole('button', { name: 'Guardar' }))
  await vi.waitFor(() =>
    expect(calls.find((c) => c.method === 'PATCH')?.body).toEqual({
      target_amount: '4000000',
      deadline: null,
    }),
  )
})

test('con el plazo vencido no dice «para el …» como si aún hubiera tiempo', async () => {
  mockApi({ 'GET /auth/me': user, 'GET /goals': [{ ...goal, deadline: '2020-03-01' }] })
  renderApp(<GoalsPage />)
  expect(await screen.findByText(/el plazo venció el/)).toBeInTheDocument()
  expect(screen.queryByText(/para el/)).not.toBeInTheDocument()
})

test('el historial lista los aportes y deja borrar uno con confirmación', async () => {
  const calls = mockApi({
    'GET /auth/me': user,
    'GET /goals': [goal],
    'GET /goals/g1/contributions': [
      { id: 'c1', goal_id: 'g1', amount: '50000.00', occurred_on: '2026-10-01', note: 'Prima' },
      { id: 'c2', goal_id: 'g1', amount: '-20000.00', occurred_on: '2026-11-02', note: '' },
    ],
    'DELETE /goals/g1/contributions/c2': { status: 204, body: null },
  })
  renderApp(<GoalsPage />)
  await userEvent.click(await screen.findByRole('button', { name: 'Historial de Viaje' }))
  const list = await screen.findByRole('list', { name: 'Aportes' })
  // Del más reciente al más antiguo
  const rows = within(list).getAllByRole('listitem')
  expect(rows[0]).toHaveTextContent(/2 de nov/)
  expect(rows[1]).toHaveTextContent('Prima')
  await userEvent.click(within(rows[0]).getByRole('button', { name: /Eliminar aporte/ }))
  await userEvent.click(within(rows[0]).getByRole('button', { name: 'Eliminar' }))
  await vi.waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true))
})
