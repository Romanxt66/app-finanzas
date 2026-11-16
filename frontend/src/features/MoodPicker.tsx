import { SPENDING_MOODS, type SpendingMood } from '../lib/spendingMoods'
import { Alvi } from './Alvi'

/** Cinco caritas para decir cómo te sentías al gastar; pulsar la elegida otra vez la quita. */
export function MoodPicker({
  value,
  onChange,
}: {
  value: SpendingMood | null
  onChange: (v: SpendingMood | null) => void
}) {
  return (
    <div className="cr-stack" style={{ gap: 6 }}>
      <span className="label cr-muted">¿Cómo te sientes? (opcional)</span>
      <div className="cr-mood-picker" role="group" aria-label="Cómo te sientes">
        {(Object.keys(SPENDING_MOODS) as SpendingMood[]).map((m) => (
          <button
            key={m}
            type="button"
            aria-pressed={value === m}
            onClick={() => onChange(value === m ? null : m)}
          >
            <Alvi face={SPENDING_MOODS[m].face} size={34} />
            <span className="caption">{SPENDING_MOODS[m].label}</span>
          </button>
        ))}
      </div>
    </div>
  )
}
