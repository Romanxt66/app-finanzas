import { useSpendingMood } from '../api/hooks'
import { Card, Skeleton } from '../design'
import { formatMoney } from '../lib/format'
import { moodHighlightText, SPENDING_MOODS } from '../lib/spendingMoods'
import { Alvi } from './Alvi'

/** En qué ánimo gastas más (últimos 90 días), como en la app. */
export function SpendingMoodCard() {
  const { data: r, isLoading } = useSpendingMood()
  if (isLoading) return <Skeleton lines={1} height={160} />
  if (!r) return null
  return (
    <Card title="Ánimo del gasto" action={<span className="label cr-muted">90 días</span>}>
      {r.tagged === 0 ? (
        <div className="cr-row">
          <Alvi face={SPENDING_MOODS.calm.face} size={44} />
          <p className="body cr-muted" style={{ margin: 0 }}>
            Al registrar un gasto, elige cómo te sientes. Con unos cuantos, verás en qué ánimo
            gastas más.
          </p>
        </div>
      ) : (
        <div className="cr-stack">
          {r.highlight && (
            <div className="cr-row">
              <Alvi face={SPENDING_MOODS[r.highlight.mood].face} size={48} />
              <p className="body" style={{ margin: 0 }}>
                {moodHighlightText(r.highlight)}
              </p>
            </div>
          )}
          <ul className="cr-plain-list cr-stack" aria-label="Gasto por ánimo">
            {r.by_mood.map((m) => (
              <li key={m.mood} className="cr-mood-row">
                <span className="body">{SPENDING_MOODS[m.mood]?.label ?? m.mood}</span>
                <span
                  className="cr-track"
                  role="progressbar"
                  aria-valuemin={0}
                  aria-valuemax={100}
                  aria-valuenow={Math.round(Number(m.share_pct))}
                  aria-label={`Parte del gasto con ánimo ${SPENDING_MOODS[m.mood]?.label ?? m.mood}`}
                >
                  <span className="cr-fill" style={{ width: `${Number(m.share_pct)}%` }} />
                </span>
                <span className="amount-sm">{formatMoney(m.total, r.currency ?? undefined)}</span>
              </li>
            ))}
          </ul>
          <span className="caption cr-muted">
            {r.tagged} de {r.expenses} gastos con ánimo · media por compra según cómo te sentías
          </span>
        </div>
      )}
    </Card>
  )
}
