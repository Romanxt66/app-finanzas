import { screen } from '@testing-library/react'
import { expect, test } from 'vitest'
import { mockApi, renderApp } from '../test-utils'
import { PersonalInflationCard } from './PersonalInflationCard'

const base = {
  currency: 'COP',
  current_from: '2026-08-18',
  current_to: '2026-11-16',
  base_from: null,
  base_to: null,
  coverage_pct: '62.0',
  matched: 0,
  items: [],
  categories: [],
}

test('sin datos comparables explica qué hace falta', async () => {
  mockApi({ 'GET /personal-inflation': { ...base, comparison: null, index_pct: null } })
  renderApp(<PersonalInflationCard />)
  expect(await screen.findByText(/mismos comercios hace unos meses/)).toBeInTheDocument()
})

test('con datos muestra el índice, el periodo y los comercios', async () => {
  mockApi({
    'GET /personal-inflation': {
      ...base,
      comparison: 'year',
      index_pct: '8.4',
      matched: 2,
      items: [
        {
          merchant: 'Éxito',
          category: 'Supermercado',
          base_price: '100000',
          current_price: '110000',
          change_pct: '10.0',
          weight_pct: '60',
        },
      ],
    },
  })
  renderApp(<PersonalInflationCard />)
  expect(await screen.findByText('tu vida está más cara')).toBeInTheDocument()
  expect(screen.getByText('vs hace un año')).toBeInTheDocument()
  expect(screen.getByRole('list', { name: 'Comercios comparados' })).toHaveTextContent('Éxito')
})
