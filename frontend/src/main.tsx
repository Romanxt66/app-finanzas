import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { applyStoredTheme, ErrorBoundary } from './design'
import './index.css'
import App from './App.tsx'

applyStoredTheme()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </StrictMode>,
)

// PWA: solo en producción (en desarrollo el service worker estorbaría al recargar en caliente)
if (import.meta.env.PROD && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(() => {
      /* sin service worker la app sigue funcionando en línea */
    })
  })
}
