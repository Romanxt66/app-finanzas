import { useState } from 'react'
import { useBudgets, useDailyAllowance } from '../api/hooks'
import { Glass } from '../design'
import { MOOD_FACES, MOOD_MESSAGES, MOOD_SPEECH, MOOD_TITLES, financeMood } from '../lib/mood'
import { Alvi } from './Alvi'

/** Tarjeta del resumen con Alvi: su cara refleja la salud del mes; al tocarla cuenta por qué. */
export function MoodCard({
  month,
  income,
  expense,
  balance,
}: {
  month: string
  income: number
  expense: number
  balance: number
}) {
  const { data: allowance } = useDailyAllowance()
  const { data: budgets = [] } = useBudgets(month)
  const [tip, setTip] = useState(0)
  const [hop, setHop] = useState(0)
  const mood = financeMood({
    income,
    expense,
    balance,
    allowanceStatus: allowance?.status,
    budgets: budgets.map((b) => ({ amount: Number(b.amount), spent: Number(b.spent) })),
  })
  const steps = mood.reasons.length + 1
  const step = tip % steps
  const reason = mood.reasons[step - 1]
  const line =
    step === 0 ? MOOD_MESSAGES[mood.level] : `${reason[0].toUpperCase()}${reason.slice(1)}.`
  return (
    <section className="cr-mood" aria-label={MOOD_TITLES[mood.level]}>
      <button
        type="button"
        className="cr-mood-alvi"
        aria-label={`${MOOD_TITLES[mood.level]}. Toca para que te cuente por qué.`}
        onClick={() => {
          setTip((t) => t + 1)
          setHop((h) => h + 1)
        }}
      >
        <span key={hop} className={hop ? 'cr-mood-hop' : undefined}>
          <Alvi face={MOOD_FACES[mood.level]} size={104} />
        </span>
        alvi
      </button>
      <Glass size="md" className="cr-mood-bubble">
        <p className="cr-mood-says">{MOOD_SPEECH[mood.level]}</p>
        <p className="cr-mood-line" aria-live="polite">
          {line}
        </p>
        {mood.reasons.length > 0 && (
          <span className="cr-mood-hint">toca a alvi: te cuenta más</span>
        )}
      </Glass>
    </section>
  )
}
