import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { vi } from 'vitest'
import { AuthProvider } from '../features/auth'
import { LoginPage, RegisterPage } from './AuthPages'

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

function setup(route = '/login') {
  render(
    <QueryClientProvider
      client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}
    >
      <AuthProvider>
        <MemoryRouter initialEntries={[route]}>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/register" element={<RegisterPage />} />
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

describe('RegisterPage', () => {
  beforeEach(() => localStorage.clear())
  afterEach(() => vi.restoreAllMocks())

  async function fill(password: string) {
    await userEvent.type(screen.getByLabelText('Nombre'), 'Ana')
    await userEvent.type(screen.getByLabelText('Correo'), 'ana@example.com')
    await userEvent.type(screen.getByLabelText('Contraseña'), password)
    await userEvent.click(screen.getByRole('button', { name: 'Crear cuenta' }))
  }

  it.each([
    ['corta1', 'al menos 8 caracteres'],
    ['soloLetrasAqui', 'al menos un número'],
    ['1234567890', 'al menos una letra'],
  ])('contraseña "%s" → dice por qué no vale', async (password, reason) => {
    const fetchMock = vi.spyOn(globalThis, 'fetch')
    setup('/register')
    await fill(password)
    expect(await screen.findByText(new RegExp(`^La contraseña .*${reason}`))).toBeInTheDocument()
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('los requisitos se marcan al escribir', async () => {
    setup('/register')
    const rules = screen.getByRole('list', { name: 'Requisitos de la contraseña' })
    expect(rules.querySelectorAll('[data-ok="true"]')).toHaveLength(0)
    await userEvent.type(screen.getByLabelText('Contraseña'), 'abcdefgh1')
    expect(rules.querySelectorAll('[data-ok="true"]')).toHaveLength(4)
  })

  it('muestra el mensaje del servidor (correo repetido)', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      json(409, { error: { code: 'conflict', message: 'El correo ya está registrado' } }),
    )
    setup('/register')
    await fill('clave-segura-1')
    expect(await screen.findByRole('alert')).toHaveTextContent('El correo ya está registrado')
  })

  it('si el servidor no responde, lo explica', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('', { status: 502 }))
    setup('/register')
    await fill('clave-segura-1')
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'No se pudo conectar con el servidor',
    )
  })
})
