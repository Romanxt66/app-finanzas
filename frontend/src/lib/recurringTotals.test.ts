import { expect, test } from 'vitest'
import { monthlyEquivalent, recurringTotals } from './recurringTotals'

const rule = (over: Partial<Parameters<typeof recurringTotals>[0][number]> = {}) => ({
  type: 'expense',
  amount: '100',
  frequency: 'monthly',
  active: true,
  end_date: null,
  account_id: 'a',
  ...over,
})

test('pasa cada frecuencia a su equivalente mensual', () => {
  expect(monthlyEquivalent(120, 'yearly')).toBe(10)
  expect(monthlyEquivalent(12, 'weekly')).toBe(52)
  expect(monthlyEquivalent(50, 'monthly')).toBe(50)
})

test('suma solo lo activo, vigente, de la moneda y que no sea transferencia', () => {
  const currency = (id: string) => (id === 'usd' ? 'USD' : 'COP')
  const t = recurringTotals(
    [
      rule(),
      rule({ type: 'income', amount: '3000' }),
      rule({ frequency: 'yearly', amount: '1200' }),
      rule({ active: false }),
      rule({ end_date: '2026-01-01' }),
      rule({ account_id: 'usd' }),
      rule({ type: 'transfer' }),
    ],
    currency,
    'COP',
    '2026-11-16',
  )
  expect(t).toEqual({ expense: 200, income: 3000, count: 3 })
})
