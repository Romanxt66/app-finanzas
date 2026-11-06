// Ánimo de Alvi (la gotita del resumen), igual que en la app Android: cada parte del mes suma puntos
// (máx. 100) y el total decide la expresión, de agobiada (0) a radiante (4).

export type Face = {
  color: string
  smile: number // −1 triste … 1 sonrisa amplia
  mouthOpen?: number
  eyeHappy?: number // ojos en arco (^ ^)
  brow?: number // −1 preocupación … 1 enfado
  blush?: number
  sweat?: number
  tear?: number
  sparkle?: number
  bounce?: number
  shiver?: number
}

export const MOOD_FACES: Face[] = [
  { color: '#8e8e8e', smile: -1, mouthOpen: 0.3, brow: -1, tear: 0.9, sweat: 0.6, shiver: 0.35 },
  { color: '#a2a2a2', smile: -0.4, brow: -1, sweat: 1, shiver: 1 },
  { color: '#c4c4c4', smile: 0.35, blush: 0.25 },
  { color: '#999999', smile: 0.8, mouthOpen: 0.35, blush: 0.7, bounce: 0.35 },
  { color: '#949494', smile: 1, mouthOpen: 0.7, eyeHappy: 1, blush: 0.8, sparkle: 1, bounce: 1 },
]

/** Cara tranquila para estados vacíos. */
export const CALM_FACE: Face = { color: '#c4c4c4', smile: 0.35, blush: 0.25 }

export const MOOD_SPEECH = [
  'Uf… estoy agobiada',
  'Estoy un poco preocupada',
  'Todo tranqui por aquí',
  '¡Estoy contenta!',
  '¡Estoy radiante!',
]
export const MOOD_TITLES = [
  'Alvi está agobiada',
  'Alvi está preocupada',
  'Alvi está tranquila',
  'Alvi está contenta',
  'Alvi está radiante',
]
export const MOOD_MESSAGES = [
  'Tu dinero necesita un respiro: este mes sale más de lo que entra.',
  'Ojo, el mes se está apretando. Un par de ajustes y vuelve la calma.',
  'Todo en orden, sin sobresaltos. Sigue así.',
  'Vas muy bien este mes. ¡Bien hecho!',
  '¡Tus finanzas brillan! Ahorras y vas por debajo de tus límites.',
]

export type Mood = { level: number; score: number; reasons: string[] }

export function financeMood({
  income,
  expense,
  balance,
  allowanceStatus,
  budgets = [],
}: {
  income: number
  expense: number
  balance: number
  allowanceStatus?: string | null
  budgets?: { amount: number; spent: number }[]
}): Mood {
  let score = 0
  const reasons: string[] = []
  if (income > 0) {
    const rate = ((income - expense) / income) * 100
    score += rate >= 20 ? 35 : rate >= 10 ? 25 : rate >= 0 ? 12 : 0
    reasons.push(
      rate >= 0
        ? `ahorras el ${Math.round(rate)} %`
        : `gastas ${Math.round(Math.abs(rate))} % más de lo que entra`,
    )
  } else {
    score += expense > 0 ? 6 : 15
    if (expense > 0) reasons.push('sin ingresos este mes')
  }
  if (allowanceStatus === 'ok') {
    score += 30
    reasons.push('vas dentro de tu ritmo')
  } else if (allowanceStatus === 'tight') {
    score += 12
    reasons.push('hoy te pasaste del día')
  } else if (allowanceStatus === 'over') {
    reasons.push('sin margen para el resto del mes')
  } else {
    score += 15
  }
  const active = budgets.filter((b) => b.amount > 0)
  if (!active.length) {
    score += 12
  } else {
    const over = active.filter((b) => b.spent > b.amount).length
    score += Math.round(20 * (1 - over / active.length))
    reasons.push(
      over === 0
        ? 'ningún presupuesto excedido'
        : `${over} presupuesto${over === 1 ? '' : 's'} excedido${over === 1 ? '' : 's'}`,
    )
  }
  if (balance > 0) score += 15
  else if (balance < 0) reasons.push('saldo en negativo')
  const level = score >= 80 ? 4 : score >= 60 ? 3 : score >= 40 ? 2 : score >= 20 ? 1 : 0
  return { level, score, reasons }
}
