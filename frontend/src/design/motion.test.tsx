import { act, render, renderHook, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { vi } from 'vitest'
import { Button, Skeleton } from './components'
import { ConfirmDialog } from './Confirm'
import { applyStoredTheme, useTheme } from './theme'
import { ToastProvider } from './Toast'
import { useToast } from './toastContext'
import { useCountUp } from './useCountUp'

describe('ConfirmDialog', () => {
  const setup = (open = true) => {
    const onConfirm = vi.fn()
    const onCancel = vi.fn()
    render(
      <ConfirmDialog open={open} title="¿Eliminar?" onConfirm={onConfirm} onCancel={onCancel}>
        No se puede deshacer.
      </ConfirmDialog>,
    )
    return { onConfirm, onCancel }
  }

  it('no renderiza nada cerrado', () => {
    setup(false)
    expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument()
  })

  it('enfoca "Cancelar" (acción segura) y confirma solo con el botón destructivo', async () => {
    const { onConfirm, onCancel } = setup()
    expect(screen.getByRole('alertdialog')).toHaveAccessibleName('¿Eliminar?')
    expect(screen.getByRole('button', { name: 'Cancelar' })).toHaveFocus()
    await userEvent.click(screen.getByRole('button', { name: 'Eliminar' }))
    expect(onConfirm).toHaveBeenCalledTimes(1)
    expect(onCancel).not.toHaveBeenCalled()
  })

  it('Escape y clic fuera cancelan', async () => {
    const { onConfirm, onCancel } = setup()
    await userEvent.keyboard('{Escape}')
    expect(onCancel).toHaveBeenCalledTimes(1)
    await userEvent.click(document.querySelector('.cr-overlay')!)
    expect(onCancel).toHaveBeenCalledTimes(2)
    expect(onConfirm).not.toHaveBeenCalled()
  })

  it('devuelve el foco al elemento que lo abrió', async () => {
    function Harness() {
      const [open, setOpen] = useState(false)
      return (
        <>
          <Button onClick={() => setOpen(true)}>Abrir</Button>
          <ConfirmDialog
            open={open}
            title="t"
            onConfirm={() => setOpen(false)}
            onCancel={() => setOpen(false)}
          />
        </>
      )
    }
    render(<Harness />)
    const opener = screen.getByRole('button', { name: 'Abrir' })
    await userEvent.click(opener)
    await userEvent.keyboard('{Escape}')
    expect(opener).toHaveFocus()
  })
})

describe('Toast', () => {
  function Trigger() {
    const toast = useToast()
    return <Button onClick={() => toast.success('Cuenta creada')}>Ok</Button>
  }

  it('muestra el aviso en una región aria-live y se retira solo', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true })
    render(
      <ToastProvider>
        <Trigger />
      </ToastProvider>,
    )
    await userEvent.click(screen.getByRole('button', { name: 'Ok' }))
    expect(screen.getByRole('status')).toHaveTextContent('Cuenta creada')
    act(() => void vi.advanceTimersByTime(4000))
    await waitFor(() => expect(screen.getByRole('status')).not.toHaveTextContent('Cuenta creada'))
    vi.useRealTimers()
  })

  it('sin proveedor no falla', async () => {
    render(<Trigger />)
    await userEvent.click(screen.getByRole('button', { name: 'Ok' }))
  })
})

describe('tema', () => {
  beforeEach(() => {
    localStorage.clear()
    document.documentElement.removeAttribute('data-theme')
  })

  it('cicla automático → claro → oscuro → automático y lo recuerda', () => {
    const { result } = renderHook(() => useTheme())
    expect(result.current.choice).toBe('system')
    act(() => result.current.cycle())
    expect(document.documentElement).toHaveAttribute('data-theme', 'light')
    expect(localStorage.getItem('theme')).toBe('light')
    act(() => result.current.cycle())
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark')
    act(() => result.current.cycle())
    expect(document.documentElement).not.toHaveAttribute('data-theme')
    expect(localStorage.getItem('theme')).toBeNull()
  })

  it('aplica la preferencia guardada al arrancar', () => {
    localStorage.setItem('theme', 'dark')
    applyStoredTheme()
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark')
  })
})

describe('useCountUp y esqueletos', () => {
  it('sin matchMedia (jsdom) devuelve el valor final sin animar', () => {
    const { result, rerender } = renderHook(({ v }) => useCountUp(v), { initialProps: { v: 100 } })
    expect(result.current).toBe(100)
    rerender({ v: 250 })
    expect(result.current).toBe(250)
  })

  it('anima hasta el valor y termina exactamente en él', async () => {
    const original = window.matchMedia
    window.matchMedia = ((q: string) => ({ matches: false, media: q })) as typeof window.matchMedia
    const { result } = renderHook(() => useCountUp(1000))
    expect(result.current).toBe(0)
    await waitFor(() => expect(result.current).toBe(1000), { timeout: 6000 })
    window.matchMedia = original
  })

  it('"reducir movimiento" desactiva el conteo', () => {
    const original = window.matchMedia
    window.matchMedia = ((q: string) => ({ matches: true, media: q })) as typeof window.matchMedia
    const { result } = renderHook(() => useCountUp(500))
    expect(result.current).toBe(500)
    window.matchMedia = original
  })

  it('Skeleton anuncia la carga a lectores de pantalla', () => {
    render(<Skeleton lines={2} />)
    expect(screen.getByRole('status')).toHaveTextContent('Cargando…')
    expect(document.querySelectorAll('.cr-skeleton')).toHaveLength(2)
  })
})
