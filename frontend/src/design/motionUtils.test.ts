import { monotonePath } from './motionUtils'

const nums = (d: string) => d.match(/-?\d+(\.\d+)?/g)!.map(Number)

describe('monotonePath', () => {
  it('pasa por todos los puntos', () => {
    const d = monotonePath([
      [0, 10],
      [10, 0],
      [20, 5],
    ])
    expect(d.startsWith('M0.0 10.0')).toBe(true)
    expect(d).toContain('10.0 0.0')
    expect(d.endsWith('20.0 5.0')).toBe(true)
  })

  it('no inventa picos: los puntos de control no salen del rango de los datos', () => {
    const ys = [40, 38, 3, 3, 20, 2]
    const d = monotonePath(ys.map((y, i) => [i * 10, y]))
    const values = nums(d).filter((_, i) => i % 2 === 1)
    expect(Math.min(...values)).toBeGreaterThanOrEqual(2)
    expect(Math.max(...values)).toBeLessThanOrEqual(40)
  })

  it('con menos de dos puntos no dibuja nada', () => {
    expect(monotonePath([[0, 0]])).toBe('')
  })
})
