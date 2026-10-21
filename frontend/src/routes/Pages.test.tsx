import { act, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Route, Routes } from 'react-router-dom'
import { vi } from 'vitest'
import { account, category, mockApi, page, renderApp, transaction, user } from '../test-utils'
import { AccountsPage } from './Accounts'
import { BudgetsPage } from './Budgets'
import { CategoriesPage } from './Categories'
import { DashboardPage } from './Dashboard'
import { Layout } from './Layout'
import { TransactionsPage } from './Transactions'

afterEach(() => vi.restoreAllMocks())

describe('Layout', () => {
  const app = (
    <Routes>
      <Route path="/login" element={<p>Pantalla login</p>} />
      <Route element={<Layout />}>
        <Route index element={<p>Contenido</p>} />
      </Route>
    </Routes>
  )

  it('redirige a login sin sesión', async () => {
    mockApi({})
    renderApp(app, { authed: false })
    expect(await screen.findByText('Pantalla login')).toBeInTheDocument()
  })

  it('avisa cuando no hay conexión y lo retira al volver', async () => {
    mockApi({ 'GET /auth/me': user })
    renderApp(app)
    await screen.findByText('Contenido')
    expect(screen.queryByText(/Sin conexión/)).not.toBeInTheDocument()
    vi.spyOn(navigator, 'onLine', 'get').mockReturnValue(false)
    act(() => void window.dispatchEvent(new Event('offline')))
    expect(await screen.findByText(/Sin conexión/)).toBeInTheDocument()
    vi.spyOn(navigator, 'onLine', 'get').mockReturnValue(true)
    act(() => void window.dispatchEvent(new Event('online')))
    await waitFor(() => expect(screen.queryByText(/Sin conexión/)).not.toBeInTheDocument())
  })

  it('muestra navegación y nombre del usuario, y cierra sesión', async () => {
    mockApi({ 'GET /auth/me': user })
    renderApp(app)
    expect(await screen.findByText('Contenido')).toBeInTheDocument()
    expect(screen.getByText('Ana Test')).toBeInTheDocument()
    // barra superior (escritorio) y pestañas (móvil) existen a la vez en el DOM; el CSS muestra una
    const count = (name: string) => screen.getAllByRole('link', { name }).length
    for (const shared of ['Inicio', 'Movimientos', 'Cuentas', 'Metas'])
      expect(count(shared)).toBe(2)
    for (const desktopOnly of ['Presupuestos', 'Recurrentes', 'Categorías'])
      expect(count(desktopOnly)).toBe(1)
    expect(count('Más')).toBe(1) // solo móvil
    expect(screen.getByRole('link', { name: 'Ana Test' })).toHaveAttribute('href', '/profile')
    await userEvent.click(screen.getByRole('button', { name: 'Salir' }))
    expect(await screen.findByText('Pantalla login')).toBeInTheDocument()
    expect(localStorage.getItem('access_token')).toBeNull()
  })
})

describe('AccountsPage', () => {
  it('lista cuentas con saldo formateado y estado vacío', async () => {
    mockApi({
      'GET /accounts': [account(), account({ id: 'a2', name: 'Efectivo', archived: true })],
    })
    renderApp(<AccountsPage />)
    expect(await screen.findByText('Restaurar')).toBeInTheDocument()
    expect(screen.getByText('Archivar')).toBeInTheDocument()
    expect(screen.getAllByText(/150/)[0]).toBeInTheDocument()
  })

  it('muestra estado vacío', async () => {
    mockApi({ 'GET /accounts': [] })
    renderApp(<AccountsPage />)
    expect(await screen.findByText('Aún no tienes cuentas.')).toBeInTheDocument()
  })

  it('valida y crea una cuenta', async () => {
    const calls = mockApi({
      'GET /accounts': [],
      'GET /currencies': ['EUR', 'COP'],
      'POST /accounts': { status: 201, body: account() },
    })
    renderApp(<AccountsPage />)
    await userEvent.click(screen.getByRole('button', { name: 'Crear cuenta' }))
    expect(await screen.findByText('Requerido')).toBeInTheDocument()
    expect(screen.getByText('Selecciona una moneda')).toBeInTheDocument()

    await userEvent.type(screen.getByLabelText('Nombre'), 'Ahorros')
    await userEvent.selectOptions(await screen.findByLabelText('Moneda'), 'EUR')
    await userEvent.clear(screen.getByLabelText('Saldo inicial'))
    await userEvent.type(screen.getByLabelText('Saldo inicial'), '25.5')
    await userEvent.click(screen.getByRole('button', { name: 'Crear cuenta' }))
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true))
    expect(calls.find((c) => c.method === 'POST')?.body).toMatchObject({
      name: 'Ahorros',
      type: 'bank',
      currency: 'EUR',
      initial_balance: '25.5',
    })
  })

  it('archiva una cuenta', async () => {
    const calls = mockApi({ 'GET /accounts': [account()], 'PATCH /accounts/a1': account() })
    renderApp(<AccountsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Archivar' }))
    await waitFor(() =>
      expect(calls.find((c) => c.method === 'PATCH')?.body).toEqual({ archived: true }),
    )
  })

  it('muestra el error de la API al crear', async () => {
    mockApi({
      'GET /accounts': [],
      'GET /currencies': ['EUR', 'COP'],
      'POST /accounts': {
        status: 400,
        body: { error: { code: 'bad_request', message: 'Moneda no válida' } },
      },
    })
    renderApp(<AccountsPage />)
    await userEvent.type(screen.getByLabelText('Nombre'), 'X')
    await userEvent.selectOptions(await screen.findByLabelText('Moneda'), 'EUR')
    await userEvent.click(screen.getByRole('button', { name: 'Crear cuenta' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Moneda no válida')
  })
})

describe('CategoriesPage', () => {
  it('agrupa por tipo y permite eliminar', async () => {
    const calls = mockApi({
      'GET /categories': [category(), category({ id: 'c2', name: 'Sueldo', kind: 'income' })],
      'DELETE /categories/c1': { status: 204, body: null },
    })
    renderApp(<CategoriesPage />)
    const expenses = (await screen.findByText('Gastos')).closest('section')!
    expect(within(expenses).getByText('Comida')).toBeInTheDocument()
    expect(within(expenses).queryByText('Sueldo')).not.toBeInTheDocument()
    await userEvent.click(within(expenses).getByRole('button', { name: 'Eliminar' }))
    // pide confirmación antes de borrar
    expect(calls.some((c) => c.method === 'DELETE')).toBe(false)
    const dialog = await screen.findByRole('alertdialog')
    expect(dialog).toHaveTextContent('Comida')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Eliminar' }))
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true))
  })

  it('crea una categoría y muestra conflicto', async () => {
    mockApi({
      'GET /categories': [],
      'POST /categories': {
        status: 409,
        body: { error: { code: 'conflict', message: 'Ya existe una categoría con ese nombre' } },
      },
    })
    renderApp(<CategoriesPage />)
    await userEvent.type(screen.getByLabelText('Nombre'), 'Comida')
    await userEvent.click(screen.getByRole('button', { name: 'Añadir' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Ya existe')
  })
})

describe('TransactionsPage', () => {
  const base = {
    'GET /accounts': [account(), account({ id: 'a2', name: 'Efectivo' })],
    'GET /categories': [category(), category({ id: 'c2', name: 'Sueldo', kind: 'income' })],
  }

  it('lista transacciones con cuenta, categoría y signo', async () => {
    mockApi({
      ...base,
      'GET /transactions': page([
        transaction(),
        transaction({
          id: 't2',
          type: 'income',
          description: 'Pago',
          category_id: 'c2',
          amount: '300',
        }),
      ]),
    })
    renderApp(<TransactionsPage />)
    expect(await screen.findByText('Almuerzo')).toBeInTheDocument()
    expect(screen.getByText('Pago')).toBeInTheDocument()
    expect(screen.getByText(/^−/)).toBeInTheDocument()
    expect(screen.getByText(/^\+/)).toBeInTheDocument()
    expect(screen.getByText('2 resultados')).toBeInTheDocument()
  })

  it('envía filtros a la API y reinicia la página', async () => {
    const calls = mockApi({ ...base, 'GET /transactions': page([]) })
    renderApp(<TransactionsPage />)
    await screen.findByText('No hay transacciones.')
    await userEvent.type(screen.getByLabelText('Buscar'), 'café')
    await userEvent.selectOptions(screen.getByLabelText('Tipo'), 'income')
    await waitFor(() => {
      const last = calls.filter((c) => c.path === '/transactions').at(-1)!
      expect(last.query.get('search')).toBe('café')
      expect(last.query.get('type')).toBe('income')
      expect(last.query.get('offset')).toBe('0')
    })
  })

  it('pagina', async () => {
    const calls = mockApi({ ...base, 'GET /transactions': page([transaction()], 45) })
    renderApp(<TransactionsPage />)
    expect(await screen.findByText('1 / 3')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Anterior' })).toBeDisabled()
    await userEvent.click(screen.getByRole('button', { name: 'Siguiente' }))
    await waitFor(() =>
      expect(
        calls
          .filter((c) => c.path === '/transactions')
          .at(-1)!
          .query.get('offset'),
      ).toBe('20'),
    )
  })

  it('crea un gasto', async () => {
    const calls = mockApi({
      ...base,
      'GET /transactions': page([]),
      'POST /transactions': { status: 201, body: transaction() },
    })
    renderApp(<TransactionsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Nueva' }))
    const form = screen.getByText('Nueva transacción').closest('section')!
    await userEvent.selectOptions(within(form).getByLabelText('Cuenta'), 'a1')
    await userEvent.selectOptions(within(form).getByLabelText('Categoría'), 'c1')
    await userEvent.type(within(form).getByLabelText('Monto'), '12.50')
    await userEvent.click(within(form).getByRole('button', { name: 'Guardar' }))
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true))
    expect(calls.find((c) => c.method === 'POST')?.body).toMatchObject({
      type: 'expense',
      account_id: 'a1',
      category_id: 'c1',
      amount: '12.50',
      transfer_account_id: null,
    })
  })

  it('una transferencia pide cuenta destino y no envía categoría', async () => {
    const calls = mockApi({
      ...base,
      'GET /transactions': page([]),
      'POST /transactions': { status: 201, body: transaction() },
    })
    renderApp(<TransactionsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Nueva' }))
    const form = screen.getByText('Nueva transacción').closest('section')!
    await userEvent.selectOptions(within(form).getByLabelText('Tipo'), 'transfer')
    expect(within(form).queryByLabelText('Categoría')).not.toBeInTheDocument()
    await userEvent.selectOptions(within(form).getByLabelText('Cuenta origen'), 'a1')
    await userEvent.type(within(form).getByLabelText('Monto'), '5')
    await userEvent.click(within(form).getByRole('button', { name: 'Guardar' }))
    expect(await screen.findByText('Elige la cuenta destino')).toBeInTheDocument()
    await userEvent.selectOptions(within(form).getByLabelText('Cuenta destino'), 'a2')
    await userEvent.click(within(form).getByRole('button', { name: 'Guardar' }))
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true))
    expect(calls.find((c) => c.method === 'POST')?.body).toMatchObject({
      type: 'transfer',
      transfer_account_id: 'a2',
      category_id: null,
    })
  })

  it('rechaza montos inválidos', async () => {
    mockApi({ ...base, 'GET /transactions': page([]) })
    renderApp(<TransactionsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Nueva' }))
    await userEvent.type(screen.getByLabelText('Monto'), '-3')
    await userEvent.click(screen.getByRole('button', { name: 'Guardar' }))
    expect(await screen.findByText(/Monto positivo/)).toBeInTheDocument()
  })

  it('edita y elimina', async () => {
    const calls = mockApi({
      ...base,
      'GET /transactions': page([transaction()]),
      'PUT /transactions/t1': transaction(),
      'DELETE /transactions/t1': { status: 204, body: null },
    })
    renderApp(<TransactionsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Editar' }))
    expect(screen.getByLabelText('Monto')).toHaveValue('12.50')
    await userEvent.clear(screen.getByLabelText('Monto'))
    await userEvent.type(screen.getByLabelText('Monto'), '20')
    await userEvent.click(screen.getByRole('button', { name: 'Guardar' }))
    await waitFor(() =>
      expect(calls.find((c) => c.method === 'PUT')?.body).toMatchObject({ amount: '20' }),
    )
    await userEvent.click(await screen.findByRole('button', { name: 'Eliminar' }))
    const dialog = await screen.findByRole('alertdialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Eliminar' }))
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true))
  })
})

describe('BudgetsPage', () => {
  const budget = (over = {}) => ({
    id: 'b1',
    created_at: '2026-01-01T00:00:00Z',
    category_id: 'c1',
    month: '2026-03-01',
    amount: '200.00',
    spent: '75.00',
    remaining: '125.00',
    ...over,
  })

  it('muestra progreso y restante', async () => {
    mockApi({
      'GET /accounts': [account()],
      'GET /categories': [category()],
      'GET /budgets': [budget()],
    })
    renderApp(<BudgetsPage />)
    expect(await screen.findByRole('progressbar')).toBeInTheDocument()
    expect(within(screen.getByRole('listitem')).getByText('Comida')).toBeInTheDocument()
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '38')
    expect(screen.getByText(/Quedan/)).toBeInTheDocument()
  })

  it('marca presupuestos excedidos', async () => {
    mockApi({
      'GET /accounts': [account()],
      'GET /categories': [category()],
      'GET /budgets': [budget({ spent: '250.00', remaining: '-50.00' })],
    })
    renderApp(<BudgetsPage />)
    expect(await screen.findByText(/Excedido en/)).toBeInTheDocument()
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '100')
  })

  it('solo ofrece categorías de gasto y crea con el mes seleccionado', async () => {
    const calls = mockApi({
      'GET /accounts': [],
      'GET /budgets': [],
      'GET /categories': [category(), category({ id: 'c2', name: 'Sueldo', kind: 'income' })],
      'POST /budgets': { status: 201, body: budget() },
    })
    renderApp(<BudgetsPage />)
    const select = await screen.findByLabelText('Categoría de gasto')
    await waitFor(() =>
      expect(within(select).getByRole('option', { name: 'Comida' })).toBeInTheDocument(),
    )
    expect(within(select).queryByRole('option', { name: 'Sueldo' })).not.toBeInTheDocument()
    await userEvent.selectOptions(select, 'c1')
    await userEvent.type(screen.getByLabelText('Monto'), '99')
    await userEvent.click(screen.getByRole('button', { name: 'Añadir' }))
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true))
    expect(calls.find((c) => c.method === 'POST')?.body).toMatchObject({
      category_id: 'c1',
      amount: '99',
    })
  })
})

describe('DashboardPage · próximos recurrentes', () => {
  it('muestra los 3 próximos activos, ordenados por fecha', async () => {
    const r = (id: string, d: string, over = {}) => ({
      id,
      created_at: '2026-01-01T00:00:00Z',
      type: 'expense',
      account_id: 'a1',
      transfer_account_id: null,
      category_id: null,
      amount: '10.00',
      description: id,
      frequency: 'monthly',
      next_date: d,
      end_date: null,
      active: true,
      ...over,
    })
    mockApi({
      'GET /accounts': [account()],
      'GET /categories': [],
      'GET /transactions': page([]),
      'GET /reports/summary': {
        month: '2026-03-01',
        income: '0',
        expense: '0',
        net: '0',
        expense_by_category: [],
        trend: [],
      },
      'GET /recurring': [
        r('D', '2026-06-01'),
        r('A', '2026-04-01'),
        r('B', '2026-05-01'),
        r('pausada', '2026-03-01', { active: false }),
        r('C', '2026-07-01'),
      ],
    })
    renderApp(<DashboardPage />)
    const list = await screen.findByRole('list', { name: 'Próximos recurrentes' })
    expect(
      within(list)
        .getAllByRole('listitem')
        .map((i) => i.textContent?.slice(0, 1)),
    ).toEqual(['A', 'B', 'D'])
    expect(within(list).queryByText('pausada')).not.toBeInTheDocument()
  })

  it('sin reglas no muestra la sección', async () => {
    mockApi({
      'GET /accounts': [],
      'GET /categories': [],
      'GET /transactions': page([]),
      'GET /reports/summary': {
        month: '2026-03-01',
        income: '0',
        expense: '0',
        net: '0',
        expense_by_category: [],
        trend: [],
      },
      'GET /recurring': [],
    })
    renderApp(<DashboardPage />)
    await screen.findByText('Sin gastos este mes.')
    expect(screen.queryByText('Próximos recurrentes')).not.toBeInTheDocument()
  })
})

describe('DashboardPage', () => {
  it('muestra totales, categorías y últimas transacciones', async () => {
    const months = [
      '2025-10-01',
      '2025-11-01',
      '2025-12-01',
      '2026-01-01',
      '2026-02-01',
      '2026-03-01',
    ]
    mockApi({
      'GET /accounts': [account({ balance: '150.00' }), account({ id: 'a2', balance: '50.00' })],
      'GET /categories': [category()],
      'GET /reports/summary': {
        month: '2026-03-01',
        income: '500.00',
        expense: '75.00',
        net: '425.00',
        expense_by_category: [
          { category_id: 'c1', total: '75.00' },
          { category_id: null, total: '5.00' },
        ],
        trend: months.map((month) => ({ month, income: '0', expense: '0' })),
      },
      'GET /transactions': page([transaction()]),
    })
    renderApp(<DashboardPage />)
    expect(await screen.findByText('Saldo total')).toBeInTheDocument()
    await waitFor(() => expect(screen.getByText(/200/)).toBeInTheDocument())
    expect(await screen.findByText('Sin categoría')).toBeInTheDocument()
    expect(screen.getByText(/Almuerzo/)).toBeInTheDocument()
  })

  it('estados vacíos', async () => {
    mockApi({
      'GET /accounts': [],
      'GET /categories': [],
      'GET /transactions': page([]),
      'GET /reports/summary': {
        month: '2026-03-01',
        income: '0',
        expense: '0',
        net: '0',
        expense_by_category: [],
        trend: [],
      },
    })
    renderApp(<DashboardPage />)
    expect(await screen.findByText('Sin gastos este mes.')).toBeInTheDocument()
    expect(screen.getByText('Aún no hay movimientos.')).toBeInTheDocument()
  })
})
