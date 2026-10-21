import { useState } from 'react'
import {
  Bar,
  BarChart,
  CartesianGrid,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { useAccounts, useCategories, useSummary, useTransactions } from '../api/hooks'
import { Card, Empty } from '../components/ui'
import { formatDate, monthStart } from '../lib/format'
import { money, useDisplayCurrency } from '../lib/useCurrency'

function Stat({ label, value, tone = '' }: { label: string; value: string; tone?: string }) {
  return (
    <Card>
      <p className="text-sm text-slate-500">{label}</p>
      <p className={`mt-1 text-2xl font-bold tabular-nums ${tone}`}>{value}</p>
    </Card>
  )
}

export function DashboardPage() {
  const [month, setMonth] = useState(monthStart())
  const currency = useDisplayCurrency()
  const { data: accounts = [] } = useAccounts()
  const { data: categories = [] } = useCategories()
  const { data: summary } = useSummary(month)
  const { data: recent } = useTransactions({ limit: 5, offset: 0 })
  const names = new Map(categories.map((c) => [c.id, c.name]))
  const total = accounts.reduce((acc, a) => acc + Number(a.balance), 0)

  const trend = summary?.trend.map((m) => ({
    mes: new Intl.DateTimeFormat(undefined, { month: 'short' }).format(
      new Date(`${m.month}T00:00:00`),
    ),
    Ingresos: Number(m.income),
    Gastos: Number(m.expense),
  }))

  return (
    <>
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold">Resumen</h1>
        <input
          type="month"
          aria-label="Mes"
          className="rounded-md border border-slate-300 px-3 py-2 text-sm"
          value={month.slice(0, 7)}
          onChange={(e) => e.target.value && setMonth(`${e.target.value}-01`)}
        />
      </div>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Stat label="Balance total" value={money(total, currency)} />
        <Stat
          label="Ingresos"
          value={money(summary?.income ?? 0, currency)}
          tone="text-emerald-700"
        />
        <Stat label="Gastos" value={money(summary?.expense ?? 0, currency)} tone="text-red-600" />
        <Stat label="Neto del mes" value={money(summary?.net ?? 0, currency)} />
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <Card title="Tendencia (6 meses)">
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={trend}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="mes" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Bar dataKey="Ingresos" fill="#059669" />
                <Bar dataKey="Gastos" fill="#dc2626" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>
        <Card title="Gasto por categoría">
          {!summary?.expense_by_category.length ? (
            <Empty>Sin gastos este mes.</Empty>
          ) : (
            <ul className="space-y-2">
              {summary.expense_by_category.map((c) => (
                <li key={c.category_id ?? 'none'} className="flex justify-between text-sm">
                  <span>{c.category_id ? names.get(c.category_id) : 'Sin categoría'}</span>
                  <span className="tabular-nums">{money(c.total, currency)}</span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
      <Card title="Últimas transacciones">
        {!recent?.items.length ? (
          <Empty>Aún no hay movimientos.</Empty>
        ) : (
          <ul className="divide-y divide-slate-100">
            {recent.items.map((t) => (
              <li key={t.id} className="flex justify-between py-2 text-sm">
                <span>
                  {t.description || (t.category_id && names.get(t.category_id)) || t.type} ·{' '}
                  <span className="text-slate-500">{formatDate(t.occurred_on)}</span>
                </span>
                <span className="tabular-nums">{money(t.amount, currency)}</span>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </>
  )
}
