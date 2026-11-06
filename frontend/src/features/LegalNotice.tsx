import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Button, Glass } from '../design'
import { LEGAL_VERSION, acceptLegal, acceptedLegal } from '../lib/legal'

/** Aviso (sin bloquear la página) para aceptar la versión vigente de los términos y la privacidad. */
export function LegalNotice() {
  const [accepted, setAccepted] = useState(() => acceptedLegal() === LEGAL_VERSION)
  if (accepted) return null
  return (
    <Glass as="aside" padded className="cr-legal-notice" aria-label="Términos y privacidad">
      <p>
        {acceptedLegal() ? 'Actualizamos los ' : 'Revisa los '}
        <Link to="/terminos">términos</Link> y la{' '}
        <Link to="/privacidad">política de privacidad</Link>. Al seguir usando Alvea los aceptas.
      </p>
      <Button
        variant="primary"
        onClick={() => {
          acceptLegal()
          setAccepted(true)
        }}
      >
        Entendido
      </Button>
    </Glass>
  )
}
