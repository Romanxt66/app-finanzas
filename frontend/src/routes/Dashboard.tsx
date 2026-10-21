import { useEffect, useState } from 'react'
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { useAccounts, useCategories, useRecurring, useSummary, useTransactions } from '../api/hooks'
import {
  BalanceCard,
  Card,
  Donut,
  Empty,
  Icon,
  Input,
  Segmented,
  StatTile,
  TransactionList,
  TransactionRow,
} from '../design'
import { formatDate, formatMoney, monthLabel, monthStart } from '../lib/format'
import { Link } from 'react-router-dom'

const compact = (n: number) => new Intl.NumberFormat('es-CO', { notation: 'compact' }).format(n)

const HIDE_KEY = 'balance_hidden'

function useHiddenBalance() {
  const [hidden, setHidden] = useState(() => {
    try {
      return localStorage.getItem(HIDE_KEY) === '1'
    } catch {
      return false
    }
  })
  useEffect(() => {
    try {
      localStorage.setItem(HIDE_KEY, hidden ? '1' : '0')
    } catch {
      /* preferencia opcional */
    }
  }, [hidden])
  return [hidden, () => setHidden((h) => !h)] as const
}

/** Variación % frente al mes anterior; null si no hay base de comparación. */
function change(current: number, previous?: number): number | null {
  return previous ? ((current - previous) / previous) * 100 : null
}

/** Guía de primeros pasos: desaparece sola cuando ya hay cuenta, categorías y un movimiento. */
function GettingStarted(props: {
  hasAccounts: boolean
  hasCategories: boolean
  hasTransactions: boolean
  loaded: boolean
}) {
  const steps = [
    {
      to: '/accounts',
      label: 'Crea tu primera cuenta',
      done: props.hasAccounts,
      icon: 'wallet' as const,
    },
    {
      to: '/categories',
      label: 'Define tus categorías',
      done: props.hasCategories,
      icon: 'tag' as const,
    },
    {
      to: '/transactions',
      label: 'Registra tu primer movimiento',
      done: props.hasTransactions,
      icon: 'plus' as const,
    },
  ]
  if (!props.loaded || steps.every((s) => s.done)) return null
  return (
    <Card title="Empieza aquí">
      <ol className="cr-steps" aria-label="Primeros pasos">
        {steps.map((step) => (
          <li key={step.to}>
            <Link to={step.to} data-done={step.done}>
              <span className="cr-chip">
                <Icon name={step.done ? 'check' : step.icon} />
              </span>
              <span className="body">{step.label}</span>
              <span className="cr-sr">{step.done ? ' (hecho)' : ' (pendiente)'}</span>
            </Link>
          </li>
        ))}
      </ol>
      <p className="caption cr-muted" style={{ marginTop: 'var(--space-3)' }}>
        ¿Vienes de otra app? Puedes{' '}
        <Link to="/import" style={{ color: 'var(--mint)' }}>
          importar el CSV de tu banco
        </Link>
        .
      </p>
    </Card>
  )
}

export function DashboardPage() {
  const [month, setMonth] = useState(monthStart())
  const [hidden, toggleHidden] = useHiddenBalance()
  const [chosenCurrency, setChosenCurrency] = useState<string | undefined>()
  const { data: accounts = [] } = useAccounts()
  const { data: allAccounts = [] } = useAccounts(true)
  const { data: categories = [] } = useCategories()
  const { data: summary } = useSummary(month, chosenCurrency)
  const currency = summary?.currency ?? undefined
  const currencies = summary?.currencies ?? []
  const { data: recent } = useTransactions({ limit: 5, offset: 0 })
  const { data: rules } = useRecurring()
  const upcoming = (rules ?? [])
    .filter((r) => r.active)
    .sort((a, b) => a.next_date.localeCompare(b.next_date))
    .slice(0, 3)
  const names = new Map(categories.map((c) => [c.id, c.name]))
  const currencyOf = new Map(allAccounts.map((a) => [a.id, a.currency]))
  // El saldo suma solo las cuentas de la moneda mostrada (no se mezclan monedas)
  const total = accounts
    .filter((a) => !currency || a.currency === currency)
    .reduce((acc, a) => acc + Number(a.balance), 0)

  const trend = summary?.trend ?? []
  const prev = trend.length > 1 ? trend[trend.length - 2] : undefined
  const income = Number(summary?.income ?? 0)
  const expense = Number(summary?.expense ?? 0)
  const chartData = trend.map((m) => ({
    mes: monthLabel(m.month),
    Ingresos: Number(m.income),
    Gastos: Number(m.expense),
  }))
  const savingsRate = income > 0 ? Math.round(((income - expense) / income) * 100) : null
  const expenseTotal = (summary?.expense_by_category ?? []).reduce((a, c) => a + Number(c.total), 0)

  return (
    <>
      <div className="cr-page-head">
        <h1 className="title">Resumen</h1>
        {currencies.length > 1 && (
          <Segmented
            label="Moneda"
            options={currencies.map((c) => ({ value: c, label: c }))}
            value={currency ?? currencies[0]}
            onChange={setChosenCurrency}
          />
        )}
        <div className="cr-month">
          <Input
            label="Mes"
            type="month"
            value={month.slice(0, 7)}
            onChange={(e) => e.target.value && setMonth(`${e.target.value}-01`)}
          />
        </div>
      </div>

      <GettingStarted
        hasAccounts={allAccounts.length > 0}
        hasCategories={categories.length > 0}
        hasTransactions={(recent?.total ?? 0) > 0}
        loaded={!!recent && !!allAccounts}
      />

      <BalanceCard
        label="Saldo total"
        value={total}
        currency={currency}
        note={
          accounts.length
            ? `${accounts.length} cuenta${accounts.length === 1 ? '' : 's'} activa${accounts.length === 1 ? '' : 's'}`
            : undefined
        }
        trend={
          trend.length > 1 ? trend.map((m) => Number(m.income) - Number(m.expense)) : undefined
        }
        trendLabel="Neto de los últimos meses"
        hidden={hidden}
        onToggleHidden={toggleHidden}
      />

      <div className="cr-grid-kpi">
        <StatTile
          label="Ingresos"
          value={income}
          currency={currency}
          delta={change(income, prev && Number(prev.income))}
          icon="salary"
          tone="mint"
        />
        <StatTile
          label="Gastos"
          value={expense}
          currency={currency}
          delta={change(expense, prev && Number(prev.expense))}
          invertDelta
          icon="wallet"
          tone="amber"
        />
        <StatTile
          label="Neto del mes"
          value={income - expense}
          currency={currency}
          icon="chart"
          note={
            savingsRate === null
              ? undefined
              : savingsRate >= 0
                ? `Ahorraste el ${savingsRate} % de tus ingresos`
                : `Gastaste ${Math.abs(savingsRate)} % más de lo que ingresó`
          }
        />
      </div>

      <div className="cr-grid-cols">
        <Card title="Tendencia (6 meses)">
          <div className="cr-chart">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData}>
                <CartesianGrid vertical={false} stroke="var(--hairline)" />
                <XAxis
                  dataKey="mes"
                  tick={{ fill: 'var(--ink-muted)', fontSize: 12 }}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fill: 'var(--ink-muted)', fontSize: 12 }}
                  axisLine={false}
                  tickLine={false}
                  width={44}
                  tickFormatter={(v) => compact(Number(v))}
                />
                <Tooltip
                  cursor={{ fill: 'var(--glass)' }}
                  contentStyle={{
                    background: 'var(--surface-solid)',
                    border: '1px solid var(--glass-border)',
                    borderRadius: 12,
                    color: 'var(--ink)',
                  }}
                  formatter={(v) => formatMoney(Number(v), currency)}
                />
                <Bar dataKey="Ingresos" className="cr-bar-in" radius={[6, 6, 0, 0]} />
                <Bar dataKey="Gastos" className="cr-bar-out" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card title="Gasto por categoría">
          {!summary?.expense_by_category.length ? (
            <Empty>Sin gastos este mes.</Empty>
          ) : (
            <div className="cr-donut-row">
              <Donut
                label={`Distribución del gasto: ${summary.expense_by_category
                  .slice(0, 3)
                  .map(
                    (c) =>
                      `${c.category_id ? names.get(c.category_id) : 'Sin categoría'} ${Math.round(expenseTotal ? (Number(c.total) / expenseTotal) * 100 : 0)} %`,
                  )
                  .join(', ')}`}
                data={summary.expense_by_category.map((c) => ({
                  key: c.category_id ?? 'none',
                  value: Number(c.total),
                }))}
              />
              <ul
                style={{ listStyle: 'none', margin: 0, padding: 0 }}
                aria-label="Gasto por categoría"
              >
                {summary.expense_by_category.map((c, i) => {
                  const pct = expenseTotal ? (Number(c.total) / expenseTotal) * 100 : 0
                  return (
                    <li key={c.category_id ?? 'none'} className="cr-cat-row">
                      <div className="cr-row-split" style={{ padding: 0 }}>
                        <span className="body">
                          <span
                            className="cr-dot"
                            aria-hidden="true"
                            style={{
                              background: [
                                'var(--mint)',
                                'var(--amber)',
                                'var(--negative)',
                                'var(--ink-muted)',
                              ][i % 4],
                              opacity: i < 4 ? 1 : 0.55,
                            }}
                          />
                          {c.category_id ? names.get(c.category_id) : 'Sin categoría'}
                        </span>
                        <span className="amount-sm">
                          {formatMoney(c.total, currency)}{' '}
                          <span className="caption cr-muted">{Math.round(pct)} %</span>
                        </span>
                      </div>
                    </li>
                  )
                })}
              </ul>
            </div>
          )}
        </Card>
      </div>

      {upcoming.length > 0 && (
        <section aria-labelledby="proximos">
          <div className="cr-card-title">
            <h2 id="proximos" className="heading">
              Próximos recurrentes
            </h2>
          </div>
          <TransactionList label="Próximos recurrentes">
            {upcoming.map((r) => (
              <TransactionRow
                key={r.id}
                kind={r.type}
                title={r.description || (r.category_id && names.get(r.category_id)) || 'Recurrente'}
                detail={`${formatDate(r.next_date)} · ${{ weekly: 'cada semana', monthly: 'cada mes', yearly: 'cada año' }[r.frequency]}`}
                amount={Number(r.amount)}
                currency={currencyOf.get(r.account_id)}
              />
            ))}
          </TransactionList>
        </section>
      )}

      <section aria-labelledby="recientes">
        <div className="cr-card-title">
          <h2 id="recientes" className="heading">
            Movimientos recientes
          </h2>
        </div>
        {!recent?.items.length ? (
          <Card>
            <Empty>Aún no hay movimientos.</Empty>
          </Card>
        ) : (
          <TransactionList label="Movimientos recientes">
            {recent.items.map((t) => (
              <TransactionRow
                key={t.id}
                kind={t.type}
                title={
                  t.description ||
                  (t.category_id && names.get(t.category_id)) ||
                  ({ income: 'Ingreso', expense: 'Gasto', transfer: 'Transferencia' } as const)[
                    t.type
                  ]
                }
                detail={formatDate(t.occurred_on)}
                amount={Number(t.amount)}
                currency={currencyOf.get(t.account_id)}
              />
            ))}
          </TransactionList>
        )}
      </section>
    </>
  )
}
