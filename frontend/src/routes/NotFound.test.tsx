import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test } from 'vitest'
import { mockApi, renderApp, user } from '../test-utils'
import { NotFoundPage } from './NotFound'

test('una dirección inexistente explica qué pasó y lleva al inicio', async () => {
  mockApi({ 'GET /auth/me': user })
  renderApp(<NotFoundPage />)
  expect(await screen.findByText(/no existe/)).toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: 'Ir al inicio' }))
})
