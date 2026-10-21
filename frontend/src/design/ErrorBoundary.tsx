import { Component, type ErrorInfo, type ReactNode } from 'react'
import { Backdrop, Button, Glass } from './components'

interface Props {
  children: ReactNode
  /** Para registrar el error (consola, servicio de logs…). Por defecto, console.error. */
  onError?: (error: Error, info: ErrorInfo) => void
}

/** Red de seguridad: un fallo de renderizado muestra una pantalla amable en vez de dejar la página en blanco. */
export class ErrorBoundary extends Component<Props, { failed: boolean }> {
  state = { failed: false }

  static getDerivedStateFromError() {
    return { failed: true }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    if (this.props.onError) this.props.onError(error, info)
    else console.error(error, info.componentStack)
  }

  render() {
    if (!this.state.failed) return this.props.children
    return (
      <Backdrop>
        <main className="cr-auth" role="alert">
          <h1 className="title">Algo salió mal</h1>
          <Glass strong padded>
            <p className="body">
              Ocurrió un error inesperado en la aplicación. Tus datos están a salvo; recarga la
              página para continuar.
            </p>
            <div style={{ marginTop: 'var(--space-4)' }}>
              <Button variant="primary" onClick={() => window.location.reload()}>
                Recargar
              </Button>
            </div>
          </Glass>
        </main>
      </Backdrop>
    )
  }
}
