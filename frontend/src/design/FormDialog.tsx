import { useEffect, useId, useRef, type ReactNode } from 'react'
import { Glass } from './components'

/** Diálogo modal para formularios cortos. Escape y clic fuera cierran; el foco vuelve al origen. */
export function FormDialog({
  open,
  title,
  onClose,
  children,
}: {
  open: boolean
  title: string
  onClose: () => void
  children: ReactNode
}) {
  const titleId = useId()
  const panel = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const previous = document.activeElement as HTMLElement | null
    panel.current?.querySelector<HTMLElement>('input, select, textarea, button')?.focus()
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('keydown', onKey)
      previous?.focus?.()
    }
  }, [open, onClose])

  if (!open) return null
  return (
    <div className="cr cr-overlay" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <Glass
        strong
        padded
        className="cr-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
      >
        <div ref={panel} className="cr-stack">
          <h2 id={titleId} className="heading">
            {title}
          </h2>
          {children}
        </div>
      </Glass>
    </div>
  )
}
