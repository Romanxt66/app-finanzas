/**
 * Curva monótona (Fritsch–Carlson): pasa por todos los puntos sin inventar picos ni bajar de cero
 * cuando los datos no lo hacen. Es la misma curva que dibuja la app Android.
 */
export function monotonePath(pts: [number, number][]): string {
  const n = pts.length
  if (n < 2) return ''
  const dx = pts.slice(1).map((p, i) => p[0] - pts[i][0])
  const sl = pts.slice(1).map((p, i) => (p[1] - pts[i][1]) / (dx[i] || 1))
  const m = pts.map((_, i) =>
    i === 0
      ? sl[0]
      : i === n - 1
        ? sl[n - 2]
        : sl[i - 1] * sl[i] <= 0
          ? 0
          : (sl[i - 1] + sl[i]) / 2,
  )
  for (let i = 0; i < n - 1; i++) {
    if (sl[i] === 0) {
      m[i] = m[i + 1] = 0
      continue
    }
    const a = m[i] / sl[i]
    const b = m[i + 1] / sl[i]
    const h = a * a + b * b
    if (h > 9) {
      const t = 3 / Math.sqrt(h)
      m[i] = t * a * sl[i]
      m[i + 1] = t * b * sl[i]
    }
  }
  const f = (v: number) => v.toFixed(1)
  let d = `M${f(pts[0][0])} ${f(pts[0][1])}`
  for (let i = 0; i < n - 1; i++) {
    const [x0, y0] = pts[i]
    const [x1, y1] = pts[i + 1]
    const h = (x1 - x0) / 3
    d += `C${f(x0 + h)} ${f(y0 + m[i] * h)} ${f(x1 - h)} ${f(y1 - m[i + 1] * h)} ${f(x1)} ${f(y1)}`
  }
  return d
}
