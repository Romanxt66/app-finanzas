/** Horas de vida: cuánto trabajo cuesta un importe, a partir del valor de la hora del usuario. */

/** Horas equivalentes a un importe; null si el valor de la hora no es válido. */
export function hoursFor(amount: number, hourlyRate: number): number | null {
  return hourlyRate > 0 && Number.isFinite(amount) ? Math.abs(amount) / hourlyRate : null
}

/** 0,2 → «12 min»; 1,5 → «1 h 30 min»; 26 → «26 h». */
export function formatHours(hours: number): string {
  const minutes = Math.round(hours * 60)
  if (minutes < 1) return '< 1 min'
  if (minutes < 60) return `${minutes} min`
  const h = Math.floor(minutes / 60)
  const m = minutes % 60
  return m === 0 || h >= 10 ? `${h} h` : `${h} h ${m} min`
}

/** Texto para junto a un gasto («≈ 1 h 12 min de trabajo»), o undefined si no hay valor de hora. */
export function lifeHoursNote(amount: number, hourlyRate: number | undefined): string | undefined {
  if (!hourlyRate) return undefined
  const hours = hoursFor(amount, hourlyRate)
  return hours === null ? undefined : `≈ ${formatHours(hours)} de trabajo`
}

/** Valor de la hora a partir del ingreso neto mensual y las horas semanales (52 semanas / 12 meses). */
export function hourlyRate(monthlyNetIncome: number, weeklyHours: number): number | null {
  const hoursPerMonth = (weeklyHours * 52) / 12
  return monthlyNetIncome > 0 && hoursPerMonth > 0 ? monthlyNetIncome / hoursPerMonth : null
}
