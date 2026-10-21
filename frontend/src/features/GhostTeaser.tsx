import { Link } from 'react-router-dom'
import { useGhostSubscriptions } from '../api/hooks'
import { Badge, Card, Icon } from '../design'
import { formatMoney } from '../lib/format'

/** Aviso del resumen: solo aparece si hay cobros sin registrar o alertas que revisar. */
export function GhostTeaser() {
  const { data } = useGhostSubscriptions()
  if (!data) return null
  const ghosts = data.subscriptions.filter((s) => !s.tracked)
  if (ghosts.length === 0 && data.alerts.length === 0) return null
  return (
    <Card title="Suscripciones fantasma">
      <div className="cr-stack">
        {ghosts.length > 0 && (
          <p className="body">
            {ghosts.length === 1
              ? 'Hay 1 cobro recurrente que no registraste'
              : `Hay ${ghosts.length} cobros recurrentes que no registraste`}
            {data.untracked_monthly.length > 0 &&
              `: ≈ ${data.untracked_monthly.map((t) => formatMoney(t.total, t.currency)).join(' + ')} al mes.`}
          </p>
        )}
        {data.alerts.length > 0 && (
          <Badge tone="warning" icon="up">
            {data.alerts.length === 1 ? '1 alerta' : `${data.alerts.length} alertas`}
          </Badge>
        )}
        <Link to="/subscriptions" className="cr-link">
          Revisar <Icon name="arrow" />
        </Link>
      </div>
    </Card>
  )
}
