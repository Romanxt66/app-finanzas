import { screen, waitFor, within } from '@testing-library/react'
import { afterEach, expect, test, vi } from 'vitest'
import { account, category, mockApi, page, renderApp, transaction } from '../test-utils'
import { AnalyticsPage } from './Analytics'

afterEach(() => vi.restoreAllMocks())

const summary = {
  month: '2026-11-01',
  currency: 'EUR',
  income: '0',
  expense: '930',
  net: '-930',
  expense_by_category: [],
  trend: [],
}

test('«Mayores gastos» pide los gastos del periodo ordenados por importe', async () => {
  const calls = mockApi({
    'GET /accounts': [account()],
    'GET /categories': [category()],
    'GET /reports/summary': summary,
    'GET /transactions': page([
      transaction({ id: 't1', description: 'Arriendo', amount: '900' }),
      transaction({ id: 't2', description: 'Café', amount: '30' }),
    ]),
  })
  renderApp(<AnalyticsPage />)
  const list = await screen.findByRole('list', { name: 'Mayores gastos del periodo' })
  expect(within(list).getByText('Arriendo')).toBeInTheDocument()
  await waitFor(() => expect(calls.some((c) => c.path === '/transactions')).toBe(true))
  const q = calls.find((c) => c.path === '/transactions')!.query
  expect(q.get('order')).toBe('amount')
  expect(q.get('type')).toBe('expense')
  expect(q.get('limit')).toBe('5')
  expect(q.get('date_from')).toMatch(/^\d{4}-\d{2}-01$/)
})
