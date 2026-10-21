import { parseAmount, parseDate, type DateFormat } from './csv'

export interface Mapping {
  date: number
  description: number // -1 = sin descripción
  /** Una sola columna con signo, o -1 si el extracto separa débito y crédito */
  amount: number
  debit: number
  credit: number
  dateFormat: DateFormat
}

export interface ImportItem {
  occurred_on: string
  description: string
  amount: string
}

export interface RowError {
  row: number // número de fila del archivo (1 = primera)
  reason: string
}

const MAX_DESCRIPTION = 255

function cell(row: string[], index: number): string {
  return index >= 0 ? (row[index] ?? '').trim() : ''
}

/** Convierte filas de texto en movimientos con signo (positivo = ingreso, negativo = gasto). */
export function buildItems(
  rows: string[][],
  mapping: Mapping,
  firstDataRow: number,
): { items: ImportItem[]; errors: RowError[] } {
  const items: ImportItem[] = []
  const errors: RowError[] = []
  rows.forEach((row, i) => {
    const rowNumber = firstDataRow + i
    const date = parseDate(cell(row, mapping.date), mapping.dateFormat)
    if (!date) return void errors.push({ row: rowNumber, reason: 'Fecha no válida' })

    let amount: number | null
    if (mapping.amount >= 0) amount = parseAmount(cell(row, mapping.amount))
    else {
      const debit = parseAmount(cell(row, mapping.debit))
      const credit = parseAmount(cell(row, mapping.credit))
      amount = credit && credit !== 0 ? Math.abs(credit) : debit ? -Math.abs(debit) : null
    }
    if (amount === null) return void errors.push({ row: rowNumber, reason: 'Monto no válido' })
    if (amount === 0) return void errors.push({ row: rowNumber, reason: 'El monto es cero' })

    items.push({
      occurred_on: date,
      description: cell(row, mapping.description).slice(0, MAX_DESCRIPTION),
      amount: amount.toFixed(2),
    })
  })
  return { items, errors }
}

/** ¿La primera fila parece un encabezado? (ninguna celda es fecha ni monto). */
export function looksLikeHeader(row: string[]): boolean {
  return row.every(
    (c) => parseAmount(c) === null && parseDate(c, 'ymd') === null && parseDate(c, 'dmy') === null,
  )
}

const NAMES = {
  date: /fecha|date/i,
  description: /descrip|concepto|detalle|memo|payee|narrat/i,
  amount: /monto|importe|valor|amount|^total$/i,
  debit: /d[eé]bito|debit|cargo|retiro/i,
  credit: /cr[eé]dito|credit|abono|dep[oó]sito/i,
}

/** Propone un mapeo a partir de los nombres del encabezado (el usuario puede corregirlo). */
export function guessMapping(header: string[], dateFormat: DateFormat): Mapping {
  const find = (re: RegExp) => header.findIndex((h) => re.test(h))
  const amount = find(NAMES.amount)
  return {
    date: find(NAMES.date),
    description: find(NAMES.description),
    amount,
    debit: amount >= 0 ? -1 : find(NAMES.debit),
    credit: amount >= 0 ? -1 : find(NAMES.credit),
    dateFormat,
  }
}
