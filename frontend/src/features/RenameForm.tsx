import { useState } from 'react'
import { Button, ErrorText, Input } from '../design'

/** Formulario de un solo campo de texto (renombrar cuenta/categoría, editar un monto…). */
export function RenameForm(props: {
  initial: string
  label: string
  pending?: boolean
  error?: unknown
  inputMode?: 'text' | 'decimal'
  validate?: (value: string) => string | null
  onSubmit: (value: string) => void
  onCancel: () => void
}) {
  const [value, setValue] = useState(props.initial)
  const [problem, setProblem] = useState<string | null>(null)
  return (
    <form
      className="cr-stack"
      onSubmit={(e) => {
        e.preventDefault()
        const trimmed = value.trim()
        const error = props.validate ? props.validate(trimmed) : trimmed ? null : 'Requerido'
        setProblem(error)
        if (!error) props.onSubmit(trimmed)
      }}
    >
      <Input
        label={props.label}
        value={value}
        inputMode={props.inputMode}
        onChange={(e) => setValue(e.target.value)}
        error={problem ?? undefined}
      />
      <ErrorText error={props.error} />
      <div className="cr-dialog-actions">
        <Button variant="ghost" onClick={props.onCancel}>
          Cancelar
        </Button>
        <Button type="submit" variant="primary" disabled={props.pending}>
          Guardar
        </Button>
      </div>
    </form>
  )
}
