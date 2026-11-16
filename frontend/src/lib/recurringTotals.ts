/** Cuánto suponen al mes los movimientos que se repiten (gastos e ingresos fijos). */

type Rule = {
  type: string
  amount: string
  frequency: string
  active: boolean
  end_date: string | null
  account_id: string
}

/** Veces al mes, de media: una semana es 52/12 ≈ 4,33 veces al mes; un año, 1/12. */
const PER_MONTH: Record<string, number> = { weekly: 52 / 12, monthly: 1, yearly: 1 / 12 }

export function monthlyEquivalent(amount: number, frequency: string): number {
  return amount * (PER_MONTH[frequency] ?? 1)
}

export interface RecurringTotals {
  expense: number
  income: number
  /** Reglas que cuentan (activas, sin terminar, en la moneda pedida). */
  count: number
}

/** Suma al mes de las reglas activas y vigentes cuya cuenta usa `currency` (las transferencias no
 *  cambian lo que tienes, así que no cuentan). */
export function recurringTotals(
  rules: Rule[],
  currencyOf: (accountId: string) => string | undefined,
  currency: string,
  today: string,
): RecurringTotals {
  let expense = 0
  let income = 0
  let count = 0
  for (const r of rules) {
    if (!r.active || (r.end_date && r.end_date < today)) continue
    if (r.type !== 'expense' && r.type !== 'income') continue
    if (currencyOf(r.account_id) !== currency) continue
    const monthly = monthlyEquivalent(Number(r.amount), r.frequency)
    if (r.type === 'expense') expense += monthly
    else income += monthly
    count++
  }
  return { expense, income, count }
}
