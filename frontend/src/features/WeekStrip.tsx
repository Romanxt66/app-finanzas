import { useState } from 'react'
import { Glass, Icon } from '../design'

import { isoDay as iso, parseDay as parse, weekStart } from '../lib/dates'

/** Tira de la semana (lun–dom). Tocar un día lo elige y tocarlo otra vez lo suelta; la píldora se desliza. */
export function WeekStrip({
  selected,
  onChange,
  marked = new Set<string>(),
}: {
  selected: string | null
  onChange: (day: string | null) => void
  marked?: Set<string>
}) {
  const [week, setWeek] = useState(() => weekStart(selected ? parse(selected) : new Date()))
  // Si el día elegido cambia desde fuera, la tira salta a su semana (estado derivado, sin efecto)
  const [shownFor, setShownFor] = useState(selected)
  if (selected !== shownFor) {
    setShownFor(selected)
    if (selected) setWeek(weekStart(parse(selected)))
  }
  const [today] = useState(() => iso(new Date()))
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(week)
    d.setDate(week.getDate() + i)
    return d
  })
  const index = days.findIndex((d) => iso(d) === selected)
  const end = days[6]
  const month = (d: Date, style: 'long' | 'short') =>
    d.toLocaleDateString('es-CO', { month: style })
  const range =
    week.getMonth() === end.getMonth()
      ? `${week.getDate()}–${end.getDate()} de ${month(end, 'long')}`
      : `${week.getDate()} ${month(week, 'short')} – ${end.getDate()} ${month(end, 'short')}`
  const shift = (n: number) =>
    setWeek((w) => {
      const d = new Date(w)
      d.setDate(w.getDate() + 7 * n)
      return d
    })
  return (
    <Glass size="md" className="cr-week" role="group" aria-label="Elegir un día">
      <div className="cr-week-head">
        <button
          type="button"
          className="cr-week-arrow is-prev"
          aria-label="Semana anterior"
          onClick={() => shift(-1)}
        >
          <Icon name="chevron" />
        </button>
        <span className="caption cr-muted">{range}</span>
        <button
          type="button"
          className="cr-week-arrow"
          aria-label="Semana siguiente"
          onClick={() => shift(1)}
        >
          <Icon name="chevron" />
        </button>
      </div>
      <div className="cr-week-days" style={{ ['--sel' as string]: index }}>
        {index >= 0 && <span className="cr-week-pill" aria-hidden="true" />}
        {days.map((d) => {
          const key = iso(d)
          const on = key === selected
          return (
            <button
              key={key}
              type="button"
              className="cr-week-day"
              aria-pressed={on}
              title={d.toLocaleDateString('es-CO', {
                weekday: 'long',
                day: 'numeric',
                month: 'long',
              })}
              data-today={key === today || undefined}
              onClick={() => onChange(on ? null : key)}
            >
              <span className="cr-week-name" aria-hidden="true">
                {d.toLocaleDateString('es-CO', { weekday: 'narrow' }).toUpperCase()}
              </span>
              <span className="cr-week-num">{d.getDate()}</span>
              {/* El nombre accesible empieza por el número visible (WCAG 2.5.3) */}
              <span className="cr-sr-only">
                {d.toLocaleDateString('es-CO', { month: 'long' })},{' '}
                {d.toLocaleDateString('es-CO', { weekday: 'long' })}
              </span>
              <span className="cr-week-dot" data-on={(marked.has(key) && !on) || undefined} />
            </button>
          )
        })}
      </div>
    </Glass>
  )
}
