import type { Face } from './mood'

// Cómo te sentías al gastar (opcional, solo en gastos). Mismas caritas que la app Android.
export type SpendingMood = 'happy' | 'calm' | 'stressed' | 'sad' | 'bored'

export const SPENDING_MOODS: Record<SpendingMood, { label: string; face: Face }> = {
  happy: { label: 'Feliz', face: { color: '#c9c9c9', smile: 0.85, eyeHappy: 0.9, blush: 0.6 } },
  calm: { label: 'Tranquilo', face: { color: '#d4d4d4', smile: 0.4, eyeHappy: 0.85, blush: 0.3 } },
  stressed: { label: 'Estresado', face: { color: '#a2a2a2', smile: -0.45, brow: 1, sweat: 0.9 } },
  sad: { label: 'Triste', face: { color: '#bebebe', smile: -0.8, brow: -1, tear: 1 } },
  bored: { label: 'Aburrido', face: { color: '#bdbdbd', smile: -0.05 } },
}

const WEEKDAYS = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábados', 'domingos']

/** «Cuando estás estresado gastas un 29 % más por compra, sobre todo los viernes.» */
export function moodHighlightText(h: {
  mood: SpendingMood
  change_pct: string | number
  top_weekday: number
}): string {
  const label = SPENDING_MOODS[h.mood]?.label.toLowerCase() ?? h.mood
  const day = WEEKDAYS[Math.min(6, Math.max(0, h.top_weekday - 1))]
  const change = Number(h.change_pct)
  if (Math.abs(change) < 5)
    return `Cuando estás ${label} gastas lo de siempre por compra. Lo marcas más los ${day}.`
  const pct = Math.abs(change).toLocaleString('es-CO', { maximumFractionDigits: 1 })
  return `Cuando estás ${label} gastas un ${pct} % ${change > 0 ? 'más' : 'menos'} por compra, sobre todo los ${day}.`
}
