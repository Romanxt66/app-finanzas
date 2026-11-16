import { usePersonalInflation } from '../api/hooks'
import { Badge, Card, Delta, Empty, Skeleton } from '../design'
import { formatMoney } from '../lib/format'

const pct = (n: number) =>
  `${n > 0 ? '+' : n < 0 ? '−' : ''}${Math.abs(n).toLocaleString('es-CO', { maximumFractionDigits: 1 })} %`

/** Cuánto se encareció lo que compras de verdad: mismos comercios, ahora frente a meses atrás (como en la app). */
export function PersonalInflationCard() {
  const { data: r, isLoading } = usePersonalInflation()
  if (isLoading) return <Skeleton lines={1} height={160} />
  if (!r) return null
  const index = r.index_pct == null ? null : Number(r.index_pct)
  if (index == null) {
    return (
      <Card title="Tu inflación personal">
        <Empty>
          Cuando tengas gastos en los mismos comercios hace unos meses y ahora, verás cuánto se
          encareció tu vida.
        </Empty>
      </Card>
    )
  }
  const up = index > 0.05
  const down = index < -0.05
  const since = r.comparison === 'year' ? 'hace un año' : 'hace seis meses'
  return (
    <Card title="Tu inflación personal" action={<span className="label cr-muted">vs {since}</span>}>
      <div className="cr-stack">
        <p className="amount" style={{ margin: 0 }}>
          {pct(index)}{' '}
          <span className="label cr-muted">
            {up
              ? 'tu vida está más cara'
              : down
                ? 'tu vida está más barata'
                : 'tus precios no se movieron'}
          </span>
        </p>
        <p className="caption cr-muted" style={{ margin: 0 }}>
          Precio medio por compra en los mismos {r.matched} comercios, ponderado por lo que gastas
          en cada uno (cubre el {Math.round(Number(r.coverage_pct))} % de tu gasto reciente).
        </p>
        {r.categories.length > 1 && (
          <div className="cr-row" style={{ flexWrap: 'wrap' }}>
            {r.categories.slice(0, 6).map((c) => {
              const ch = Number(c.change_pct)
              return (
                <Badge
                  key={c.category ?? '-'}
                  tone={ch > 0.05 ? 'negative' : ch < -0.05 ? 'positive' : 'neutral'}
                >
                  {`${c.category ?? 'Sin categoría'} ${pct(ch)}`}
                </Badge>
              )
            })}
          </div>
        )}
        <ul className="cr-plain-list cr-stack" aria-label="Comercios comparados">
          {r.items.slice(0, 5).map((it) => (
            <li key={it.merchant} className="cr-row-split">
              <span>
                <span className="body">{it.merchant}</span>
                <span className="caption cr-muted cr-block">
                  {formatMoney(it.base_price, r.currency ?? undefined)} →{' '}
                  {formatMoney(it.current_price, r.currency ?? undefined)} por compra
                </span>
              </span>
              <Delta value={Number(it.change_pct)} invert />
            </li>
          ))}
        </ul>
      </div>
    </Card>
  )
}
