import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { vi } from 'vitest'
import { FormDialog } from '../design'
import { RenameForm } from '../features/RenameForm'
import { account, category, mockApi, page, renderApp, transaction, user } from '../test-utils'
import { AccountsPage } from './Accounts'
import { BudgetsPage } from './Budgets'
import { CategoriesPage } from './Categories'
import { monthlyNeeded } from '../lib/goals'
import { GoalsPage } from './Goals'
import { MorePage } from './More'
import { ProfilePage } from './Profile'
import { TransactionsPage } from './Transactions'

afterEach(() => vi.restoreAllMocks())

const goal = (over = {}) => ({
  id: 'g1',
  created_at: '2026-01-01T00:00:00Z',
  name: 'Viaje',
  target_amount: '1000.00',
  currency: 'COP',
  deadline: null,
  saved: '250.00',
  remaining: '750.00',
  achieved: false,
  ...over,
})

describe('monthlyNeeded', () => {
  const now = new Date(2026, 0, 15)
  it('reparte lo que falta entre los meses restantes', () => {
    expect(monthlyNeeded(goal({ deadline: '2026-06-30' }) as never, now)).toBeCloseTo(150) // 750 / 5
  })
  it('null sin fecha, vencida o ya lograda', () => {
    expect(monthlyNeeded(goal() as never, now)).toBeNull()
    expect(monthlyNeeded(goal({ deadline: '2025-12-31' }) as never, now)).toBeNull()
    expect(monthlyNeeded(goal({ deadline: '2026-06-30', achieved: true }) as never, now)).toBeNull()
  })
})

describe('GoalsPage', () => {
  it('muestra progreso, faltante y estado vacío', async () => {
    mockApi({
      'GET /goals': [
        goal({ deadline: '2099-01-01' }),
        goal({ id: 'g2', name: 'Fondo', achieved: true, saved: '1000.00', remaining: '0.00' }),
      ],
    })
    renderApp(<GoalsPage />)
    expect(await screen.findByText('Viaje')).toBeInTheDocument()
    const bars = screen.getAllByRole('progressbar')
    expect(bars.map((b) => b.getAttribute('aria-valuenow'))).toEqual(['25', '100'])
    expect(screen.getByText('Lograda')).toBeInTheDocument()
    expect(screen.getByText(/al mes/)).toBeInTheDocument()
  })

  it('sin metas invita a crear una', async () => {
    mockApi({ 'GET /goals': [] })
    renderApp(<GoalsPage />)
    expect(await screen.findByText(/Aún no tienes metas/)).toBeInTheDocument()
  })

  it('valida y crea una meta (fecha vacía → null)', async () => {
    const calls = mockApi({ 'GET /goals': [], 'POST /goals': { status: 201, body: goal() } })
    renderApp(<GoalsPage />)
    await userEvent.click(screen.getByRole('button', { name: 'Crear meta' }))
    expect(
      await screen.findAllByText(/Requerido|Código de 3 letras|Monto positivo/),
    ).not.toHaveLength(0)
    await userEvent.type(screen.getByLabelText('Nombre'), 'Casa')
    await userEvent.type(screen.getByLabelText('Monto objetivo'), '5000000')
    await userEvent.type(screen.getByLabelText('Moneda'), 'cop')
    await userEvent.click(screen.getByRole('button', { name: 'Crear meta' }))
    await waitFor(() => expect(calls.some((c) => c.method === 'POST')).toBe(true))
    expect(calls.find((c) => c.method === 'POST')?.body).toEqual({
      name: 'Casa',
      target_amount: '5000000',
      currency: 'cop',
      deadline: null,
    })
  })

  it('aporta y retira (el retiro se envía con signo negativo)', async () => {
    const calls = mockApi({
      'GET /goals': [goal()],
      'POST /goals/g1/contributions': {
        status: 201,
        body: { id: 'c1', goal_id: 'g1', amount: '50.00', occurred_on: '2026-03-01', note: '' },
      },
    })
    renderApp(<GoalsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Aportar' }))
    let dialog = await screen.findByRole('dialog')
    await userEvent.type(within(dialog).getByLabelText('Monto'), '50')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Aportar' }))
    await waitFor(() => expect(calls.filter((c) => c.method === 'POST')).toHaveLength(1))
    expect(calls.find((c) => c.method === 'POST')?.body).toMatchObject({ amount: '50' })
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())

    await userEvent.click(screen.getByRole('button', { name: 'Retirar' }))
    dialog = await screen.findByRole('dialog')
    await userEvent.type(within(dialog).getByLabelText('Monto'), '20')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Retirar' }))
    await waitFor(() => expect(calls.filter((c) => c.method === 'POST')).toHaveLength(2))
    expect(calls.filter((c) => c.method === 'POST')[1].body).toMatchObject({ amount: '-20' })
  })

  it('muestra el error del servidor al retirar de más', async () => {
    mockApi({
      'GET /goals': [goal()],
      'POST /goals/g1/contributions': {
        status: 400,
        body: {
          error: {
            code: 'bad_request',
            message: 'No puedes retirar más de lo que has ahorrado en esta meta',
          },
        },
      },
    })
    renderApp(<GoalsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Retirar' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.type(within(dialog).getByLabelText('Monto'), '9999')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Retirar' }))
    expect(await within(dialog).findByRole('alert')).toHaveTextContent('No puedes retirar más')
  })

  it('elimina con confirmación', async () => {
    const calls = mockApi({
      'GET /goals': [goal()],
      'DELETE /goals/g1': { status: 204, body: null },
    })
    renderApp(<GoalsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Eliminar' }))
    expect(calls.some((c) => c.method === 'DELETE')).toBe(false)
    const dialog = await screen.findByRole('alertdialog')
    expect(dialog).toHaveTextContent('Viaje')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Eliminar' }))
    await waitFor(() => expect(calls.some((c) => c.method === 'DELETE')).toBe(true))
  })
})

describe('ProfilePage', () => {
  it('actualiza el nombre', async () => {
    const calls = mockApi({
      'GET /auth/me': user,
      'PATCH /auth/me': { ...user, full_name: 'Nuevo' },
    })
    renderApp(<ProfilePage />)
    const input = await screen.findByLabelText('Nombre')
    await waitFor(() => expect(input).toHaveValue('Ana Test'))
    await userEvent.clear(input)
    await userEvent.type(input, 'Nuevo')
    await userEvent.click(screen.getByRole('button', { name: 'Guardar' }))
    await waitFor(() =>
      expect(calls.find((c) => c.method === 'PATCH')?.body).toEqual({ full_name: 'Nuevo' }),
    )
  })

  it.each([
    ['corta1', 'al menos 8 caracteres'],
    ['soloLetrasAqui', 'al menos un número'],
  ])('contraseña nueva "%s" → explica el motivo y no llama a la API', async (pw, reason) => {
    const calls = mockApi({ 'GET /auth/me': user })
    renderApp(<ProfilePage />)
    await userEvent.type(await screen.findByLabelText('Contraseña actual'), 'vieja-clave1')
    await userEvent.type(screen.getByLabelText('Contraseña nueva'), pw)
    await userEvent.click(screen.getByRole('button', { name: 'Cambiar contraseña' }))
    expect(await screen.findByText(new RegExp(reason))).toBeInTheDocument()
    expect(calls.some((c) => c.method === 'POST')).toBe(false)
  })

  it('cambia la contraseña y limpia el formulario; muestra el error del servidor si la actual falla', async () => {
    let fail = true
    const calls = mockApi({
      'GET /auth/me': user,
      'POST /auth/change-password': () =>
        fail
          ? {
              status: 400,
              body: {
                error: { code: 'bad_request', message: 'La contraseña actual es incorrecta' },
              },
            }
          : { status: 204, body: null },
    })
    renderApp(<ProfilePage />)
    await userEvent.type(await screen.findByLabelText('Contraseña actual'), 'mala-clave1')
    await userEvent.type(screen.getByLabelText('Contraseña nueva'), 'NuevaClave-99')
    await userEvent.click(screen.getByRole('button', { name: 'Cambiar contraseña' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('actual es incorrecta')
    fail = false
    await userEvent.click(screen.getByRole('button', { name: 'Cambiar contraseña' }))
    await waitFor(() => expect(screen.getByLabelText('Contraseña nueva')).toHaveValue(''))
    expect(calls.filter((c) => c.method === 'POST')).toHaveLength(2)
  })

  it('el selector de tema aplica y guarda la preferencia', async () => {
    localStorage.clear()
    mockApi({ 'GET /auth/me': user })
    renderApp(<ProfilePage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Oscuro' }))
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark')
    expect(localStorage.getItem('theme')).toBe('dark')
    await userEvent.click(screen.getByRole('button', { name: 'Automático' }))
    expect(document.documentElement).not.toHaveAttribute('data-theme')
  })
})

describe('MorePage', () => {
  it('enlaza a lo que no cabe en la barra móvil', () => {
    renderApp(<MorePage />)
    const hrefs = screen.getAllByRole('link').map((l) => l.getAttribute('href'))
    expect(hrefs).toEqual(['/budgets', '/categories', '/profile'])
  })
})

describe('edición y borrado', () => {
  it('renombra una cuenta', async () => {
    const calls = mockApi({
      'GET /accounts': [account()],
      'PATCH /accounts/a1': account({ name: 'Nuevo' }),
    })
    renderApp(<AccountsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Renombrar Banco' }))
    const dialog = await screen.findByRole('dialog')
    const input = within(dialog).getByLabelText('Nombre')
    expect(input).toHaveValue('Banco')
    await userEvent.clear(input)
    await userEvent.type(input, 'Nuevo')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Guardar' }))
    await waitFor(() =>
      expect(calls.find((c) => c.method === 'PATCH')?.body).toEqual({ name: 'Nuevo' }),
    )
  })

  it('elimina una cuenta con confirmación y muestra el conflicto del servidor', async () => {
    mockApi({
      'GET /accounts': [account()],
      'DELETE /accounts/a1': {
        status: 409,
        body: {
          error: {
            code: 'conflict',
            message: 'La cuenta tiene movimientos: archívala en lugar de eliminarla',
          },
        },
      },
    })
    renderApp(<AccountsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Eliminar Banco' }))
    const dialog = await screen.findByRole('alertdialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Eliminar' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('archívala')
  })

  it('renombra una categoría', async () => {
    const calls = mockApi({
      'GET /categories': [category()],
      'PATCH /categories/c1': category({ name: 'Mercado' }),
    })
    renderApp(<CategoriesPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Renombrar Comida' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.clear(within(dialog).getByLabelText('Nombre'))
    await userEvent.type(within(dialog).getByLabelText('Nombre'), 'Mercado')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Guardar' }))
    await waitFor(() =>
      expect(calls.find((c) => c.method === 'PATCH')?.body).toEqual({ name: 'Mercado' }),
    )
  })

  it('edita el monto de un presupuesto y valida', async () => {
    const calls = mockApi({
      'GET /accounts': [account()],
      'GET /categories': [category()],
      'GET /budgets': [
        {
          id: 'b1',
          created_at: '2026-01-01T00:00:00Z',
          category_id: 'c1',
          month: '2026-03-01',
          amount: '200.00',
          spent: '10.00',
          remaining: '190.00',
        },
      ],
      'PATCH /budgets/b1': { id: 'b1' },
    })
    renderApp(<BudgetsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Editar Comida' }))
    const dialog = await screen.findByRole('dialog')
    const input = within(dialog).getByLabelText('Monto')
    expect(input).toHaveValue('200')
    await userEvent.clear(input)
    await userEvent.type(input, '-5')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Guardar' }))
    expect(await within(dialog).findByText(/Monto positivo/)).toBeInTheDocument()
    expect(calls.some((c) => c.method === 'PATCH')).toBe(false)
    await userEvent.clear(input)
    await userEvent.type(input, '350.5')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Guardar' }))
    await waitFor(() =>
      expect(calls.find((c) => c.method === 'PATCH')?.body).toEqual({ amount: '350.5' }),
    )
  })
})

describe('exportar CSV', () => {
  it('descarga con el token y los filtros activos', async () => {
    localStorage.clear()
    const fetchMock = mockApi({
      'GET /accounts': [account()],
      'GET /categories': [category()],
      'GET /transactions': page([transaction()]),
      'GET /transactions/export': 'fecha,tipo\n2026-03-10,gasto',
    })
    URL.createObjectURL = vi.fn(() => 'blob:x')
    URL.revokeObjectURL = vi.fn()
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {})
    renderApp(<TransactionsPage />)
    await userEvent.selectOptions(await screen.findByLabelText('Tipo'), 'expense')
    await userEvent.click(screen.getByRole('button', { name: 'Exportar CSV' }))
    await waitFor(() => expect(click).toHaveBeenCalled())
    const exportCall = fetchMock.find((c) => c.path === '/transactions/export')!
    expect(exportCall.query.get('type')).toBe('expense')
    expect(URL.createObjectURL).toHaveBeenCalled()
  })

  it('muestra un error claro si la exportación falla', async () => {
    mockApi({
      'GET /accounts': [],
      'GET /categories': [],
      'GET /transactions': page([]),
      'GET /transactions/export': { status: 500, body: '' },
    })
    renderApp(<TransactionsPage />)
    await userEvent.click(await screen.findByRole('button', { name: 'Exportar CSV' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Error del servidor')
  })
})

describe('RenameForm y FormDialog', () => {
  it('RenameForm valida con la función recibida y no envía si falla', async () => {
    const onSubmit = vi.fn()
    render(
      <RenameForm
        initial=""
        label="Valor"
        validate={(v) => (v === 'ok' ? null : 'Debe ser ok')}
        onSubmit={onSubmit}
        onCancel={() => {}}
      />,
    )
    await userEvent.type(screen.getByLabelText('Valor'), 'x')
    await userEvent.click(screen.getByRole('button', { name: 'Guardar' }))
    expect(screen.getByText('Debe ser ok')).toBeInTheDocument()
    expect(onSubmit).not.toHaveBeenCalled()
    await userEvent.clear(screen.getByLabelText('Valor'))
    await userEvent.type(screen.getByLabelText('Valor'), 'ok')
    await userEvent.click(screen.getByRole('button', { name: 'Guardar' }))
    expect(onSubmit).toHaveBeenCalledWith('ok')
  })

  it('FormDialog enfoca el primer campo y Escape cierra', async () => {
    const onClose = vi.fn()
    render(
      <FormDialog open title="Editar" onClose={onClose}>
        <input aria-label="campo" />
      </FormDialog>,
    )
    expect(screen.getByRole('dialog')).toHaveAccessibleName('Editar')
    expect(screen.getByLabelText('campo')).toHaveFocus()
    await userEvent.keyboard('{Escape}')
    expect(onClose).toHaveBeenCalled()
  })
})
