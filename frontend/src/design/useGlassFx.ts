import { useEffect } from 'react'

// Módulos que se inclinan hacia el cursor (los que ya se elevan al pasar el ratón)
const TILT = '.cr-balance, .cr-stat, .cr-budget'

/**
 * Efectos de cristal que siguen al cursor: reflejo especular (--mx, --my, --hl) y ligera inclinación 3D.
 * Solo toca UN módulo por fotograma (el que está bajo el puntero) y nunca recorre el documento: así el
 * coste no depende de cuántas tarjetas haya. Solo punteros finos, sin «reducir movimiento» y fuera del
 * modo ligero (ver usePerfGuard).
 */
export function useGlassFx() {
  useEffect(() => {
    if (typeof matchMedia === 'undefined') return
    const fine = matchMedia('(hover: hover) and (pointer: fine)')
    const calm = matchMedia('(prefers-reduced-motion: reduce)')
    if (!fine.matches || calm.matches) return

    let raf = 0
    let x = 0
    let y = 0
    let current: HTMLElement | null = null

    const frame = () => {
      raf = 0
      if (document.documentElement.dataset.perf === 'lite') return
      const glass = (document.elementFromPoint(x, y) as Element | null)?.closest<HTMLElement>(
        '.cr-glass',
      )
      if (current && current !== glass) current.style.setProperty('--hl', '0')
      current = glass ?? null
      if (!glass) return
      const r = glass.getBoundingClientRect()
      glass.style.setProperty('--mx', `${Math.round(x - r.left)}px`)
      glass.style.setProperty('--my', `${Math.round(y - r.top)}px`)
      glass.style.setProperty('--hl', '1')
    }

    const move = (e: PointerEvent) => {
      x = e.clientX
      y = e.clientY
      if (!raf) raf = requestAnimationFrame(frame)
      if (document.documentElement.dataset.perf === 'lite') return
      const card = (e.target as Element | null)?.closest?.<HTMLElement>(TILT)
      if (card) {
        const r = card.getBoundingClientRect()
        const rx = ((y - r.top) / r.height - 0.5) * -5
        const ry = ((x - r.left) / r.width - 0.5) * 6
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
