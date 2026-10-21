import { useDailyAllowance, type DailyAllowance } from '../api/hooks'
import { AnimatedMoney, Glass, Skeleton } from '../design'
import { formatMoney } from '../lib/format'

const RADIUS = 52
const CIRCUMFERENCE = 2 * Math.PI * RADIUS

const MESSAGES: Record<DailyAllowance['status'], string> = {
  ok: 'Vas dentro de tu ritmo.',
  tight: 'Hoy ya superaste lo que te tocaba.',
  over: 'No queda margen para el resto del mes.',
  no_data: 'Define un presupuesto del mes o registra tus ingresos para calcularlo.',
}

function Gauge({ ratio, danger }: { ratio: number; danger: boolean }) {
  const filled = Math.min(Math.max(ratio, 0), 1)
  return (
    <svg viewBox="0 0 120 120" className="cr-gauge" aria-hidden="true">
      <circle cx="60" cy="60" r={RADIUS} className="cr-gauge-track" />
      <circle
        cx="60"
        cy="60"
        r={RADIUS}
        className={danger ? 'cr-gauge-fill cr-gauge-danger' : 'cr-gauge-fill'}
        style={{ strokeDasharray: CIRCUMFERENCE, strokeDashoffset: CIRCUMFERENCE * (1 - filled) }}
      />
    </svg>
  )
}

/** «Disponible hoy»: lo que queda del mes repartido entre los días que faltan. */
export function DailyAllowanceCard() {
  const { data, isLoading } = useDailyAllowance()
  if (isLoading) return <Skeleton lines={1} height={160} />
  if (!data) return null

  const allowance = Number(data.allowance_today)
  const left = Number(data.left_today)
  const spent = Number(data.spent_today)
  const ratio = allowance > 0 ? spent / allowance : spent > 0 ? 1 : 0
  const danger = data.status === 'tight' || data.status === 'over'
  const basis =
    data.basis === 'budget' ? 'Según tu presupuesto del mes' : 'Según tus ingresos del mes'

  return (
    <Glass strong as="section" aria-labelledby="disponible-hoy" className="cr-allow">
      <div className="cr-allow-gaugebox">
        <Gauge ratio={ratio} danger={danger} />
        <span className="cr-allow-pct label" aria-hidden="true">
          {Math.round(Math.min(ratio, 9.99) * 100)} %
        </span>
      </div>
      <div className="cr-allow-body">
        <h2 id="disponible-hoy" className="label cr-muted">
          Disponible hoy
        </h2>
        <div className={danger ? 'amount-xl cr-neg' : 'amount-xl'}>
          <AnimatedMoney value={left} currency={data.currency} />
        </div>
        <p className="body">{MESSAGES[data.status]}</p>
        {data.status !== 'no_data' && (
          <ul className="cr-allow-facts">
            <li>
              <span className="caption cr-muted">Te tocaban hoy</span>
              <span className="amount-sm">{formatMoney(data.allowance_today, data.currency)}</span>
            </li>
            <li>
              <span className="caption cr-muted">Quedan {data.days_remaining} días</span>
              <span className="amount-sm">
                ≈ {formatMoney(data.average_per_day, data.currency)}/día
              </span>
            </li>
            {Number(data.pending_committed) > 0 && (
              <li>
                <span className="caption cr-muted">Ya comprometido</span>
                <span className="amount-sm">
                  {formatMoney(data.pending_committed, data.currency)}
                </span>
              </li>
            )}
          </ul>
        )}
        {data.status !== 'no_data' && (
          <p className="caption cr-muted">
            {basis}
            {data.pattern_used ? ' · ajustado a tus hábitos por día de la semana' : ''}
          </p>
        )}
      </div>
    </Glass>
  )
}
