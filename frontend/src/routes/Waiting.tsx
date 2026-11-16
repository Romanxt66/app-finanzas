import { useEffect, useState } from 'react'
import {
  useAddWaiting,
  useContribute,
  useDecideWaiting,
  useGoals,
  useDeleteWaiting,
  useWaitingRoom,
  type WaitingItem,
  type WaitingRoom,
} from '../api/hooks'
import {
  AnimatedMoney,
  Badge,
  Button,
  Card,
  ConfirmDialog,
  ErrorText,
  FormDialog,
  Glass,
  Input,
  PageTitle,
  Segmented,
  Skeleton,
} from '../design'
import { CurrencySelect } from '../features/CurrencySelect'
import { useLifeHoursNote } from '../features/useLifeHoursNote'
import { formatDate, formatMoney, todayISO } from '../lib/format'
import { useDisplayCurrency } from '../lib/useCurrency'

const WAITS = [
  { value: '24', label: '1 día' },
  { value: '72', label: '3 días' },
  { value: '168', label: '1 semana' },
]

/** «2 d 5 h», «40 min»: lo que falta para poder decidir. */
export function timeLeft(ms: number): string {
  const minutes = Math.floor(ms / 60_000)
  if (minutes < 1) return 'menos de un minuto'
  const days = Math.floor(minutes / 1440)
  const hours = Math.floor(minutes / 60) % 24
  const mins = minutes % 60
  if (days > 0) return `${days} d${hours > 0 ? ` ${hours} h` : ''}`
  if (hours > 0) return `${hours} h${mins > 0 ? ` ${mins} min` : ''}`
  return `${mins} min`
}

/** Sala de espera: aparcar una compra unos días y decidir con la cabeza fría (como en la app). */
export function WaitingRoomPage() {
  const { data: room, isLoading, error } = useWaitingRoom()
  // Las cuentas atrás se refrescan solas cada medio minuto
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 30_000)
    return () => clearInterval(t)
  }, [])
  // Tras descartar una compra se ofrece apartar ese dinero en una meta (como en la app)
  const [saved, setSaved] = useState<WaitingItem | null>(null)
  const pending = room?.items.filter((i) => i.status === 'waiting') ?? []
  const decided = room?.items.filter((i) => i.status !== 'waiting') ?? []

  return (
    <>
      <PageTitle title="Sala de espera" headline="Piénsalo *antes* de comprar." />
      <p className="body cr-muted">
        Deja aquí lo que te tienta. Pasado el plazo decides con la cabeza fría, y lo que no compres
        suma a tu ahorro.
      </p>
      <ErrorText error={error} />
      {isLoading ? <Skeleton lines={1} height={120} /> : room && <NotSpent room={room} />}
      <AddForm />
      {pending.length > 0 && (
        <>
          <h2 className="heading">En espera</h2>
          <ul className="cr-stack cr-plain-list" aria-label="En espera">
            {pending.map((item) => (
              <li key={item.id}>
                <PendingCard item={item} now={now} onSkipped={setSaved} />
              </li>
            ))}
          </ul>
        </>
      )}
      {decided.length > 0 && (
        <>
          <h2 className="heading">Decididas</h2>
          <Glass size="md" padded as="ul" className="cr-plain-list cr-stack" aria-label="Decididas">
            {decided.map((item) => (
              <li key={item.id} className="cr-row-split">
                <span>
                  <span className="body">{item.name}</span>
                  {item.decided_at && (
                    <span className="caption cr-muted"> · {formatDate(item.decided_at)}</span>
                  )}
                </span>
                <span className="cr-row">
                  <span className="amount-sm">{formatMoney(item.amount, item.currency)}</span>
                  {item.status === 'skipped' ? (
                    <Badge tone="positive">no la compraste</Badge>
                  ) : (
                    <Badge>la compraste</Badge>
                  )}
                </span>
              </li>
            ))}
          </Glass>
        </>
      )}
      <SendToGoal item={saved} onClose={() => setSaved(null)} />
    </>
  )
}

/** «¿Lo mandas a una meta?»: aporta lo que no gastaste a una meta de la misma moneda. */
function SendToGoal({ item, onClose }: { item: WaitingItem | null; onClose: () => void }) {
  const { data: goals = [] } = useGoals()
  const contribute = useContribute()
  const options = item
    ? goals.filter((g) => !g.achieved && g.currency === item.currency).slice(0, 4)
    : []
  return (
    <FormDialog
      open={!!item && options.length > 0}
      title="¿Lo mandas a una meta?"
      onClose={onClose}
    >
      {item && (
        <div className="cr-stack">
          <p className="body cr-muted">
            Aparta los {formatMoney(item.amount, item.currency)} que no gastaste en una de tus
            metas.
          </p>
          {options.map((g) => (
            <Button
              key={g.id}
              icon="flag"
              disabled={contribute.isPending}
              onClick={() =>
                contribute.mutate(
                  {
                    goalId: g.id,
                    amount: String(Number(item.amount)),
                    occurred_on: todayISO(),
                    note: `No compraste «${item.name}»`,
                  },
                  { onSuccess: onClose },
                )
              }
            >
              {g.name}
            </Button>
          ))}
          <ErrorText error={contribute.error} />
          <Button variant="ghost" onClick={onClose}>
            Ahora no
          </Button>
        </div>
      )}
    </FormDialog>
  )
}

function NotSpent({ room }: { room: WaitingRoom }) {
  const saved = room.not_spent.length > 0
  return (
    <Glass strong size="md" padded className="cr-stack">
      <span className="label cr-muted">lo que no gastaste</span>
      {saved ? (
        <div className="amount">
          {room.not_spent.map((t) => (
            <span key={t.currency} style={{ marginRight: 16 }}>
              <AnimatedMoney value={Number(t.total)} currency={t.currency} />
            </span>
          ))}
        </div>
      ) : (
        <p className="heading">Aún nada… ¡pero pronto!</p>
      )}
      <span className="caption cr-muted">
        {saved
          ? `${room.skipped} compra${room.skipped === 1 ? '' : 's'} descartada${room.skipped === 1 ? '' : 's'} · ${room.bought} hecha${room.bought === 1 ? '' : 's'}`
          : 'Cada compra que decidas no hacer se suma aquí.'}
      </span>
    </Glass>
  )
}

function AddForm() {
  const add = useAddWaiting()
  const main = useDisplayCurrency()
  const lifeNote = useLifeHoursNote()
  const [name, setName] = useState('')
  const [amount, setAmount] = useState('')
  const [currency, setCurrency] = useState('')
  const [wait, setWait] = useState('72')
  const [tried, setTried] = useState(false)
  const cur = currency || main || ''
  const value = Number(amount.replace(',', '.'))
  const nameError = tried && !name.trim() ? '¿Qué quieres comprar?' : undefined
  const amountError = tried && !(value > 0) ? 'Escribe un precio mayor que 0' : undefined
  const hours = value > 0 ? lifeNote(value, cur) : undefined

  return (
    <Card title="¿Qué te tienta?">
      <form
        className="cr-stack"
        onSubmit={(e) => {
          e.preventDefault()
          setTried(true)
          if (!name.trim() || !(value > 0) || !cur) return
          add.mutate(
            { name: name.trim(), amount: String(value), currency: cur, wait_hours: Number(wait) },
            {
              onSuccess: () => {
                setName('')
                setAmount('')
                setTried(false)
              },
            },
          )
        }}
      >
        <div className="cr-form-grid">
          <Input
            label="Qué quieres comprar"
            value={name}
            error={nameError}
            onChange={(e) => setName(e.target.value)}
          />
          <Input
            label="Precio"
            inputMode="decimal"
            value={amount}
            error={amountError}
            onChange={(e) => setAmount(e.target.value)}
          />
          <CurrencySelect value={cur} onChange={(e) => setCurrency(e.target.value)} />
        </div>
        <div className="cr-row">
          <span className="label cr-muted">Esperar</span>
          <Segmented label="Cuánto esperar" options={WAITS} value={wait} onChange={setWait} />
        </div>
        {hours && <p className="cr-serif cr-muted">Te costaría {hours}.</p>}
        <ErrorText error={add.error} />
        <div>
          <Button type="submit" variant="primary" icon="target" disabled={add.isPending}>
            Dejar en espera
          </Button>
        </div>
      </form>
    </Card>
  )
}

function PendingCard({
  item,
  now,
  onSkipped,
}: {
  item: WaitingItem
  now: number
  onSkipped: (item: WaitingItem) => void
}) {
  const decide = useDecideWaiting()
  const remove = useDeleteWaiting()
  const lifeNote = useLifeHoursNote()
  const [confirming, setConfirming] = useState(false)
  const start = new Date(item.created_at).getTime()
  const end = new Date(item.ready_at).getTime()
  const left = end - now
  const ready = item.ready || left <= 0
  const total = end - start
  const progress = total <= 0 ? 1 : Math.min(1, Math.max(0, 1 - left / total))
  const hours = lifeNote(Number(item.amount), item.currency)

  return (
    <Glass size="md" className="cr-budget">
      <div className="cr-budget-head">
        <span>
          <span className="body">{item.name}</span>
          {hours && <span className="caption cr-muted cr-block">{hours}</span>}
        </span>
        <span className="amount-sm">{formatMoney(item.amount, item.currency)}</span>
      </div>
      <div
        className="cr-track"
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.round(progress * 100)}
        aria-label={`Espera de ${item.name}`}
      >
        <div className="cr-fill" style={{ width: `${progress * 100}%` }} />
      </div>
      <span className="caption cr-muted">
        {ready
          ? '¡Ya puedes decidir! ¿Todavía lo quieres?'
          : `Faltan ${timeLeft(left)} para decidir`}
      </span>
      <div className="cr-row">
        <Button
          size="sm"
          variant={ready ? 'primary' : 'ghost'}
          disabled={decide.isPending}
          onClick={() =>
            decide.mutate(
              { id: item.id, decision: 'skipped' },
              { onSuccess: () => onSkipped(item) },
            )
          }
        >
          Ya no la quiero
        </Button>
        {ready && (
          <Button
            size="sm"
            variant="ghost"
            disabled={decide.isPending}
            onClick={() => decide.mutate({ id: item.id, decision: 'bought' })}
          >
            La compré
          </Button>
        )}
        <Button
          size="sm"
          variant="ghost"
          icon="trash"
          aria-label={`Quitar ${item.name} de la lista`}
          onClick={() => setConfirming(true)}
        />
      </div>
      <ErrorText error={decide.error ?? remove.error} />
      <ConfirmDialog
        open={confirming}
        title={`¿Quitar «${item.name}»?`}
        onCancel={() => setConfirming(false)}
        onConfirm={() => {
          remove.mutate(item.id)
          setConfirming(false)
        }}
      >
        No contará como gasto ni como ahorro.
      </ConfirmDialog>
    </Glass>
  )
}
