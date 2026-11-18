import { useEffect, useRef, useState } from 'react'
import { GOOGLE_CLIENT_ID, loadGoogle, resetGoogle } from '../lib/google'

/** La «G» de Google con sus cuatro colores oficiales (la exige su guía de marca). */
export function GoogleG({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" aria-hidden="true" focusable="false">
      <path
        fill="#EA4335"
        d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"
      />
      <path
        fill="#4285F4"
        d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"
      />
      <path
        fill="#FBBC05"
        d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"
      />
      <path
        fill="#34A853"
        d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"
      />
    </svg>
  )
}

const LABELS = {
  continue_with: 'Continuar con Google',
  signup_with: 'Registrarse con Google',
  signin_with: 'Iniciar sesión con Google',
} as const

/**
 * «Continuar con Google» con el aspecto de la app: se pinta al instante con nuestro estilo y, encima,
 * va invisible el botón oficial de Google (un iframe que solo él puede crear y que es el que abre la
 * ventana de cuentas). Así nunca «parpadea» ni aparece a medias aunque el script de Google tarde.
 * Si el script no carga (sin conexión, bloqueadores), al pulsar se explica y se reintenta.
 */
export function GoogleButton({
  onCredential,
  text = 'continue_with',
}: {
  onCredential: (idToken: string) => void
  text?: keyof typeof LABELS
}) {
  const wrap = useRef<HTMLDivElement>(null)
  const hit = useRef<HTMLDivElement>(null)
  const callback = useRef(onCredential)
  callback.current = onCredential
  const [state, setState] = useState<'loading' | 'ready' | 'failed'>('loading')
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    let alive = true
    let observer: ResizeObserver | undefined
    let check: ReturnType<typeof setInterval> | undefined
    loadGoogle()
      .then((gsi) => {
        if (!alive || !hit.current || !wrap.current) return
        gsi.initialize({
          client_id: GOOGLE_CLIENT_ID,
          callback: (r) => callback.current(r.credential),
          ux_mode: 'popup',
          cancel_on_tap_outside: true,
        })
        // El botón oficial mide como mucho 400 px: se vuelve a crear si cambia el ancho disponible
        let width = 0
        const render = () => {
          if (!hit.current || !wrap.current) return
          const next = Math.round(Math.min(400, Math.max(200, wrap.current.clientWidth)))
          if (next === width) return
          width = next
          hit.current.replaceChildren()
          gsi.renderButton(hit.current, {
            type: 'standard',
            theme: 'outline',
            size: 'large',
            shape: 'pill',
            text,
            locale: 'es',
            width: next,
          })
        }
        render()
        observer = typeof ResizeObserver === 'undefined' ? undefined : new ResizeObserver(render)
        observer?.observe(wrap.current)
        // Solo vale cuando el iframe de Google se ha dibujado de verdad (si Google lo rechaza, p. ej.
        // por un origen no autorizado, se queda en 0 × 0 y el clic no haría nada)
        const started = Date.now()
        check = setInterval(() => {
          const frame = hit.current?.querySelector('iframe')
          if (frame && frame.offsetWidth > 0 && frame.offsetHeight > 0) {
            clearInterval(check)
            if (alive) setState('ready')
          } else if (Date.now() - started > 10_000) {
            clearInterval(check)
            if (alive) setState('failed')
          }
        }, 200)
      })
      .catch(() => alive && setState('failed'))
    return () => {
      alive = false
      observer?.disconnect()
      clearInterval(check)
    }
  }, [text, attempt])

  const label = LABELS[text]
  return (
    <div ref={wrap} className="cr-google" data-state={state}>
      <button
        type="button"
        className="cr-google-btn"
        // Con el script listo, el que recibe el clic y el foco es el botón oficial de encima
        tabIndex={state === 'ready' ? -1 : 0}
        aria-hidden={state === 'ready' || undefined}
        aria-busy={state === 'loading' || undefined}
        onClick={() => {
          if (state !== 'failed') return
          resetGoogle()
          setState('loading')
          setAttempt((n) => n + 1)
        }}
      >
        <span className="cr-google-g">
          <GoogleG />
        </span>
        <span>{label}</span>
      </button>
      <div ref={hit} className="cr-google-hit" title={label} />
      {state === 'failed' && (
        <p className="caption cr-muted cr-google-note" role="status">
          No se pudo cargar Google. Revisa tu conexión o el bloqueador de anuncios y pulsa otra vez.
        </p>
      )}
    </div>
  )
}
