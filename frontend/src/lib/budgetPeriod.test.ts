import { periodLabel, periodStart, shiftPeriod } from './budgetPeriod'

describe('periodos de presupuesto', () => {
  it('la semana empieza el lunes y el mes el día 1', () => {
    expect(periodStart('week', '2026-11-12')).toBe('2026-11-09')
    expect(periodStart('week', '2026-11-15')).toBe('2026-11-09') // domingo
    expect(periodStart('month', '2026-11-12')).toBe('2026-11-01')
    expect(periodStart('day', '2026-11-12')).toBe('2026-11-12')
  })

  it('recorre periodos hacia atrás y adelante', () => {
    expect(shiftPeriod('day', '2026-11-30', 1)).toBe('2026-12-01')
    expect(shiftPeriod('week', '2026-11-12', -1)).toBe('2026-11-02')
    expect(shiftPeriod('month', '2026-01-20', -1)).toBe('2025-12-01')
  })

  it('etiquetas legibles', () => {
    expect(periodLabel('month', '2026-11-12')).toBe('noviembre 2026')
    expect(periodLabel('week', '2026-11-12')).toMatch(/^9 – 15 nov/)
    expect(periodLabel('week', '2026-11-30')).toMatch(/30 nov – 6 dic/)
  })
})
