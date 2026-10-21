import type { Goal } from '../api/hooks'

/** Cuánto ahorrar al mes para llegar a la fecha límite (null si no aplica). */
export function monthlyNeeded(goal: Goal, now = new Date()): number | null {
  if (!goal.deadline || goal.achieved) return null
  const end = new Date(`${goal.deadline}T00:00:00`)
  const months = (end.getFullYear() - now.getFullYear()) * 12 + (end.getMonth() - now.getMonth())
  if (months <= 0) return null
  return Number(goal.remaining) / months
}
