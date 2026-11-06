import { Link } from 'react-router-dom'
import { Button, Glass, Icon, type IconName, PageTitle } from '../design'
import { useAuth } from '../features/authContext'

const LINKS: { to: string; label: string; icon: IconName }[] = [
  { to: '/analytics', label: 'Análisis', icon: 'chart' },
  { to: '/budgets', label: 'Presupuestos', icon: 'target' },
  { to: '/recurring', label: 'Recurrentes', icon: 'swap' },
  { to: '/subscriptions', label: 'Suscripciones', icon: 'search' },
  { to: '/import', label: 'Importar CSV', icon: 'download' },
  { to: '/categories', label: 'Categorías', icon: 'tag' },
  { to: '/profile', label: 'Perfil y ajustes', icon: 'user' },
]

const LEGAL: { to: string; label: string; icon: IconName }[] = [
  { to: '/terminos', label: 'Términos y condiciones', icon: 'list' },
  { to: '/privacidad', label: 'Política de privacidad', icon: 'shield' },
]

/** Destinos que no caben en la barra de pestañas del móvil. */
export function MorePage() {
  const { logout } = useAuth()
  return (
    <>
      <PageTitle title="Más" headline="Todo lo *demás*." />
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
      <h2 className="heading">Legal y ayuda</h2>
      <Glass size="md" as="ul" className="cr-more">
        {LEGAL.map((l) => (
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
      <p className="caption cr-muted">alvea · hecho en Colombia</p>
      <div>
        <Button variant="ghost" icon="logout" onClick={logout}>
          Cerrar sesión
        </Button>
      </div>
    </>
  )
}
