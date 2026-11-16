import { screen } from '@testing-library/react'
import { expect, test } from 'vitest'
import { mockApi, renderApp } from '../test-utils'
import { WaitingTeaser } from './WaitingTeaser'

const room = (over = {}) => ({
  items: [],
  waiting: 0,
  ready: 0,
  skipped: 0,
  bought: 0,
  not_spent: [],
  ...over,
})

test('avisa de lo que ya se puede decidir y de lo que no se gastó', async () => {
  mockApi({
    'GET /waiting-room': room({
      waiting: 2,
      ready: 1,
      not_spent: [{ currency: 'COP', total: '50000.00' }],
    }),
  })
  renderApp(<WaitingTeaser />)
  expect(await screen.findByText('1 compra lista para decidir')).toBeInTheDocument()
  expect(screen.getByText(/no gastaste/)).toBeInTheDocument()
  expect(screen.getByRole('link', { name: /Ver/ })).toHaveAttribute('href', '/waiting')
})

test('sin nada en espera invita a probarla', async () => {
  mockApi({ 'GET /waiting-room': room() })
  renderApp(<WaitingTeaser />)
  expect(await screen.findByText(/¿Te tienta algo\?/)).toBeInTheDocument()
  expect(screen.getByRole('link', { name: /Probar/ })).toBeInTheDocument()
})
