// «Continuar con Google» con Google Identity Services: la página recibe un ID token y lo envía a
// /auth/google, que comprueba que vaya dirigido a uno de nuestros IDs de cliente (GOOGLE_CLIENT_IDS).

/** ID de cliente OAuth «Alvea web» (público: va en la página). VITE_GOOGLE_CLIENT_ID lo sustituye. */
export const GOOGLE_CLIENT_ID: string =
  import.meta.env.VITE_GOOGLE_CLIENT_ID ??
  '2627257012-06rocpn2pjiqqa6flkl0pri5gfcnqrps.apps.googleusercontent.com'

const SCRIPT = 'https://accounts.google.com/gsi/client'

export interface GoogleId {
  initialize(options: {
    client_id: string
    callback: (response: { credential: string }) => void
    ux_mode?: 'popup' | 'redirect'
    auto_select?: boolean
    cancel_on_tap_outside?: boolean
  }): void
  renderButton(parent: HTMLElement, options: Record<string, string | number>): void
}

declare global {
  interface Window {
    google?: { accounts: { id: GoogleId } }
  }
}

let loading: Promise<GoogleId> | null = null

/** Olvida un intento fallido para que el siguiente vuelva a pedir el script. */
export function resetGoogle() {
  if (!window.google?.accounts?.id) loading = null
}

/**
 * Carga el script de Google una sola vez. Falla si no se puede (sin conexión, bloqueado…) o si
 * tarda más de 12 s, para no dejar el botón esperando para siempre.
 */
export function loadGoogle(): Promise<GoogleId> {
  if (window.google?.accounts?.id) return Promise.resolve(window.google.accounts.id)
  loading ??= new Promise<GoogleId>((resolve, reject) => {
    const fail = () => {
      loading = null
      s.remove()
      reject(new Error('gsi'))
    }
    const timer = setTimeout(fail, 12_000)
    const s = document.createElement('script')
    s.src = SCRIPT
    s.async = true
    s.onload = () => {
      clearTimeout(timer)
      if (window.google?.accounts?.id) resolve(window.google.accounts.id)
      else fail()
    }
    s.onerror = () => {
      clearTimeout(timer)
      fail()
    }
    document.head.appendChild(s)
  })
  return loading
}
