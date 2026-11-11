import { useState } from 'react'
import { Link } from 'react-router-dom'
import { type BudgetPeriod, useBudgetsFor } from '../api/hooks'
import { AnimatedMoney, Glass, Icon, Segmented } from '../design'
import { PERIOD_OPTIONS, periodLabel } from '../lib/budgetPeriod'
import { formatMoney, todayISO } from '../lib/format'
import { useDisplayCurrency } from '../lib/useCurrency'

const KEY = 'home_budget_period'
const WORD: Record<BudgetPeriod, string> = { day: 'hoy', week: 'esta semana', month: 'este mes' }

function stored(): BudgetPeriod {
  try {
    const v = localStorage.getItem(KEY)
    return v === 'day' || v === 'week' || v === 'month' ? v : 'month'
  } catch {
    return 'month'
  }
}

/**
 * Presupuesto en el inicio: eliges si ver el de hoy, el de la semana o el del mes (se recuerda).
 * Si hay uno general manda ese; si no, suma los de cada categoría.
 */
export function BudgetHomeCard() {
  const [period, setPeriod] = useState<BudgetPeriod>(stored)
  const today = todayISO()
  const currency = useDisplayCurrency()
  const { data: budgets, isLoading } = useBudgetsFor(period, today)
  const choose = (p: BudgetPeriod) => {
    setPeriod(p)
    try {
      localStorage.setItem(KEY, p)
    } catch {
      /* preferencia opcional */
    }
  }
  const list = budgets ?? []
  const general = list.find((b) => b.category_id === null)
  const shown = general ? [general] : list
  const limit = shown.reduce((t, b) => t + Number(b.amount), 0)
  const spent = shown.reduce((t, b) => t + Number(b.spent), 0)
  const ratio = limit ? spent / limit : 0
  const state = ratio > 1 ? 'is-over' : ratio >= 0.8 ? 'is-warn' : ''
  const left = limit - spent

  return (
    <Glass as="section" padded className={`cr-budget-home ${state}`} aria-label="Presupuesto">
      <div className="cr-budget-home-head">
        <h2 className="heading">Presupuesto</h2>
        <Segmented<BudgetPeriod>
          label="Ver presupuesto de"
          options={PERIOD_OPTIONS.map((o) => ({
            value: o.value,
            label: o.value === 'day' ? 'Hoy' : o.label,
          }))}
          value={period}
          onChange={choose}
        />
      </div>
      {isLoading && !budgets ? (
        <p className="caption cr-muted">Cargando…</p>
      ) : !limit ? (
        <p className="body cr-muted cr-budget-home-figures">
          Aún no tienes presupuesto para {WORD[period]}.{' '}
          <Link className="cr-text-link" to="/budgets">
            Crear uno
          </Link>
        </p>
      ) : (
        <>
          <div className="cr-budget-home-figures">
            <div>
              <div className="overline">
                {left >= 0 ? `Te queda ${WORD[period]}` : 'Te pasaste'}
              </div>
              <div className="amount-xl">
                <AnimatedMoney value={Math.abs(left)} currency={currency} />
              </div>
            </div>
            <span className="label cr-muted">
              {formatMoney(spent, currency)} de {formatMoney(limit, currency)}
            </span>
          </div>
          <div
            className="cr-track"
            role="progressbar"
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={Math.round(Math.min(ratio, 1) * 100)}
            aria-label={`Presupuesto de ${WORD[period]}`}
          >
            <div className="cr-fill" style={{ width: `${Math.min(ratio, 1) * 100}%` }} />
          </div>
          <div className="cr-budget-home-foot">
            <span className="caption cr-muted">
              {Math.round(ratio * 100)} % · {periodLabel(period, today)}
              {general ? ' · general' : list.length > 1 ? ` · ${list.length} categorías` : ''}
            </span>
            <Link className="cr-link" to="/budgets">
              Ver presupuestos <Icon name="arrow" />
            </Link>
          </div>
        </>
      )}
    </Glass>
  )
}
