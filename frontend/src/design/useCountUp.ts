import { useEffect, useRef, useState } from 'react'

const DURATION_MS = 700

function prefersReducedMotion(): boolean {
  // jsdom y entornos sin matchMedia: sin animación (los tests ven el valor final al instante)
  return (
    typeof window.matchMedia !== 'function' ||
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  )
}

/** Anima un número desde su valor anterior hasta `target` (ease-out). Respeta "reducir movimiento". */
export function useCountUp(target: number): number {
  const [value, setValue] = useState(() => (prefersReducedMotion() ? target : 0))
  const from = useRef(value)

  useEffect(() => {
    if (prefersReducedMotion()) {
      setValue(target)
      return
    }
    const start = performance.now()
    const origin = from.current
    let frame = 0
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / DURATION_MS)
      const eased = 1 - Math.pow(1 - t, 3)
      const current = origin + (target - origin) * eased
      from.current = current
      setValue(t === 1 ? target : current)
      if (t < 1) frame = requestAnimationFrame(tick)
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  }, [target])

  return value
}
