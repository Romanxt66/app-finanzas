import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Route, Routes } from 'react-router-dom'
import { mockApi, renderApp } from '../test-utils'
import { LegalPage } from './Legal'

const app = (
  <Routes>
    <Route path="/terminos" element={<LegalPage kind="terms" />} />
    <Route path="/privacidad" element={<LegalPage kind="privacy" />} />
  </Routes>
)

describe('Páginas legales', () => {
  it('la privacidad se lee sin sesión, explica Google y cómo borrar la cuenta', async () => {
    mockApi({})
    renderApp(app, { authed: false, route: '/privacidad' })
    expect(await screen.findByRole('heading', { level: 1 })).toHaveTextContent('Tus datos, tuyos.')
    expect(screen.getByText(/Si entras con Google/)).toBeInTheDocument()
    expect(screen.getByText(/uso limitado/)).toBeInTheDocument()
    expect(screen.getAllByText(/Eliminar cuenta/).length).toBeGreaterThan(0)
  })

  it('enlaza de privacidad a términos', async () => {
    mockApi({})
    renderApp(app, { authed: false, route: '/privacidad' })
    await userEvent.click(await screen.findByText('Leer los términos y condiciones'))
    expect(await screen.findByRole('heading', { level: 1 })).toHaveTextContent(
      'Las reglas, claras.',
    )
  })
})
