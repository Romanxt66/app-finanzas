import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Route, Routes } from 'react-router-dom'
import { vi } from 'vitest'
import { ToastProvider } from '../design'
import { account, category, mockApi, renderApp, user } from '../test-utils'
import { Layout } from './Layout'
import { RecurringPage } from './Recurring'

afterEach(() => vi.restoreAllMocks())

const rule = (over = {}) => ({
  id: 'r1',
  created_at: '2026-01-01T00:00:00Z',
  type: 'expense',
  account_id: 'a1',
  transfer_account_id: null,
  category_id: 'c1',
  amount: '800000.00',
  description: 'Arriendo',
  frequency: 'monthly',
  next_date: '2026-05-31',
  end_date: null,
  active: true,
  ...over,
})

const base = { 'GET /accounts': [account()], 'GET /categories': [category()] }

describe('RecurringPage', () => {
  it('lista reglas con frecuencia, próxima fecha y estado', async () => {
    mockApi({
      ...base,
      'GET /recurring': [
        rule(),
        rule({ id: 'r2', description: 'Gimnasio', active: false, frequency: 'weekly' }),
      ],
    })
    renderApp(<RecurringPage />)
    expect(await screen.findByText('Arriendo')).toBeInTheDocument()
    expect(screen.getByText(/Cada mes · próximo: 31 de may/)).toBeInTheDocument()
    expect(screen.getByText(/Cada semana · pausado/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Pausar Arriendo' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Reanudar Gimnasio' })).toBeInTheDocument()
  })

  it('estado vacío', async () => {
    mockApi({ ...base, 'GET /recurring': [] })
    renderApp(<RecurringPage />)
    expect(await screen.findByText(/Aún no tienes movimientos recurrentes/)).toBeInTheDocument()
  })

  it('valida fechas y campos antes de enviar', async () => {
    const calls = mockApi({ ...base, 'GET /recurring': [] })
    renderApp(<RecurringPage />)
    await screen.findByRole('option', { name: /Banco/ })
    await userEvent.type(screen.getByLabelText('Monto'), '100')
    await userEvent.selectOptions(screen.getByLabelText('Cuenta'), 'a1')
    await userEvent.clear(screen.getByLabelText('Primera fecha'))
    await userEvent.type(screen.getByLabelText('Primera fecha'), '2026-05-10')
    await userEvent.type(screen.getByLabelText('Hasta (opcional)'), '2026-04-01')
    await userEvent.click(screen.getByRole('button', { name: 'Crear recurrente' }))
    expect(
      await screen.findByText('La fecha final no puede ser anterior a la inicial'),
    ).toBeInTheDocument()
    expect(calls.some((c) => c.method === 'POST')).toBe(false)
  })

  it('crea un gasto mensual y limpia opcionales vacíos', async () => {
    const calls = mockApi({
      ...base,
      'GET /recurring': [],
      'POST /recurring': { status: 201, body: rule() },
    })
    renderApp(<RecurringPage />)
    await screen.findByRole('option', { name: /Banco/ })
    await userEvent.selectOptions(screen.getByLabelText('Cuenta'), 'a1')
    await screen.findByRole('option', { name: 'Comida' })
    await userEvent.selectOptions(screen.getByLabelText('Categoría'), 'c1')
    await userEvent.type(screen.getByLabelText('Monto'), '800000')
    await userEvent.type(screen.getByLabelText('Descripción'), 'Arriendo')
    await userEvent.click(screen.getByRole('button', { name: 'Crear recurrente' }))
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true))
    expect(calls.find((c) => c.method === 'POST')?.body).toMatchObject({
      type: 'expense',
      account_id: 'a1',
      category_id: 'c1',
      amount: '800000',
      frequency: 'monthly',
      description: 'Arriendo',
      transfer_account_id: null,
      end_date: null,
    })
  })

  it('una transferencia pide destino y no envía categoría', async () => {
    const calls = mockApi({
      ...base,
      'GET /accounts': [account(), account({ id: 'a2', name: 'Ahorro' })],
      'GET /recurring': [],
      'POST /recurring': { status: 201, body: rule() },
    })
    renderApp(<RecurringPage />)
    await userEvent.selectOptions(await screen.findByLabelText('Tipo'), 'transfer')
    expect(screen.queryByLabelText('Categoría')).not.toBeInTheDocument()
    await screen.findAllByRole('option', { name: /Ahorro/ })
    await userEvent.selectOptions(screen.getByLabelText('Cuenta origen'), 'a1')
    await userEvent.type(screen.getByLabelText('Monto'), '5')
    await userEvent.click(screen.getByRole('button', { name: 'Crear recurrente' }))
    expect(await screen.findByText('Elige la cuenta destino')).toBeInTheDocument()
    await userEvent.selectOptions(screen.getByLabelText('Cuenta destino'), 'a2')
    await userEvent.click(screen.getByRole('button', { name: 'Crear recurrente' }))
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true))
    expect(calls.find((c) => c.method === 'POST')?.body).toMatchObject({
      type: 'transfer',
      transfer_account_id: 'a2',
      category_id: null,
    })
  })

  it('pausa, reanuda y elimina con confirmación', async () => {
    const calls = mockApi({
      ...base,
      'GET /recurring': [rule()],
      'PATCH /recurring/r1': rule({ active: false }),
      'DELETE /recurring/r1': { status: 204, body: null },
    })
    renderApp(<RecurringPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Pausar Arriendo' }))
    await waitFor(() =>
      expect(calls.find((c) => c.method === 'PATCH')?.body).toEqual({ active: false }),
    )
    await userEvent.click(screen.getByRole('button', { name: 'Eliminar' }))
    expect(calls.some((c) => c.method === 'DELETE')).toBe(false)
    await userEvent.click(
      within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Eliminar' }),
    )
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true))
  })
})

describe('registro automático de recurrentes al abrir la app', () => {
  const app = (
    <ToastProvider>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<p>Contenido</p>} />
        </Route>
      </Routes>
    </ToastProvider>
  )

  it('llama a /recurring/run una vez con la fecha local y avisa cuántos se crearon', async () => {
    const calls = mockApi({ 'GET /auth/me': user, 'POST /recurring/run': { created: 3 } })
    renderApp(app)
    expect(await screen.findByText('Contenido')).toBeInTheDocument()
    expect(await screen.findByText('Se registraron 3 movimientos recurrentes')).toBeInTheDocument()
    const runs = calls.filter((c) => c.path === '/recurring/run')
    expect(runs).toHaveLength(1)
    expect(runs[0].query.get('today')).toMatch(/^\d{4}-\d{2}-\d{2}$/)
  })

  it('sin vencidos no muestra aviso', async () => {
    mockApi({ 'GET /auth/me': user, 'POST /recurring/run': { created: 0 } })
    renderApp(app)
    await screen.findByText('Contenido')
    await waitFor(() => expect(screen.getByRole('status', { name: '' })).toBeInTheDocument())
    expect(screen.queryByText(/Se registr/)).not.toBeInTheDocument()
  })

  it('si el servidor falla, la app sigue usable', async () => {
    mockApi({ 'GET /auth/me': user, 'POST /recurring/run': { status: 500, body: '' } })
    renderApp(app)
    expect(await screen.findByText('Contenido')).toBeInTheDocument()
  })
})
