import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { useContribute, useCreateGoal, useDeleteGoal, useGoals, type Goal } from '../api/hooks'
import {
  Button,
  Card,
  ConfirmDialog,
  Empty,
  ErrorText,
  FormDialog,
  Input,
  ProgressCard,
  Skeleton,
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
  if (goal.deadline) parts.push(`para el ${formatDate(goal.deadline)}`)
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

export function GoalsPage() {
  const { data: goals, isLoading } = useGoals()
  const create = useCreateGoal()
  const remove = useDeleteGoal()
  const [contribution, setContribution] = useState<{ goal: Goal; withdraw: boolean } | null>(null)
  const [pendingDelete, setPendingDelete] = useState<Goal | null>(null)
  const { register, handleSubmit, reset, formState } = useForm({
    resolver: zodResolver(goalSchema),
  })

  return (
    <>
      <h1 className="title">Metas</h1>
      <Card title="Nueva meta">
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
      </Card>

      {isLoading ? (
        <Skeleton lines={2} height={120} />
      ) : !goals?.length ? (
        <Card>
          <Empty>Aún no tienes metas. Crea una para empezar a ahorrar con un objetivo.</Empty>
        </Card>
      ) : (
        <ul className="cr-goal-grid">
          {goals.map((g) => (
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
                    <Button variant="danger" size="sm" onClick={() => setPendingDelete(g)}>
                      Eliminar
                    </Button>
                  </>
                }
              />
            </li>
          ))}
        </ul>
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
