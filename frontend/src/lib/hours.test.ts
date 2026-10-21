import { formatHours, hoursFor, lifeHoursNote } from './hours'

describe('hoursFor', () => {
  it('divide el importe entre el valor de la hora', () => {
    expect(hoursFor(23.08, 11.54)).toBeCloseTo(2)
  })
  it('usa el valor absoluto (un gasto puede venir con signo)', () => {
    expect(hoursFor(-11.54, 11.54)).toBeCloseTo(1)
  })
  it('null con una hora sin valor', () => {
    expect(hoursFor(10, 0)).toBeNull()
    expect(hoursFor(10, -3)).toBeNull()
  })
})

describe('formatHours', () => {
  it.each([
    [0.001, '< 1 min'],
    [0.2, '12 min'],
    [1, '1 h'],
    [1.5, '1 h 30 min'],
    [2.0083, '2 h'],
    [26.4, '26 h'],
  ])('%s h → %s', (hours, text) => expect(formatHours(hours)).toBe(text))
})

describe('lifeHoursNote', () => {
  it('describe el importe en tiempo de trabajo', () => {
    expect(lifeHoursNote(23.08, 11.54)).toBe('≈ 2 h de trabajo')
  })
  it('no dice nada sin valor de hora', () => {
    expect(lifeHoursNote(10, undefined)).toBeUndefined()
  })
})
