import type { Summary } from '../api/hooks'

export type PeriodReport = {
  income: number
  expense: number
  net: number
  currency: string | null
  byCategory: { categoryId: string | null; total: number }[]
  trend: { month: string; income: number; expense: number }[]
}

/** Suma los resúmenes mensuales del periodo (el más reciente primero). El gráfico muestra al menos 3 meses. */
export function combinePeriod(summaries: Summary[], months: number): PeriodReport {
  const byCat = new Map<string | null, number>()
  let income = 0
  let expense = 0
  for (const s of summaries) {
    income += Number(s.income)
    expense += Number(s.expense)
    for (const c of s.expense_by_category) {
      const id = c.category_id ?? null
      byCat.set(id, (byCat.get(id) ?? 0) + Number(c.total))
    }
  }
  const trend = (summaries[0]?.trend ?? []).map((t) => ({
    month: t.month,
    income: Number(t.income),
    expense: Number(t.expense),
  }))
  const keep = Math.max(months, 3)
  return {
    income,
    expense,
    net: income - expense,
    currency: summaries[0]?.currency ?? null,
    byCategory: [...byCat.entries()]
      .map(([categoryId, total]) => ({ categoryId, total }))
      .sort((a, b) => b.total - a.total),
    trend: trend.length > keep ? trend.slice(trend.length - keep) : trend,
  }
}

/** Primer día de cada uno de los últimos `count` meses, empezando por el actual. */
export function lastMonths(count: number, now = new Date()): string[] {
  return Array.from({ length: count }, (_, i) => {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`
  })
}
