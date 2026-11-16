import { screen } from '@testing-library/react'
import { expect, test } from 'vitest'
import { mockApi, renderApp } from '../test-utils'
import { SpendingMoodCard } from './SpendingMoodCard'
import { moodHighlightText } from '../lib/spendingMoods'

const base = {
  currency: 'COP',
  date_from: '2026-08-18',
  date_to: '2026-11-16',
  expenses: 10,
  tagged: 0,
  by_mood: [],
  highlight: null,
}

test('sin gastos con ánimo invita a marcarlos', async () => {
  mockApi({ 'GET /spending-mood': base })
  renderApp(<SpendingMoodCard />)
  expect(await screen.findByText(/elige cómo te sientes/)).toBeInTheDocument()
})

test('con datos destaca el ánimo que más gasta y lista los demás', async () => {
  mockApi({
    'GET /spending-mood': {
      ...base,
      tagged: 4,
      by_mood: [
        { mood: 'stressed', count: 3, total: '90000', average: '30000', share_pct: '75' },
        { mood: 'happy', count: 1, total: '30000', average: '30000', share_pct: '25' },
      ],
      highlight: {
        mood: 'stressed',
        average: '30000',
        baseline: '23000',
        change_pct: '29',
        top_weekday: 5,
      },
    },
  })
  renderApp(<SpendingMoodCard />)
  expect(
    await screen.findByText(
      'Cuando estás estresado gastas un 29 % más por compra, sobre todo los viernes.',
    ),
  ).toBeInTheDocument()
  expect(screen.getByRole('list', { name: 'Gasto por ánimo' })).toHaveTextContent('Feliz')
  expect(screen.getByText(/4 de 10 gastos con ánimo/)).toBeInTheDocument()
})

test('moodHighlightText: sin diferencia notable lo dice', () => {
  expect(moodHighlightText({ mood: 'calm', change_pct: '2', top_weekday: 1 })).toBe(
    'Cuando estás tranquilo gastas lo de siempre por compra. Lo marcas más los lunes.',
  )
})
