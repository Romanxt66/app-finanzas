import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { vi } from 'vitest'
import { AuthProvider } from '../features/auth'
import { LoginPage } from './AuthPages'

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

function setup() {
  render(
    <QueryClientProvider
      client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}
    >
      <AuthProvider>
        <MemoryRouter initialEntries={['/login']}>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/" element={<p>Panel</p>} />
          </Routes>
        </MemoryRouter>
      </AuthProvider>
    </QueryClientProvider>,
  )
}

describe('LoginPage', () => {
  beforeEach(() => localStorage.clear())
  afterEach(() => vi.restoreAllMocks())

  it('inicia sesión y navega al panel', async () => {
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (url) =>
      String(url).endsWith('/auth/login')
        ? json(200, { access_token: 'a', refresh_token: 'r', token_type: 'bearer' })
        : json(200, { id: '1', email: 'x@example.com', full_name: 'X' }),
    )
    setup()
    await userEvent.type(screen.getByLabelText('Correo'), 'x@example.com')
    await userEvent.type(screen.getByLabelText('Contraseña'), 'secret123')
    await userEvent.click(screen.getByRole('button', { name: 'Entrar' }))
    expect(await screen.findByText('Panel')).toBeInTheDocument()
  })

  it('muestra el error de credenciales', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      json(401, { error: { code: 'unauthorized', message: 'Credenciales incorrectas' } }),
    )
    setup()
    await userEvent.type(screen.getByLabelText('Correo'), 'x@example.com')
    await userEvent.type(screen.getByLabelText('Contraseña'), 'mala')
    await userEvent.click(screen.getByRole('button', { name: 'Entrar' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Credenciales incorrectas')
  })
})
