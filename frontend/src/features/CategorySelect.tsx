import {
  forwardRef,
  useCallback,
  useEffect,
  useRef,
  useState,
  type ChangeEvent,
  type FormEvent,
  type SelectHTMLAttributes,
} from 'react'
import { useCategories, useCategorySuggestions, useCreateCategory } from '../api/hooks'
import { Button, ErrorText, FormDialog, Input, Select } from '../design'

const NEW = '__new__'
const SUGGESTED = 'suggested:'

type Props = {
  kind: 'income' | 'expense'
  label?: string
  emptyLabel?: string
  error?: string
} & Omit<SelectHTMLAttributes<HTMLSelectElement>, 'children'>

/**
 * Selector de categoría: las del usuario, las sugeridas (se crean al elegirlas) y
 * «Nueva categoría…» para escribir una propia sin salir del formulario.
 */
export const CategorySelect = forwardRef<HTMLSelectElement, Props>(function CategorySelect(
  { kind, label = 'Categoría', emptyLabel = 'Sin categoría', onChange, ...props },
  ref,
) {
  const { data: categories = [] } = useCategories()
  const { data: suggestions } = useCategorySuggestions()
  const create = useCreateCategory()
  const [dialog, setDialog] = useState(false)
  const [name, setName] = useState('')
  const element = useRef<HTMLSelectElement | null>(null)
  const previous = useRef('')
  const pending = useRef<string | null>(null)

  const mine = categories.filter((c) => c.kind === kind)
  const taken = new Set(mine.map((c) => c.name.toLocaleLowerCase()))
  const offered = (suggestions?.[kind] ?? []).filter((n) => !taken.has(n.toLocaleLowerCase()))

  const setRefs = useCallback(
    (el: HTMLSelectElement | null) => {
      element.current = el
      if (typeof ref === 'function') ref(el)
      else if (ref) ref.current = el
    },
    [ref],
  )

  // Selecciona la categoría recién creada en cuanto su <option> existe, avisando al formulario
  const applyPending = useCallback(() => {
    const el = element.current
    const id = pending.current
    if (!el || !id || !Array.from(el.options).some((o) => o.value === id)) return
    pending.current = null
    el.value = id
    previous.current = id
    el.dispatchEvent(new Event('change', { bubbles: true }))
  }, [])

  useEffect(() => {
    applyPending()
    const value = element.current?.value
    if (value !== undefined && value !== NEW && !value.startsWith(SUGGESTED)) {
      previous.current = value
    }
  })

  const add = async (categoryName: string) => {
    const existing = mine.find(
      (c) => c.name.toLocaleLowerCase() === categoryName.toLocaleLowerCase(),
    )
    try {
      const category = existing ?? (await create.mutateAsync({ name: categoryName, kind }))
      pending.current = category.id
      setDialog(false)
      applyPending()
    } catch {
      /* el error queda en create.error y se muestra en el diálogo */
    }
  }

  const handleChange = (event: ChangeEvent<HTMLSelectElement>) => {
    const value = event.target.value
    if (value === NEW || value.startsWith(SUGGESTED)) {
      event.target.value = previous.current // no se guarda el valor especial
      if (value === NEW) {
        setName('')
        create.reset()
        setDialog(true)
      } else {
        void add(value.slice(SUGGESTED.length))
      }
      return
    }
    previous.current = value
    onChange?.(event)
  }

  const submit = (event: FormEvent) => {
    // El diálogo vive en un portal: sin esto el envío sube por el árbol de React hasta el
    // formulario de la pantalla y lo enviaría también.
    event.preventDefault()
    event.stopPropagation()
    const trimmed = name.trim()
    if (trimmed) void add(trimmed)
  }

  return (
    <>
      <Select label={label} ref={setRefs} onChange={handleChange} {...props}>
        <option value="">{emptyLabel}</option>
        {mine.map((c) => (
          <option key={c.id} value={c.id}>
            {c.name}
          </option>
        ))}
        {offered.map((n) => (
          <option key={`suggested-${n}`} value={`${SUGGESTED}${n}`}>
            {n} · sugerida
          </option>
        ))}
        <option value={NEW}>＋ Nueva categoría…</option>
      </Select>
      <FormDialog open={dialog} title="Nueva categoría" onClose={() => setDialog(false)}>
        <form className="cr-stack" onSubmit={submit}>
          <Input
            label="Nombre de la categoría"
            value={name}
            maxLength={80}
            onChange={(e) => setName(e.target.value)}
          />
          <ErrorText error={create.error} />
          <div className="cr-row">
            <Button type="submit" variant="primary" disabled={!name.trim() || create.isPending}>
              Crear
            </Button>
            <Button onClick={() => setDialog(false)}>Cancelar</Button>
          </div>
        </form>
      </FormDialog>
    </>
  )
})
