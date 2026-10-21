import { useAccounts } from '../api/hooks'

/**
 * Moneda de visualización para totales agregados (presupuestos, resumen).
 * Se toma de la primera cuenta activa del usuario; el reporte aún no distingue monedas.
 */
export function useDisplayCurrency(): string | undefined {
  const { data } = useAccounts()
  return data?.[0]?.currency
}

export function money(value: string | number, currency: string | undefined): string {
  return currency
    ? new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(Number(value))
    : String(value)
}
