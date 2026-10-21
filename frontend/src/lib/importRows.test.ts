import { buildItems, guessMapping, looksLikeHeader, type Mapping } from './importRows'

const single: Mapping = {
  date: 0,
  description: 1,
  amount: 2,
  debit: -1,
  credit: -1,
  dateFormat: 'dmy',
}

describe('buildItems', () => {
  it('convierte signo, fechas y descripción', () => {
    const { items, errors } = buildItems(
      [
        ['05/03/2026', 'Supermercado', '-186.400,50'],
        ['06/03/2026', 'Nómina', '4.850.000'],
      ],
      single,
      2,
    )
    expect(errors).toEqual([])
    expect(items).toEqual([
      { occurred_on: '2026-03-05', description: 'Supermercado', amount: '-186400.50' },
      { occurred_on: '2026-03-06', description: 'Nómina', amount: '4850000.00' },
    ])
  })

  it('reporta fila, motivo y sigue con las demás', () => {
    const { items, errors } = buildItems(
      [
        ['31/02/2026', 'x', '1'],
        ['01/03/2026', 'y', 'abc'],
        ['02/03/2026', 'z', '0'],
        ['03/03/2026', 'ok', '5'],
      ],
      single,
      2,
    )
    expect(items).toHaveLength(1)
    expect(errors).toEqual([
      { row: 2, reason: 'Fecha no válida' },
      { row: 3, reason: 'Monto no válido' },
      { row: 4, reason: 'El monto es cero' },
    ])
  })

  it('débito y crédito en columnas separadas', () => {
    const m: Mapping = {
      date: 0,
      description: 1,
      amount: -1,
      debit: 2,
      credit: 3,
      dateFormat: 'ymd',
    }
    const { items } = buildItems(
      [
        ['2026-03-05', 'Retiro', '100', ''],
        ['2026-03-06', 'Abono', '', '250.5'],
      ],
      m,
      2,
    )
    expect(items.map((i) => i.amount)).toEqual(['-100.00', '250.50'])
  })

  it('recorta descripciones largas y tolera filas cortas', () => {
    const { items, errors } = buildItems(
      [['2026-03-05', 'x'.repeat(400), '5'], ['2026-03-05']],
      { ...single, dateFormat: 'ymd' },
      2,
    )
    expect(items[0].description).toHaveLength(255)
    expect(errors).toEqual([{ row: 3, reason: 'Monto no válido' }])
  })

  it('sin columna de descripción deja vacío', () => {
    const { items } = buildItems(
      [['2026-03-05', '9']],
      { ...single, description: -1, amount: 1, dateFormat: 'ymd' },
      1,
    )
    expect(items[0].description).toBe('')
  })
})

describe('encabezado y mapeo sugerido', () => {
  it('detecta encabezados y filas de datos', () => {
    expect(looksLikeHeader(['Fecha', 'Descripción', 'Monto'])).toBe(true)
    expect(looksLikeHeader(['05/03/2026', 'Café', '-5'])).toBe(false)
  })
  it('mapea por nombre de columna en español e inglés', () => {
    expect(guessMapping(['Fecha', 'Concepto', 'Importe'], 'dmy')).toMatchObject({
      date: 0,
      description: 1,
      amount: 2,
      debit: -1,
    })
    expect(guessMapping(['Date', 'Memo', 'Debit', 'Credit'], 'mdy')).toMatchObject({
      date: 0,
      description: 1,
      amount: -1,
      debit: 2,
      credit: 3,
    })
  })
})
