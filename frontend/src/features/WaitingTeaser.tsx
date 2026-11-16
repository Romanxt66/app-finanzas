import { Link } from 'react-router-dom'
import { useWaitingRoom } from '../api/hooks'
import { Badge, Card, Icon } from '../design'
import { formatMoney } from '../lib/format'

/** Aviso del resumen sobre la sala de espera: lo listo para decidir, lo que espera o una invitación. */
export function WaitingTeaser() {
  const { data } = useWaitingRoom()
  if (!data) return null
  const plural = (n: number) => (n === 1 ? '' : 's')
  const line =
    data.ready > 0
      ? `${data.ready} compra${plural(data.ready)} lista${plural(data.ready)} para decidir`
      : data.waiting > 0
        ? `${data.waiting} compra${plural(data.waiting)} esperando`
        : '¿Te tienta algo? Déjalo unos días en espera antes de comprarlo.'
  const saved = data.not_spent.map((t) => formatMoney(t.total, t.currency)).join(' · ')
  return (
    <Card title="Sala de espera">
      <div className="cr-stack">
        <p className="body">{line}</p>
        {saved && <Badge tone="positive">no gastaste {saved}</Badge>}
        <Link to="/waiting" className="cr-link">
          {data.waiting > 0 ? 'Ver' : 'Probar'} <Icon name="arrow" />
        </Link>
      </div>
    </Card>
  )
}
