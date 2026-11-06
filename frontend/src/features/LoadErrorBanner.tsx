import { useQueryClient } from '@tanstack/react-query'
import { useSyncExternalStore } from 'react'
import { Button, Glass } from '../design'

/**
 * Si alguna consulta de la pantalla falló, lo dice y ofrece reintentar. Sin esto, un fallo del servidor
 * se veía como «todo en cero» (los números caen a su valor por defecto).
 */
export function LoadErrorBanner() {
  const client = useQueryClient()
  const cache = client.getQueryCache()
  const failed = useSyncExternalStore(
    (onChange) => cache.subscribe(onChange),
    () =>
      cache.findAll({ type: 'active' }).some((q) => q.state.status === 'error' && !q.state.data),
  )
  if (!failed) return null
  return (
    <Glass as="aside" padded className="cr-load-error" role="alert">
      <p>
        <strong>No pudimos cargar tus datos.</strong> Puede ser la conexión o el servidor; tus datos
        están a salvo.
      </p>
      <Button
        variant="primary"
        icon="restore"
        onClick={() =>
          client.refetchQueries({ type: 'active', predicate: (q) => q.state.status === 'error' })
        }
      >
        Reintentar
      </Button>
    </Glass>
  )
}
