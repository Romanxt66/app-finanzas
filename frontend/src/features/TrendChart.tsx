import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { formatMoney } from '../lib/format'

const compact = (n: number) => new Intl.NumberFormat('es-CO', { notation: 'compact' }).format(n)

export type TrendPoint = { mes: string; Ingresos: number; Gastos: number }

/** Barras de ingresos y gastos de los últimos meses (va en su propio trozo con recharts). */
export default function TrendChart({
  data: chartData,
  currency,
}: {
  data: TrendPoint[]
  currency: string
}) {
  return (
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
  )
}
