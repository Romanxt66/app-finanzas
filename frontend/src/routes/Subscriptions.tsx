import { Link } from 'react-router-dom'
import { useGhostSubscriptions } from '../api/hooks'
import { Badge, Card, Empty, ErrorText, Glass, Icon, Skeleton, TransactionList } from '../design'
import { ALERT_ICONS, CADENCE_LABELS, alertText } from '../features/ghostLabels'
import { formatDate, formatMoney } from '../lib/format'

/** Cobros recurrentes detectados en tus gastos, con los que aún no registraste como recurrentes. */
export function SubscriptionsPage() {
  const { data, isLoading, error } = useGhostSubscriptions()
  const ghosts = data?.subscriptions.filter((s) => !s.tracked) ?? []
  const tracked = data?.subscriptions.filter((s) => s.tracked) ?? []

  return (
    <>
      <h1 className="title">Suscripciones</h1>
      <ErrorText error={error} />
      {isLoading ? (
        <Skeleton lines={3} height={72} />
      ) : !data?.subscriptions.length && !data?.alerts.length ? (
        <Card>
          <Empty>
            Aún no detectamos cobros recurrentes. Con unos meses de gastos registrados, aparecerán
            aquí.
          </Empty>
        </Card>
      ) : (
        <>
          {data.alerts.length > 0 && (
            <section aria-labelledby="alertas">
              <div className="cr-card-title">
                <h2 id="alertas" className="heading">
                  Alertas
                </h2>
              </div>
              <Glass size="md" as="ul" className="cr-more" aria-label="Alertas">
                {data.alerts.map((a, i) => (
                  <li key={`${a.kind}-${a.name}-${a.date}-${i}`}>
                    <div className="cr-alert">
                      <span className="cr-chip cr-chip-amber">
                        <Icon name={ALERT_ICONS[a.kind]} />
                      </span>
                      <div>
                        <p className="body">{alertText(a)}</p>
                        <p className="caption cr-muted">{formatDate(a.date)}</p>
                      </div>
                    </div>
                  </li>
                ))}
              </Glass>
            </section>
          )}

          <section aria-labelledby="fantasma">
            <div className="cr-card-title">
              <h2 id="fantasma" className="heading">
                Sin registrar
              </h2>
              {data.untracked_monthly.length > 0 && (
                <span className="label cr-muted">
                  ≈{' '}
                  {data.untracked_monthly.map((t) => formatMoney(t.total, t.currency)).join(' + ')}{' '}
                  al mes
                </span>
              )}
            </div>
            {ghosts.length === 0 ? (
              <Card>
                <Empty>No hay cobros fantasma. Todo lo recurrente ya está registrado.</Empty>
              </Card>
            ) : (
              <SubscriptionList items={ghosts} label="Cobros sin registrar" />
            )}
            {ghosts.length > 0 && (
              <p className="caption cr-muted cr-hint">
                Regístralos en <Link to="/recurring">Recurrentes</Link> para que cuenten en tu
                «Disponible hoy» y te avisemos de sus cambios.
              </p>
            )}
          </section>

          {tracked.length > 0 && (
            <section aria-labelledby="registradas">
              <div className="cr-card-title">
                <h2 id="registradas" className="heading">
                  Ya registradas
                </h2>
              </div>
              <SubscriptionList items={tracked} label="Cobros ya registrados" />
            </section>
          )}
        </>
      )}
    </>
  )
}

function SubscriptionList({
  items,
  label,
}: {
  items: NonNullable<ReturnType<typeof useGhostSubscriptions>['data']>['subscriptions']
  label: string
}) {
  return (
    <TransactionList label={label}>
      {items.map((s) => (
        <div key={`${s.name}-${s.currency}`} className="cr-txn" role="listitem">
          <span className="cr-chip cr-chip-brand">
            <Icon name="swap" />
          </span>
          <div className="cr-txn-main">
            <div className="body cr-txn-title">{s.name}</div>
            <div className="caption cr-muted">
              {CADENCE_LABELS[s.cadence]} · próximo ≈ {formatDate(s.next_expected)}
            </div>
          </div>
          <div className="cr-sub-amt">
            <div className="amount-sm">{formatMoney(s.last_amount, s.currency)}</div>
            <div className="caption cr-muted">≈ {formatMoney(s.monthly_cost, s.currency)}/mes</div>
          </div>
          <Badge tone={s.tracked ? 'positive' : 'warning'}>
            {s.tracked ? 'Registrada' : 'Sin registrar'}
          </Badge>
        </div>
      ))}
    </TransactionList>
  )
}
