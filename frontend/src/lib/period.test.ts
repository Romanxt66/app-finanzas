import type { Summary } from '../api/hooks'
import { combinePeriod, lastMonths } from './period'

const summary = (month: string, income: number, expense: number, cats: [string | null, number][]) =>
  ({
    month,
    currency: 'COP',
    currencies: ['COP'],
    income: String(income),
    expense: String(expense),
    expense_by_category: cats.map(([category_id, total]) => ({
      category_id,
      total: String(total),
    })),
    trend: [1, 2, 3, 4, 5, 6].map((i) => ({
      month: `2026-0${i}-01`,
      income: String(i * 10),
      expense: String(i),
    })),
  }) as unknown as Summary

describe('periodos', () => {
  it('suma los meses y ordena el gasto por categoría', () => {
    const r = combinePeriod(
      [
        summary('2026-06-01', 100, 40, [
          ['a', 30],
          ['b', 10],
        ]),
        summary('2026-05-01', 50, 30, [
          ['b', 25],
          [null, 5],
        ]),
      ],
      3,
    )
    expect(r.net).toBe(80)
    expect(r.byCategory[0]).toEqual({ categoryId: 'b', total: 35 })
    expect(r.trend).toHaveLength(3)
    expect(r.trend.at(-1)?.month).toBe('2026-06-01')
  })

  it('lista los últimos meses empezando por el actual', () => {
    expect(lastMonths(3, new Date(2026, 0, 15))).toEqual(['2026-01-01', '2025-12-01', '2025-11-01'])
  })
})
