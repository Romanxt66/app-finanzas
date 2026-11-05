import { dayLabel, weekStart } from './dates'

describe('fechas del historial', () => {
  it('la semana empieza el lunes', () => {
    expect(weekStart(new Date(2026, 10, 5))).toEqual(new Date(2026, 10, 2)) // jueves → lunes
    expect(weekStart(new Date(2026, 10, 8))).toEqual(new Date(2026, 10, 2)) // domingo → lunes anterior
  })

  it('nombra hoy, ayer y el resto por su día', () => {
    const now = new Date(2026, 10, 5, 15)
    expect(dayLabel('2026-11-05', now).name).toBe('hoy')
    expect(dayLabel('2026-11-04', now).name).toBe('ayer')
    expect(dayLabel('2026-11-02', now).name).toBe('lunes')
  })
})
