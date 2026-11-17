import { useEffect, useRef, useState } from 'react'
import { GOOGLE_CLIENT_ID, loadGoogle } from '../lib/google'

/**
 * Botón oficial de Google («Continuar con Google»). Al elegir la cuenta llama a `onCredential` con el
 * ID token. Si el script de Google no carga (sin conexión, bloqueadores), no se muestra nada: siempre
 * queda el acceso con correo y contraseña.
 */
export function GoogleButton({
  onCredential,
  text = 'continue_with',
}: {
  onCredential: (idToken: string) => void
  text?: 'continue_with' | 'signup_with' | 'signin_with'
}) {
  const box = useRef<HTMLDivElement>(null)
  const callback = useRef(onCredential)
  callback.current = onCredential
  const [failed, setFailed] = useState(false)
  // Tema efectivo: el elegido (data-theme) o, en «automático», el del sistema
  const attr = document.documentElement.getAttribute('data-theme')
  const resolved =
    attr ?? (window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')

  useEffect(() => {
    let alive = true
    loadGoogle()
      .then((gsi) => {
        if (!alive || !box.current) return
        gsi.initialize({
          client_id: GOOGLE_CLIENT_ID,
          callback: (r) => callback.current(r.credential),
          ux_mode: 'popup',
          cancel_on_tap_outside: true,
        })
        box.current.replaceChildren()
        gsi.renderButton(box.current, {
          type: 'standard',
          theme: resolved === 'dark' ? 'filled_black' : 'outline',
          size: 'large',
          shape: 'pill',
          text,
          locale: 'es',
          width: Math.min(400, box.current.clientWidth || 320),
        })
      })
      .catch(() => alive && setFailed(true))
    return () => {
      alive = false
    }
  }, [resolved, text])

  if (failed) return null
  return <div ref={box} className="cr-google" />
}
