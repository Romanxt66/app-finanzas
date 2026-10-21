import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { vi } from 'vitest'
import { account, mockApi, renderApp } from '../test-utils'
import { ImportPage } from './Import'

afterEach(() => vi.restoreAllMocks())

const csv = (text: string, name = 'extracto.csv') => new File([text], name, { type: 'text/csv' })
const BANK =
  'Fecha;Descripción;Monto\n05/03/2026;Supermercado;-186.400,50\n06/03/2026;Nómina;4.850.000\n31/02/2026;Fecha mala;5\n07/03/2026;Sin monto;abc\n'

async function upload(text: string) {
  await userEvent.upload(screen.getByLabelText('Archivo CSV del banco'), csv(text))
}

describe('ImportPage', () => {
  it('lee el CSV en el navegador, mapea columnas y muestra vista previa con errores', async () => {
    mockApi({ 'GET /accounts': [account({ currency: 'COP' })] })
    renderApp(<ImportPage />)
    await upload(BANK)
    expect(await screen.findByText(/2\. Columnas · extracto\.csv/)).toBeInTheDocument()
    // detectó el separador ";", el encabezado y el formato de fecha día/mes/año
    expect(screen.getByLabelText('Separador')).toHaveValue(';')
    expect(screen.getByLabelText('Formato de fecha')).toHaveValue('dmy')
    expect(screen.getByLabelText('Columna de fecha')).toHaveDisplayValue('Fecha')
    expect(screen.getByLabelText('Columna de monto (con signo)')).toHaveDisplayValue('Monto')
    expect(screen.getByText('2 filas válidas')).toBeInTheDocument()
    expect(screen.getByText('2 con errores (se omiten)')).toBeInTheDocument()
    const errors = screen.getByRole('list', { name: 'Filas con errores' })
    expect(errors).toHaveTextContent('Fila 4: Fecha no válida')
    expect(errors).toHaveTextContent('Fila 5: Monto no válido')
    const preview = screen.getByRole('list', { name: 'Vista previa' })
    expect(within(preview).getByText('Supermercado')).toBeInTheDocument()
  })

  it('exige elegir la cuenta y envía solo las filas válidas con signo', async () => {
    const calls = mockApi({
      'GET /accounts': [account()],
      'POST /transactions/bulk': { created: 2, skipped: 0 },
    })
    renderApp(<ImportPage />)
    await upload(BANK)
    const button = await screen.findByRole('button', { name: 'Importar 2 movimientos' })
    expect(button).toBeDisabled()
    expect(screen.getByText('Elige la cuenta de destino.')).toBeInTheDocument()
    await screen.findByRole('option', { name: /Banco/ })
    await userEvent.selectOptions(screen.getByLabelText('Cuenta de destino'), 'a1')
    await userEvent.click(screen.getByRole('button', { name: 'Importar 2 movimientos' }))
    await waitFor(() => expect(calls.some((c) => c.path === '/transactions/bulk')).toBe(true))
    expect(calls.find((c) => c.path === '/transactions/bulk')?.body).toEqual({
      account_id: 'a1',
      skip_duplicates: true,
      items: [
        { occurred_on: '2026-03-05', description: 'Supermercado', amount: '-186400.50' },
        { occurred_on: '2026-03-06', description: 'Nómina', amount: '4850000.00' },
      ],
    })
    expect(await screen.findByRole('status')).toHaveTextContent('Se importaron 2 movimientos')
  })

  it('informa cuántas filas ya existían', async () => {
    mockApi({ 'GET /accounts': [account()], 'POST /transactions/bulk': { created: 1, skipped: 1 } })
    renderApp(<ImportPage />)
    await upload(BANK)
    await screen.findByRole('option', { name: /Banco/ })
    await userEvent.selectOptions(screen.getByLabelText('Cuenta de destino'), 'a1')
    await userEvent.click(await screen.findByRole('button', { name: /^Importar/ }))
    expect(await screen.findByRole('status')).toHaveTextContent('1 ya existían')
  })

  it('soporta débito y crédito en columnas separadas', async () => {
    mockApi({ 'GET /accounts': [account()] })
    renderApp(<ImportPage />)
    await upload('Date,Memo,Debit,Credit\n2026-03-05,Retiro,100,\n2026-03-06,Abono,,250.5\n')
    expect(await screen.findByText('2 filas válidas')).toBeInTheDocument()
    expect(screen.getByLabelText('Columna de monto (con signo)')).toHaveDisplayValue(
      'Usar débito y crédito',
    )
    expect(screen.getByLabelText('Columna de débito (gasto)')).toHaveDisplayValue('Debit')
    expect(screen.getByLabelText('Columna de crédito (ingreso)')).toHaveDisplayValue('Credit')
  })

  it('cambiar el formato de fecha reinterpreta las filas', async () => {
    mockApi({ 'GET /accounts': [account()] })
    renderApp(<ImportPage />)
    await upload('Fecha,Detalle,Importe\n03/25/2026,x,5\n04/01/2026,y,6\n')
    // mes/día/año es el único que valida el 25: se elige solo
    expect(await screen.findByLabelText('Formato de fecha')).toHaveValue('mdy')
    expect(screen.getByText('2 filas válidas')).toBeInTheDocument()
    await userEvent.selectOptions(screen.getByLabelText('Formato de fecha'), 'dmy')
    expect(screen.getByText('1 filas válidas')).toBeInTheDocument()
  })

  it('rechaza archivos sin datos o demasiado grandes', async () => {
    mockApi({ 'GET /accounts': [] })
    renderApp(<ImportPage />)
    await upload('solo,encabezado\n')
    expect(await screen.findByRole('alert')).toHaveTextContent('no tiene filas de datos')
    const big = csv('a,b\n' + 'x'.repeat(2 * 1024 * 1024 + 10))
    await userEvent.upload(screen.getByLabelText('Archivo CSV del banco'), big)
    expect(await screen.findByRole('alert')).toHaveTextContent('supera los 2 MB')
  })

  it('muestra el error del servidor', async () => {
    mockApi({
      'GET /accounts': [account()],
      'POST /transactions/bulk': {
        status: 400,
        body: {
          error: {
            code: 'bad_request',
            message: 'Fila 2: la categoría no corresponde a un ingreso',
          },
        },
      },
    })
    renderApp(<ImportPage />)
    await upload(BANK)
    await screen.findByRole('option', { name: /Banco/ })
    await userEvent.selectOptions(screen.getByLabelText('Cuenta de destino'), 'a1')
    await userEvent.click(await screen.findByRole('button', { name: /^Importar/ }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Fila 2')
  })
})
