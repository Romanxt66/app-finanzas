import { useLifeHoursProfile } from '../api/hooks'
import { lifeHoursNote } from '../lib/hours'
import { useDisplayCurrency } from '../lib/useCurrency'

/**
 * Devuelve una función que expresa un gasto en horas de trabajo. Solo aplica a la moneda
 * principal del usuario (la del valor de su hora): no se mezclan monedas.
 */
export function useLifeHoursNote(): (amount: number, currency?: string) => string | undefined {
  const { data: profile } = useLifeHoursProfile()
  const main = useDisplayCurrency()
  const rate = profile ? Number(profile.hourly_rate) : undefined
  return (amount, currency) =>
    currency && currency === main ? lifeHoursNote(amount, rate) : undefined
}
