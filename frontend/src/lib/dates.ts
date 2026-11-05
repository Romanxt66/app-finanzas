/** Fecha local yyyy-MM-dd. */
export const isoDay = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

/** yyyy-MM-dd (o una fecha ISO más larga) a medianoche local. */
export function parseDay(s: string): Date {
  const [y, m, d] = s.slice(0, 10).split('-').map(Number)
  return new Date(y, m - 1, d)
}

/** Lunes de la semana de `d`. */
export function weekStart(d: Date): Date {
  const day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  day.setDate(day.getDate() - ((day.getDay() + 6) % 7))
  return day
}

/** Encabezado de un día en la lista («5 nov · hoy»). */
export function dayLabel(day: string, now = new Date()): { date: string; name: string } {
  const d = parseDay(day)
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const diff = Math.round((today.getTime() - d.getTime()) / 86400000)
  const name =
    diff === 0 ? 'hoy' : diff === 1 ? 'ayer' : d.toLocaleDateString('es-CO', { weekday: 'long' })
  return { date: d.toLocaleDateString('es-CO', { day: 'numeric', month: 'short' }), name }
}
