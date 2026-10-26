import { useEffect } from 'react'

// Módulos que se inclinan hacia el cursor (los que ya se elevan al pasar el ratón)
const TILT = '.cr-balance, .cr-stat, .cr-budget'

/**
 * Efectos de cristal que siguen al cursor: reflejo especular (--mx, --my, --hl en cada `.cr-glass`),
 * parallax del fondo (--px, --py en <html>) e inclinación 3D de los módulos. Solo punteros finos y sin
 * «reducir movimiento»: en táctil o con la preferencia activa no hace nada. Una sola escucha global.
 */
export function useGlassFx() {
  useEffect(() => {
    if (typeof matchMedia === 'undefined') return
    const fine = matchMedia('(hover: hover) and (pointer: fine)')
    const calm = matchMedia('(prefers-reduced-motion: reduce)')
    if (!fine.matches || calm.matches) return

    const root = document.documentElement
    let raf = 0
    let last: PointerEvent | undefined

    const frame = () => {
      raf = 0
      if (!last) return
      const { clientX: x, clientY: y } = last
      document.querySelectorAll<HTMLElement>('.cr-glass').forEach((el) => {
        const r = el.getBoundingClientRect()
        if (r.bottom < 0 || r.top > innerHeight) return
        el.style.setProperty('--mx', `${x - r.left}px`)
        el.style.setProperty('--my', `${y - r.top}px`)
        // el brillo se intensifica cerca del módulo
        const dx = Math.max(r.left - x, 0, x - r.right)
        const dy = Math.max(r.top - y, 0, y - r.bottom)
        el.style.setProperty('--hl', Math.max(0, 1 - Math.hypot(dx, dy) / 260).toFixed(2))
      })
      root.style.setProperty('--px', (x / innerWidth - 0.5).toFixed(3))
      root.style.setProperty('--py', (y / innerHeight - 0.5).toFixed(3))
    }

    const move = (e: PointerEvent) => {
      last = e
      if (!raf) raf = requestAnimationFrame(frame)
      const card = (e.target as Element | null)?.closest?.<HTMLElement>(TILT)
      if (card) {
        const r = card.getBoundingClientRect()
        const rx = ((e.clientY - r.top) / r.height - 0.5) * -5
        const ry = ((e.clientX - r.left) / r.width - 0.5) * 6
        card.style.transform = `perspective(900px) rotateX(${rx.toFixed(2)}deg) rotateY(${ry.toFixed(2)}deg) translateY(-2px)`
      }
    }
    const out = (e: PointerEvent) => {
      const card = (e.target as Element | null)?.closest?.<HTMLElement>(TILT)
      if (card && !card.contains(e.relatedTarget as Node | null)) card.style.transform = ''
    }

    addEventListener('pointermove', move, { passive: true })
    addEventListener('pointerout', out)
    return () => {
      removeEventListener('pointermove', move)
      removeEventListener('pointerout', out)
      cancelAnimationFrame(raf)
    }
  }, [])
}
