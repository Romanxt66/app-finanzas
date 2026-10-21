import type { GhostReport } from '../api/hooks'
import { formatMoney, formatPercent } from '../lib/format'

type Alert = GhostReport['alerts'][number]

export const CADENCE_LABELS = {
  weekly: 'cada semana',
  monthly: 'cada mes',
  yearly: 'cada año',
} as const

export const ALERT_ICONS = {
  price_increase: 'up',
  duplicate: 'swap',
  trial_converted: 'tag',
} as const

/** Frase que describe una alerta. */
export function alertText(a: Alert): string {
  const amount = formatMoney(a.amount, a.currency)
  const previous = a.previous_amount ? formatMoney(a.previous_amount, a.currency) : ''
  switch (a.kind) {
    case 'price_increase':
      return `${a.name} subió de ${previous} a ${amount} (+${formatPercent(a.change_percent ?? 0)} %).`
    case 'duplicate':
      return `Posible cobro duplicado de ${a.name}: ${amount} dos veces en pocos días.`
    case 'trial_converted':
      return `${a.name}: la prueba de ${previous} pasó a un cobro de ${amount}.`
  }
}
