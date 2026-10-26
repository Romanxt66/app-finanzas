import { fireEvent, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { CommandPalette, type Command } from './CommandPalette'
import type { NavItem } from './components'
import { renderApp } from '../test-utils'

const items: NavItem[] = [
  { to: '/', label: 'Inicio', icon: 'home', end: true },
  { to: '/categories', label: 'Categorías', icon: 'tag' },
]

function setup(run = vi.fn()) {
  const actions: Command[] = [
    { id: 'logout', label: 'Cerrar sesión', icon: 'logout', group: 'Cuenta', run },
  ]
  renderApp(<CommandPalette items={items} actions={actions} />)
  return run
}

describe('CommandPalette', () => {
  it('se abre con Ctrl+K, busca sin tildes y ejecuta con Enter', () => {
    const run = setup()
    expect(screen.queryByRole('dialog')).toBeNull()
    fireEvent.keyDown(document, { key: 'k', ctrlKey: true })
    expect(screen.getByRole('dialog', { name: 'Paleta de comandos' })).toBeTruthy()

    const box = screen.getByRole('combobox')
    fireEvent.change(box, { target: { value: 'sesion' } })
    expect(screen.getAllByRole('option')).toHaveLength(1)
    fireEvent.keyDown(box, { key: 'Enter' })
    expect(run).toHaveBeenCalledOnce()
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('navega con flechas y se cierra con Escape; muestra el estado vacío', () => {
    setup()
    fireEvent.click(screen.getByRole('button', { name: /Paleta de comandos \(Ctrl K\)/ }))
    const box = screen.getByRole('combobox')
    expect(screen.getAllByRole('option')).toHaveLength(3)
    expect(screen.getAllByRole('option')[0].getAttribute('aria-selected')).toBe('true')
    fireEvent.keyDown(box, { key: 'ArrowDown' })
    expect(screen.getAllByRole('option')[1].getAttribute('aria-selected')).toBe('true')

    fireEvent.change(box, { target: { value: 'zzz' } })
    expect(screen.getByText(/Sin resultados/)).toBeTruthy()
    fireEvent.keyDown(box, { key: 'Escape' })
    expect(screen.queryByRole('dialog')).toBeNull()
  })
})
