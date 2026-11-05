import { useEffect } from 'react'
import { Link } from 'react-router-dom'
import { Backdrop, Glass } from '../design'
import { LEGAL_VERSION, privacy, terms } from '../lib/legal'

/** Términos y política de privacidad: públicos, sin iniciar sesión (los enlaza Google y el registro). */
export function LegalPage({ kind }: { kind: 'terms' | 'privacy' }) {
  const doc = kind === 'terms' ? terms() : privacy()
  const other =
    kind === 'terms'
      ? { to: '/privacidad', label: 'Leer la política de privacidad' }
      : { to: '/terminos', label: 'Leer los términos y condiciones' }
  useEffect(() => {
    document.title = `${doc.title} · Alvea`
    window.scrollTo(0, 0)
  }, [doc.title])
  return (
    <Backdrop>
      <main className="cr-legal">
        <Link to="/" className="cr-legal-back">
          ← Volver
        </Link>
        <p className="cr-legal-tag">{doc.title.toLowerCase()}</p>
        <h1 className="cr-legal-title">
          {doc.headline[0]}
          <em>{doc.headline[1]}</em>.
        </h1>
        <p className="cr-legal-lead">{doc.lead}</p>
        {doc.sections.map((s) => (
          <Glass as="section" padded key={s.title} className="cr-legal-section">
            <h2>{s.title}</h2>
            {s.paragraphs.map((p) => (
              <p key={p.slice(0, 40)}>{p}</p>
            ))}
          </Glass>
        ))}
        <p className="cr-legal-version">versión vigente: {LEGAL_VERSION}</p>
        <Link to={other.to} className="cr-legal-other">
          {other.label}
        </Link>
      </main>
    </Backdrop>
  )
}
