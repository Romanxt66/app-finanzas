import { useQueries } from '@tanstack/react-query'
import { useState } from 'react'
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { useAccounts, useCategories, type Summary } from '../api/hooks'
import { api } from '../api/client'
import { Card, ErrorText, Icon, Segmented, Skeleton, StatTile } from '../design'
import { categoryIcon } from '../lib/categoryIcon'
import { formatMoney, monthLabel } from '../lib/format'
import { combinePeriod, lastMonths } from '../lib/period'

type Period = '1' | '3' | '6'
const PERIODS: { value: Period; label: string }[] = [
  { value: '1', label: '1 mes' },
  { value: '3', label: '3 meses' },
  { value: '6', label: '6 meses' },
]

/** Anillo pequeño con el porcentaje en el centro. */
function PercentRing({ fraction }: { fraction: number }) {
  const f = Math.max(0, Math.min(1, fraction))
  const r = 16
  const c = 2 * Math.PI * r
  return (
    <span className="cr-ring" aria-hidden="true">
      <svg viewBox="0 0 40 40" width={42} height={42}>
        <circle cx="20" cy="20" r={r} fill="none" stroke="var(--hairline)" strokeWidth="3.5" />
        <circle
          className="cr-ring-value"
          cx="20"
          cy="20"
          r={r}
          fill="none"
          stroke="var(--brand)"
          strokeWidth="3.5"
          strokeLinecap="round"
          strokeDasharray={`${f * c} ${c}`}
          transform="rotate(-90 20 20)"
        />
      </svg>
      <span className="cr-ring-label">{Math.round(f * 100)}%</span>
    </span>
  )
}

/** Análisis: saldo, balance del periodo (1, 3 o 6 meses), flujo de dinero y gasto por categoría. */
export function AnalyticsPage() {
  const [period, setPeriod] = useState<Period>('1')
  const months = lastMonths(Number(period))
  const results = useQueries({
    queries: months.map((m) => ({
      queryKey: ['summary', m, null],
      queryFn: () => api<Summary>('/reports/summary', { query: { month: m } }),
    })),
  })
  const { data: accounts = [] } = useAccounts()
  const { data: categories = [] } = useCategories()
  const loading = results.some((r) => r.isPending)
  const error = results.find((r) => r.error)?.error
  const summaries = results.map((r) => r.data).filter((s): s is Summary => !!s)
  const report = combinePeriod(summaries, Number(period))
  const currency = report.currency ?? accounts[0]?.currency
  const balance = accounts
    .filter((a) => !currency || a.currency === currency)
    .reduce((t, a) => t + Number(a.balance), 0)
  const names = new Map(categories.map((c) => [c.id, c.name]))
  const rows = report.byCategory.filter((r) => r.total > 0)
  const spent = rows.reduce((t, r) => t + r.total, 0)
  return (
    <>
      <div className="cr-page-head">
        <h1 className="title">Análisis</h1>
      </div>
      <Segmented<Period> label="Periodo" options={PERIODS} value={period} onChange={setPeriod} />
      <ErrorText error={error} />
      {loading && !summaries.length ? (
        <Skeleton lines={3} height={96} />
      ) : (
        <>
          <div className="cr-grid-kpi">
            <StatTile
              label="Saldo"
              value={balance}
              currency={currency ?? undefined}
              icon="wallet"
            />
            <StatTile
              label={period === '1' ? 'Balance del mes' : `Balance de ${period} meses`}
              value={report.net}
              currency={currency ?? undefined}
              icon={report.net >= 0 ? 'up' : 'down'}
              tone={report.net >= 0 ? 'brand' : 'negative'}
              note={`${formatMoney(report.income, currency ?? undefined)} entró · ${formatMoney(report.expense, currency ?? undefined)} salió`}
            />
          </div>
          {report.trend.length >= 2 && (
            <Card title="Flujo de dinero">
              <div className="cr-chart" style={{ height: 220 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={report.trend.map((t) => ({ ...t, label: monthLabel(t.month) }))}>
                    <defs>
                      <linearGradient id="cr-flow" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="var(--chart-1)" stopOpacity={0.35} />
                        <stop offset="100%" stopColor="var(--chart-1)" stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid stroke="var(--hairline)" vertical={false} />
                    <XAxis
                      dataKey="label"
                      tick={{ fill: 'var(--ink-faint)', fontSize: 12 }}
                      axisLine={false}
                      tickLine={false}
                    />
                    <YAxis hide />
                    <Tooltip
                      formatter={(v: number, k: string) => [
                        formatMoney(v, currency ?? undefined),
                        k === 'income' ? 'Ingresos' : 'Gastos',
                      ]}
                      contentStyle={{
                        background: 'var(--surface-solid)',
                        border: '1px solid var(--glass-border)',
                        borderRadius: 12,
                      }}
                    />
                    <Area
                      type="monotone"
                      dataKey="income"
                      stroke="var(--chart-1)"
                      strokeWidth={2.5}
                      fill="url(#cr-flow)"
                    />
                    <Area
                      type="monotone"
                      dataKey="expense"
                      stroke="var(--chart-2)"
                      strokeWidth={2}
                      strokeDasharray="5 4"
                      fill="none"
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
              <p className="caption cr-muted">Línea continua: ingresos · punteada: gastos</p>
            </Card>
          )}
          <Card title="Gasto por categoría">
            {rows.length === 0 ? (
              <p className="cr-muted">Sin gastos en este periodo.</p>
            ) : (
              <ul className="cr-breakdown">
                {rows.map((r) => {
                  const name = r.categoryId
                    ? (names.get(r.categoryId) ?? 'Sin categoría')
                    : 'Sin categoría'
                  return (
                    <li
                      key={r.categoryId ?? 'none'}
                      aria-label={`${name}: ${formatMoney(r.total, currency ?? undefined)}, ${Math.round((r.total / spent) * 100)} % del gasto`}
                    >
                      <PercentRing fraction={r.total / spent} />
                      <span className="cr-glyph" aria-hidden="true">
                        <Icon name={categoryIcon(name)} />
                      </span>
                      <span className="body cr-breakdown-name">{name}</span>
                      <span className="cr-breakdown-amount">
                        {formatMoney(-r.total, currency ?? undefined)}
                      </span>
                    </li>
                  )
                })}
              </ul>
            )}
          </Card>
        </>
      )}
    </>
  )
}
