import { useNavigate } from 'react-router-dom'
import { Button, Card, Empty, PageTitle } from '../design'

/** Dirección que no existe: antes la página quedaba en blanco. */
export function NotFoundPage() {
  const navigate = useNavigate()
  return (
    <>
      <PageTitle title="No encontrada" headline="Esta página *no existe*." />
      <Card>
        <Empty>Puede que el enlace esté mal escrito o que la página se haya movido.</Empty>
        <div style={{ textAlign: 'center' }}>
          <Button variant="primary" icon="home" onClick={() => navigate('/')}>
            Ir al inicio
          </Button>
        </div>
      </Card>
    </>
  )
}
