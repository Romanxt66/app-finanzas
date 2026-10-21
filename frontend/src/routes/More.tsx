import { Link } from 'react-router-dom'
import { Glass, Icon, type IconName } from '../design'

const LINKS: { to: string; label: string; icon: IconName }[] = [
  { to: '/budgets', label: 'Presupuestos', icon: 'target' },
  { to: '/recurring', label: 'Recurrentes', icon: 'swap' },
  { to: '/subscriptions', label: 'Suscripciones', icon: 'search' },
  { to: '/import', label: 'Importar CSV', icon: 'download' },
  { to: '/categories', label: 'Categorías', icon: 'tag' },
  { to: '/profile', label: 'Perfil y ajustes', icon: 'user' },
]

/** Destinos que no caben en la barra de pestañas del móvil. */
export function MorePage() {
  return (
    <>
      <h1 className="title">Más</h1>
      <Glass size="md" as="ul" className="cr-more">
        {LINKS.map((l) => (
          <li key={l.to}>
            <Link to={l.to}>
              <span className="cr-chip">
                <Icon name={l.icon} />
              </span>
              <span className="body">{l.label}</span>
            </Link>
          </li>
        ))}
      </Glass>
    </>
  )
}
