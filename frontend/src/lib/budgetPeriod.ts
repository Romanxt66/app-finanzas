// Periodos de los presupuestos: día, semana (de lunes a domingo) o mes. Fechas en `yyyy-MM-dd` local.

export type Period = 'day' | 'week' | 'month'

const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

const parse = (value: string) => {
  const [y, m, d] = value.split('-').map(Number)
  return new Date(y, m - 1, d || 1)
}

/** Primer día del periodo que contiene `value`. */
export function periodStart(period: Period, value: string): string {
  const d = parse(value)
  if (period === 'month') return iso(new Date(d.getFullYear(), d.getMonth(), 1))
  if (period === 'week') {
    const back = (d.getDay() + 6) % 7 // lunes = 0
    return iso(new Date(d.getFullYear(), d.getMonth(), d.getDate() - back))
  }
  return iso(d)
}

/** El periodo anterior (−1) o siguiente (+1). */
export function shiftPeriod(period: Period, value: string, by: number): string {
  const d = parse(periodStart(period, value))
  if (period === 'month') return iso(new Date(d.getFullYear(), d.getMonth() + by, 1))
  return iso(
    new Date(d.getFullYear(), d.getMonth(), d.getDate() + by * (period === 'week' ? 7 : 1)),
  )
}

const MONTHS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic']
const short = (d: Date, withMonth = true) =>
  withMonth ? `${d.getDate()} ${MONTHS[d.getMonth()]}` : String(d.getDate())

/** «lun 10 nov», «10 – 16 nov», «noviembre 2026». */
export function periodLabel(period: Period, value: string): string {
  const start = parse(periodStart(period, value))
  if (period === 'month') {
    return start
      .toLocaleDateString('es-CO', { month: 'long', year: 'numeric' })
      .replace(' de ', ' ')
  }
  if (period === 'day') {
    return start
      .toLocaleDateString('es-CO', { weekday: 'short', day: 'numeric', month: 'short' })
      .replace(/\./g, '')
      .replace(',', '')
  }
  const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 6)
  return start.getMonth() === end.getMonth()
    ? `${short(start, false)} – ${short(end)}`
    : `${short(start)} – ${short(end)}`
}

/** «hoy», «esta semana», «este mes» (o «ese día»… si no es el actual). */
export function periodWord(period: Period, value: string, today: string): string {
  const current = periodStart(period, value) === periodStart(period, today)
  if (period === 'day') return current ? 'hoy' : 'ese día'
  if (period === 'week') return current ? 'esta semana' : 'esa semana'
  return current ? 'este mes' : 'ese mes'
}

export const PERIOD_OPTIONS: { value: Period; label: string }[] = [
  { value: 'day', label: 'Día' },
  { value: 'week', label: 'Semana' },
  { value: 'month', label: 'Mes' },
]

/** Para la casilla «Repetir cada…». */
export const EVERY: Record<Period, string> = {
  day: 'cada día',
  week: 'cada semana',
  month: 'cada mes',
}
