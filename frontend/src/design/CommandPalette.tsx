import { Fragment, useEffect, useId, useMemo, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { useNavigate } from 'react-router-dom'
import { Button, Glass, type NavItem } from './components'
import { Icon, type IconName } from './Icon'

export interface Command {
  id: string
  label: string
  icon: IconName
  group: string
  /** Ruta a la que navega; si falta, se ejecuta `run`. */
  to?: string
  run?: () => void
}

/** Texto sin tildes y en minúsculas, para buscar «categorias» y encontrar «Categorías». */
const plain = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase()

/** Paleta de comandos de cristal (Ctrl/⌘ + K): ir a una pantalla o ejecutar una acción con el teclado. */
export function CommandPalette({ items, actions }: { items: NavItem[]; actions: Command[] }) {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const [active, setActive] = useState(0)
  const navigate = useNavigate()
  const input = useRef<HTMLInputElement>(null)
  const listId = useId()

  const commands = useMemo<Command[]>(
    () => [
      ...items.map((i) => ({
        id: `go-${i.to}`,
        label: i.label,
        icon: i.icon,
        group: 'Ir a',
        to: i.to,
      })),
      ...actions,
    ],
    [items, actions],
  )
  const shown = useMemo(() => {
    const q = plain(query.trim())
    return q ? commands.filter((c) => plain(c.label).includes(q)) : commands
  }, [commands, query])

  const close = () => {
    setOpen(false)
    setQuery('')
    setActive(0)
  }
  const choose = (c: Command | undefined) => {
    if (!c) return
    close()
    if (c.to) navigate(c.to)
    else c.run?.()
  }

  // Atajo global
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        setOpen((o) => !o)
      }
    }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [])

  // El foco entra al buscador y vuelve a donde estaba al cerrar
  useEffect(() => {
    if (!open) return
    const previous = document.activeElement as HTMLElement | null
    input.current?.focus()
    return () => previous?.focus?.()
  }, [open])

  const onInputKey = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault()
      const n = shown.length
      if (n) setActive((a) => (a + (e.key === 'ArrowDown' ? 1 : n - 1)) % n)
    } else if (e.key === 'Enter') {
      e.preventDefault()
      choose(shown[active])
    } else if (e.key === 'Escape') {
      e.preventDefault()
      close()
    }
  }

  return (
    <>
      <Button
        variant="ghost"
        size="sm"
        icon="search"
        aria-label="Paleta de comandos (Ctrl K)"
        aria-haspopup="dialog"
        onClick={() => setOpen(true)}
      />
      {open &&
        createPortal(
          <div
            className="cr cr-overlay cr-palette-overlay"
            onMouseDown={(e) => e.target === e.currentTarget && close()}
          >
            <Glass
              strong
              className="cr-palette"
              role="dialog"
              aria-modal="true"
              aria-label="Paleta de comandos"
            >
              <div className="cr-palette-field">
                <Icon name="search" />
                <input
                  ref={input}
                  value={query}
                  onChange={(e) => {
                    setQuery(e.target.value)
                    setActive(0)
                  }}
                  onKeyDown={onInputKey}
                  placeholder="Ir a o ejecutar…"
                  role="combobox"
                  aria-expanded="true"
                  aria-controls={listId}
                  aria-activedescendant={
                    shown[active] ? `${listId}-${shown[active].id}` : undefined
                  }
                  aria-label="Comando"
                  autoComplete="off"
                  spellCheck={false}
                />
                <kbd>Esc</kbd>
              </div>
              <ul id={listId} role="listbox" aria-label="Comandos" className="cr-palette-list">
                {shown.length === 0 && (
                  <li className="cr-palette-empty" role="presentation">
                    Sin resultados para «{query}»
                  </li>
                )}
                {shown.map((c, i) => (
                  <Fragment key={c.id}>
                    {(i === 0 || shown[i - 1].group !== c.group) && (
                      <li className="cr-palette-group" role="presentation">
                        {c.group}
                      </li>
                    )}
                    <li
                      id={`${listId}-${c.id}`}
                      role="option"
                      aria-selected={i === active}
                      onMouseMove={() => setActive(i)}
                      onClick={() => choose(c)}
                    >
                      <Icon name={c.icon} />
                      {c.label}
                    </li>
                  </Fragment>
                ))}
              </ul>
            </Glass>
          </div>,
          document.body,
        )}
    </>
  )
}
