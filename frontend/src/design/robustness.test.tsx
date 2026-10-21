import { act, render, renderHook, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { vi } from 'vitest'
import { ErrorBoundary } from './ErrorBoundary'
import { useOnline } from './useOnline'

function Boom(): never {
  throw new Error('fallo de prueba')
}

describe('ErrorBoundary', () => {
  it('muestra una pantalla amable con acción de recarga y reporta el error', async () => {
    const onError = vi.fn()
    const reload = vi.fn()
    vi.spyOn(console, 'error').mockImplementation(() => {})
    Object.defineProperty(window, 'location', {
      value: { ...window.location, reload },
      writable: true,
    })
    render(
      <ErrorBoundary onError={onError}>
        <Boom />
      </ErrorBoundary>,
    )
    expect(screen.getByRole('alert')).toHaveTextContent('Algo salió mal')
    expect(onError).toHaveBeenCalledWith(
      expect.objectContaining({ message: 'fallo de prueba' }),
      expect.anything(),
    )
    await userEvent.click(screen.getByRole('button', { name: 'Recargar' }))
    expect(reload).toHaveBeenCalled()
  })

  it('sin errores renderiza a los hijos tal cual', () => {
    render(
      <ErrorBoundary>
        <p>contenido</p>
      </ErrorBoundary>,
    )
    expect(screen.getByText('contenido')).toBeInTheDocument()
  })
})

describe('useOnline', () => {
  it('sigue los eventos online/offline del navegador', () => {
    const { result } = renderHook(() => useOnline())
    expect(result.current).toBe(true)
    vi.spyOn(navigator, 'onLine', 'get').mockReturnValue(false)
    act(() => void window.dispatchEvent(new Event('offline')))
    expect(result.current).toBe(false)
    vi.spyOn(navigator, 'onLine', 'get').mockReturnValue(true)
    act(() => void window.dispatchEvent(new Event('online')))
    expect(result.current).toBe(true)
  })
})
