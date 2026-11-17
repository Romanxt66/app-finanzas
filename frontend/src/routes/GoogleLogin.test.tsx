import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { vi } from 'vitest'
import { AuthProvider } from '../features/auth'
import { LoginPage, RegisterPage } from './AuthPages'

// El script real de Google no carga en las pruebas: un botón falso entrega un ID token al pulsarlo
vi.mock('../lib/google', () => ({
  GOOGLE_CLIENT_ID: 'web-client',
  loadGoogle: () =>
    Promise.resolve({
      initialize: (o: { callback: (r: { credential: string }) => void }) => {
        ;(globalThis as { __gsiCallback?: typeof o.callback }).__gsiCallback = o.callback
      },
      renderButton: (parent: HTMLElement) => {
        const b = document.createElement('button')
        b.type = 'button'
        b.textContent = 'Continuar con Google'
        b.onclick = () =>
          (globalThis as { __gsiCallback?: (r: { credential: string }) => void }).__gsiCallback?.({
            credential: 'google-id-token-123456789',
          })
        parent.appendChild(b)
      },
    }),
}))

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

function setup(route: string) {
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

beforeEach(() => localStorage.clear())
afterEach(() => vi.restoreAllMocks())

test('entra con Google: envía el ID token y llega al panel', async () => {
  const fetchMock = vi
    .spyOn(globalThis, 'fetch')
    .mockImplementation(async (url) =>
      String(url).endsWith('/auth/google')
        ? json(200, { access_token: 'a', refresh_token: 'r', token_type: 'bearer' })
        : json(200, { id: '1', email: 'x@example.com', full_name: 'X' }),
    )
  setup('/login')
  await userEvent.click(await screen.findByRole('button', { name: 'Continuar con Google' }))
  expect(await screen.findByText('Panel')).toBeInTheDocument()
  const call = fetchMock.mock.calls.find(([u]) => String(u).endsWith('/auth/google'))!
  expect(JSON.parse(String((call[1] as RequestInit).body))).toEqual({
    id_token: 'google-id-token-123456789',
  })
})

test('con dos pasos pide el código y reenvía el mismo token', async () => {
  const bodies: unknown[] = []
  vi.spyOn(globalThis, 'fetch').mockImplementation(async (url, init) => {
    if (String(url).endsWith('/auth/google')) {
      const body = JSON.parse(String((init as RequestInit).body))
      bodies.push(body)
      return body.otp
        ? json(200, { access_token: 'a', refresh_token: 'r', token_type: 'bearer' })
        : json(401, { error: { code: 'otp_required', message: 'Escribe el código' } })
    }
    return json(200, { id: '1', email: 'x@example.com', full_name: 'X' })
  })
  setup('/login')
  await userEvent.click(await screen.findByRole('button', { name: 'Continuar con Google' }))
  await userEvent.type(await screen.findByLabelText('Código de verificación'), '123 456')
  await userEvent.click(screen.getByRole('button', { name: 'Entrar con Google' }))
  expect(await screen.findByText('Panel')).toBeInTheDocument()
  expect(bodies.at(-1)).toEqual({ id_token: 'google-id-token-123456789', otp: '123456' })
})

test('en el registro avisa de que continuar con Google acepta los términos', async () => {
  vi.spyOn(globalThis, 'fetch').mockImplementation(async () => json(200, {}))
  setup('/register')
  expect(await screen.findByText(/Al continuar con Google confirmas/)).toBeInTheDocument()
})
