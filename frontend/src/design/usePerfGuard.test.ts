import { describe, expect, it } from 'vitest'
import { shouldGoLite } from './usePerfGuard'

describe('shouldGoLite', () => {
  it('no decide con pocas muestras', () => {
    expect(shouldGoLite(Array(30).fill(100))).toBe(false)
  })
  it('mantiene el cristal completo si los fotogramas van a ~60 fps', () => {
    expect(shouldGoLite(Array(120).fill(16.7))).toBe(false)
  })
  it('tolera tirones aislados', () => {
    const d = Array(120).fill(16.7)
    for (let i = 0; i < 120; i += 12) d[i] = 90
    expect(shouldGoLite(d)).toBe(false)
  })
  it('pasa a modo ligero cuando la ventana va lenta de forma sostenida', () => {
    expect(shouldGoLite(Array(100).fill(66))).toBe(true)
  })
  it('solo mira la ventana más reciente', () => {
    expect(shouldGoLite([...Array(200).fill(100), ...Array(90).fill(16.7)])).toBe(false)
  })
})
