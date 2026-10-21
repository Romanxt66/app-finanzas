import { monthStart, todayISO } from './format'

describe('format', () => {
  it('monthStart devuelve el día 1', () => {
    expect(monthStart(new Date(2026, 2, 17))).toBe('2026-03-01')
  })
  it('todayISO tiene formato ISO', () => {
    expect(todayISO()).toMatch(/^\d{4}-\d{2}-\d{2}$/)
  })
})
