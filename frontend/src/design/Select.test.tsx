import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { vi } from 'vitest'
import { Select } from './Select'

// jsdom no tiene matchMedia: se simula un puntero fino (ratón) para activar el menú de cristal
beforeEach(() => {
  window.matchMedia = ((query: string) => ({
    matches: query === '(pointer: fine)',
    media: query,
  })) as typeof window.matchMedia
})
afterEach(() => {
  delete (window as { matchMedia?: unknown }).matchMedia
  vi.restoreAllMocks()
})

function Harness({ onChange }: { onChange?: (value: string) => void }) {
  const [value, setValue] = useState('')
  return (
    <Select
      label="Moneda"
      value={value}
      onChange={(e) => {
        setValue(e.target.value)
        onChange?.(e.target.value)
      }}
    >
      <option value="">Selecciona…</option>
      {Array.from({ length: 30 }, (_, i) => (
        <option key={i} value={`M${i}`}>
          Moneda {i}
        </option>
      ))}
    </Select>
  )
}

describe('Select de cristal', () => {
  it('se abre con el ratón y elige una opción', async () => {
    const onChange = vi.fn()
    render(<Harness onChange={onChange} />)
    await userEvent.click(screen.getByLabelText('Moneda'))
    const menu = await screen.findByRole('listbox', { name: 'Moneda' })
    expect(menu.querySelectorAll('[role="option"]')).toHaveLength(31)
    await userEvent.click(within(menu).getByRole('option', { name: 'Moneda 7' }))
    expect(onChange).toHaveBeenCalledWith('M7')
    expect(screen.queryByRole('listbox')).not.toBeInTheDocument()
    expect(screen.getByLabelText('Moneda')).toHaveValue('M7')
  })

  it('desplazarse DENTRO del menú no lo cierra (para llegar a las últimas opciones)', async () => {
    render(<Harness />)
    await userEvent.click(screen.getByLabelText('Moneda'))
    const menu = await screen.findByRole('listbox', { name: 'Moneda' })
    fireEvent.scroll(menu)
    fireEvent.scroll(within(menu).getByRole('option', { name: 'Moneda 20' }))
    expect(screen.getByRole('listbox')).toBeInTheDocument()
  })

  it('el scroll de la página sí lo cierra', async () => {
    render(<Harness />)
    await userEvent.click(screen.getByLabelText('Moneda'))
    await screen.findByRole('listbox')
    fireEvent.scroll(document)
    expect(screen.queryByRole('listbox')).not.toBeInTheDocument()
  })

  it('arrastrar la barra del menú no le quita el foco al campo', async () => {
    render(<Harness />)
    await userEvent.click(screen.getByLabelText('Moneda'))
    const menu = await screen.findByRole('listbox')
    const notPrevented = fireEvent.mouseDown(menu)
    expect(notPrevented).toBe(false) // preventDefault evita el blur que cerraría el menú
    expect(screen.getByRole('listbox')).toBeInTheDocument()
  })
})
