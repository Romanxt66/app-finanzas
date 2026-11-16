import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import {
  useContribute,
  useContributions,
  useCreateGoal,
  useDeleteContribution,
  useDeleteGoal,
  useGoals,
  useUpdateGoal,
  type Goal,
} from '../api/hooks'
import {
  Button,
  Card,
  Checkbox,
  Glass,
  Icon,
  StatTile,
  ConfirmDialog,
  Empty,
  ErrorText,
  FormDialog,
  Input,
  ProgressCard,
  Skeleton,
  CreateSection,
  PageTitle,
} from '../design'
import { CurrencySelect } from '../features/CurrencySelect'
import { formatDate, formatMoney, todayISO } from '../lib/format'
import { monthlyNeeded } from '../lib/goals'

const goalSchema = z.object({
  name: z.string().min(1, 'Requerido').max(80),
  target_amount: z.string().regex(/^\d+(\.\d{1,2})?$/, 'Monto positivo con hasta 2 decimales'),
  currency: z.string().min(1, 'Selecciona una moneda'),
  deadline: z.string().optional(),
})

const contributionSchema = z.object({
  amount: z.string().regex(/^\d+(\.\d{1,2})?$/, 'Monto positivo con hasta 2 decimales'),
  occurred_on: z.string().min(1, 'Requerida'),
  note: z.string().max(255),
})

function goalNote(goal: Goal): string | undefined {
  if (goal.achieved) return '¡Meta cumplida!'
  const parts: string[] = [`Faltan ${formatMoney(goal.remaining, goal.currency)}`]
  if (goal.deadline) {
    // Con la fecha ya pasada, «para el …» sonaría a que aún hay tiempo
    parts.push(
      goal.deadline < todayISO()
        ? `· el plazo venció el ${formatDate(goal.deadline)}`
        : `para el ${formatDate(goal.deadline)}`,
    )
  }
  const perMonth = monthlyNeeded(goal)
  if (perMonth) parts.push(`· ${formatMoney(perMonth, goal.currency)} al mes`)
  return parts.join(' ')
}

function ContributionForm({
  goal,
  withdraw,
  onClose,
}: {
  goal: Goal
  withdraw: boolean
  onClose: () => void
}) {
  const contribute = useContribute()
  const { register, handleSubmit, formState } = useForm({
    resolver: zodResolver(contributionSchema),
    defaultValues: { amount: '', occurred_on: todayISO(), note: '' },
  })
  return (
    <form
      className="cr-stack"
      onSubmit={handleSubmit((d) =>
        contribute.mutate(
          {
            goalId: goal.id,
            amount: withdraw ? `-${d.amount}` : d.amount,
            occurred_on: d.occurred_on,
            note: d.note,
          },
          { onSuccess: onClose },
        ),
      )}
    >
      <Input
        label="Monto"
        inputMode="decimal"
        error={formState.errors.amount?.message}
        {...register('amount')}
      />
      <Input
        label="Fecha"
        type="date"
        error={formState.errors.occurred_on?.message}
        {...register('occurred_on')}
      />
      <Input label="Nota (opcional)" {...register('note')} />
      <ErrorText error={contribute.error} />
      <div className="cr-dialog-actions">
        <Button variant="ghost" onClick={onClose}>
          Cancelar
        </Button>
        <Button type="submit" variant="primary" disabled={contribute.isPending}>
          {withdraw ? 'Retirar' : 'Aportar'}
        </Button>
      </div>
    </form>
  )
}

const editSchema = goalSchema.omit({ currency: true })

/** Editar una meta: nombre, objetivo y fecha límite (vacía = sin fecha). Solo envía lo que cambió. */
function GoalEditForm({ goal, onClose }: { goal: Goal; onClose: () => void }) {
  const update = useUpdateGoal()
  const { register, handleSubmit, formState } = useForm({
    resolver: zodResolver(editSchema),
    defaultValues: {
      name: goal.name,
      target_amount: String(Number(goal.target_amount)),
      deadline: goal.deadline ?? '',
    },
  })
  return (
    <form
      className="cr-stack"
      onSubmit={handleSubmit((d) => {
        const deadline = d.deadline || null
        update.mutate(
          {
            id: goal.id,
            ...(d.name.trim() !== goal.name && { name: d.name.trim() }),
            ...(Number(d.target_amount) !== Number(goal.target_amount) && {
              target_amount: d.target_amount,
            }),
            ...(deadline !== (goal.deadline ?? null) && { deadline }),
          },
          { onSuccess: onClose },
        )
      })}
    >
      <div className="cr-form-grid">
        <Input label="Nombre" error={formState.errors.name?.message} {...register('name')} />
        <Input
          label={`Monto objetivo (${goal.currency})`}
          inputMode="decimal"
          error={formState.errors.target_amount?.message}
          {...register('target_amount')}
        />
        <Input label="Fecha límite (vacía: sin fecha)" type="date" {...register('deadline')} />
      </div>
      <ErrorText error={update.error} />
      <div className="cr-dialog-actions">
        <Button variant="ghost" onClick={onClose}>
          Cancelar
        </Button>
        <Button type="submit" variant="primary" disabled={update.isPending}>
          Guardar
        </Button>
      </div>
    </form>
  )
}

export function GoalsPage() {
  const { data: goals, isLoading } = useGoals()
  const create = useCreateGoal()
  const remove = useDeleteGoal()
  const [contribution, setContribution] = useState<{ goal: Goal; withdraw: boolean } | null>(null)
  const [history, setHistory] = useState<Goal | null>(null)
  const [pendingDelete, setPendingDelete] = useState<Goal | null>(null)
  const [editing, setEditing] = useState<Goal | null>(null)
  const [showAchieved, setShowAchieved] = useState(true)
  const { register, handleSubmit, reset, formState } = useForm({
    resolver: zodResolver(goalSchema),
  })

  return (
    <>
      <PageTitle title="Metas" headline="Ahorra para lo que *importa*." />
      <CreateSection title="Nueva meta" hasData={!!goals?.length}>
        <form
          className="cr-stack"
          onSubmit={handleSubmit((d) =>
            create.mutate({ ...d, deadline: d.deadline || null }, { onSuccess: () => reset() }),
          )}
        >
          <div className="cr-form-grid">
            <Input label="Nombre" error={formState.errors.name?.message} {...register('name')} />
            <Input
              label="Monto objetivo"
              inputMode="decimal"
              error={formState.errors.target_amount?.message}
              {...register('target_amount')}
            />
            <CurrencySelect error={formState.errors.currency?.message} {...register('currency')} />
            <Input label="Fecha límite (opcional)" type="date" {...register('deadline')} />
          </div>
          <div>
            <Button type="submit" variant="primary" disabled={create.isPending}>
              Crear meta
            </Button>
          </div>
          <ErrorText error={create.error} />
        </form>
      </CreateSection>

      {isLoading ? (
        <Skeleton lines={2} height={120} />
      ) : !goals?.length ? (
        <Card>
          <Empty>Aún no tienes metas. Crea una para empezar a ahorrar con un objetivo.</Empty>
        </Card>
      ) : (
        <>
          <GoalsSummary goals={goals} />
          <Checkbox
            className="cr-goal-filter"
            label="Mostrar metas cumplidas"
            checked={showAchieved}
            onChange={(e) => setShowAchieved(e.target.checked)}
          />
          <ul className="cr-goal-grid">
            {goals
              .filter((g) => showAchieved || !g.achieved)
              .map((g) => (
                <li key={g.id}>
                  <ProgressCard
                    label={g.name}
                    saved={Number(g.saved)}
                    target={Number(g.target_amount)}
                    currency={g.currency}
                    achieved={g.achieved}
                    note={goalNote(g)}
                    actions={
                      <>
                        <Button
                          variant="primary"
                          size="sm"
                          onClick={() => setContribution({ goal: g, withdraw: false })}
                        >
                          Aportar
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => setContribution({ goal: g, withdraw: true })}
                        >
                          Retirar
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          icon="list"
                          aria-label={`Historial de ${g.name}`}
                          onClick={() => setHistory(g)}
                        />
                        <Button
                          variant="ghost"
                          size="sm"
                          icon="edit"
                          aria-label={`Editar ${g.name}`}
                          onClick={() => setEditing(g)}
                        />
                        <Button
                          variant="ghost"
                          size="sm"
                          icon="trash"
                          aria-label={`Eliminar ${g.name}`}
                          onClick={() => setPendingDelete(g)}
                        />
                      </>
                    }
                  />
                </li>
              ))}
          </ul>
        </>
      )}

      <FormDialog
        open={!!contribution}
        title={
          contribution
            ? `${contribution.withdraw ? 'Retirar de' : 'Aportar a'} «${contribution.goal.name}»`
            : ''
        }
        onClose={() => setContribution(null)}
      >
        {contribution && (
          <ContributionForm
            key={`${contribution.goal.id}-${contribution.withdraw}`}
            goal={contribution.goal}
            withdraw={contribution.withdraw}
            onClose={() => setContribution(null)}
          />
        )}
      </FormDialog>
      <FormDialog
        open={!!history}
        title={history ? `Aportes a «${history.name}»` : ''}
        onClose={() => setHistory(null)}
      >
        {history && <ContributionHistory goal={history} onClose={() => setHistory(null)} />}
      </FormDialog>
      <FormDialog
        open={!!editing}
        title={editing ? `Editar «${editing.name}»` : ''}
        onClose={() => setEditing(null)}
      >
        {editing && (
          <GoalEditForm key={editing.id} goal={editing} onClose={() => setEditing(null)} />
        )}
      </FormDialog>
      <ConfirmDialog
        open={!!pendingDelete}
        title={`¿Eliminar la meta «${pendingDelete?.name}»?`}
        onCancel={() => setPendingDelete(null)}
        onConfirm={() => {
          if (pendingDelete) remove.mutate(pendingDelete.id)
          setPendingDelete(null)
        }}
      >
        Se borrarán también sus aportes. Esta acción no se puede deshacer.
      </ConfirmDialog>
      <ErrorText error={remove.error} />
    </>
  )
}

/** Aportes y retiros de una meta, del más reciente al más antiguo; se puede borrar uno hecho por error. */
function ContributionHistory({ goal, onClose }: { goal: Goal; onClose: () => void }) {
  const { data, isLoading } = useContributions(goal.id)
  const remove = useDeleteContribution()
  const [pending, setPending] = useState<string | null>(null)
  const close = (
    <div>
      <Button variant="ghost" onClick={onClose}>
        Cerrar
      </Button>
    </div>
  )
  if (isLoading) return <Skeleton lines={3} height={40} />
  if (!data?.length)
    return (
      <>
        <Empty>Aún no hay aportes en esta meta.</Empty>
        {close}
      </>
    )
  const items = [...data].sort((a, b) => b.occurred_on.localeCompare(a.occurred_on))
  return (
    <div className="cr-stack">
      <ul className="cr-plain-list cr-stack" aria-label="Aportes">
        {items.map((c) => {
          const amount = Number(c.amount)
          return (
            <li key={c.id} className="cr-row-split">
              <span>
                <span className="body">{formatDate(c.occurred_on)}</span>
                {c.note && <span className="caption cr-muted cr-block">{c.note}</span>}
              </span>
              <span className="cr-row">
                <span className={amount < 0 ? 'amount-sm cr-neg' : 'amount-sm cr-pos'}>
                  {formatMoney(amount, goal.currency, { signed: true })}
                </span>
                {pending === c.id ? (
                  <Button
                    variant="danger"
                    size="sm"
                    disabled={remove.isPending}
                    onClick={() =>
                      remove.mutate(
                        { goalId: goal.id, id: c.id },
                        { onSettled: () => setPending(null) },
                      )
                    }
                  >
                    Eliminar
                  </Button>
                ) : (
                  <Button
                    variant="ghost"
                    size="sm"
                    icon="trash"
                    aria-label={`Eliminar aporte del ${formatDate(c.occurred_on)}`}
                    onClick={() => setPending(c.id)}
                  />
                )}
              </span>
            </li>
          )
        })}
      </ul>
      <ErrorText error={remove.error} />
      {close}
    </div>
  )
}

/** Total ahorrado (moneda de la primera meta) y cuántas metas se cumplieron. */
function GoalsSummary({ goals }: { goals: Goal[] }) {
  const currency = goals[0].currency
  const same = goals.filter((g) => g.currency === currency)
  const saved = same.reduce((t, g) => t + Number(g.saved), 0)
  const target = same.reduce((t, g) => t + Number(g.target_amount), 0)
  const done = goals.filter((g) => g.achieved).length
  return (
    <div className="cr-grid-kpi">
      <StatTile
        label="Ahorrado"
        value={saved}
        currency={currency}
        icon="target"
        note={`de ${formatMoney(target, currency)}`}
      />
      <Glass size="md" className="cr-stat">
        <div className="cr-stat-head">
          <span className="cr-chip">
            <Icon name="check" />
          </span>
        </div>
        <div>
          <div className="overline">Cumplidas</div>
          <div className="amount">
            {done}/{goals.length}
          </div>
          <div className="caption cr-muted">
            {done === goals.length ? '¡todas cumplidas!' : `${goals.length - done} en camino`}
          </div>
        </div>
      </Glass>
    </div>
  )
}
