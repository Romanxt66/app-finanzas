import { useState } from 'react'
import {
  type Budget,
  type BudgetPeriod,
  useBudgetsFor,
  useCategories,
  useCreateBudget,
  useDeleteBudget,
  useUpdateBudget,
} from '../api/hooks'
import {
  Badge,
  BudgetBar,
  Button,
  Card,
  Checkbox,
  ConfirmDialog,
  CreateSection,
  Empty,
  ErrorText,
  FormDialog,
  Input,
  PageTitle,
  PeriodPill,
  Segmented,
  Skeleton,
} from '../design'
import { CategorySelect } from '../features/CategorySelect'
import { EVERY, PERIOD_OPTIONS, periodLabel, shiftPeriod } from '../lib/budgetPeriod'
import { todayISO } from '../lib/format'
import { useDisplayCurrency } from '../lib/useCurrency'

const AMOUNT = /^\d+(\.\d{1,2})?$/
const GENERAL = 'Todos los gastos'

type Draft = { category_id: string; amount: string; recurring: boolean }

/** Formulario de presupuesto: para qué (una categoría o todos los gastos), cuánto y si se repite. */
function BudgetForm(props: {
  period: BudgetPeriod
  initial: Draft
  submitLabel: string
  pending: boolean
  error: unknown
  onSubmit: (draft: Draft) => void
  onCancel?: () => void
}) {
  const [draft, setDraft] = useState(props.initial)
  const [problem, setProblem] = useState<string | null>(null)
  return (
    <form
      className="cr-stack"
      onSubmit={(e) => {
        e.preventDefault()
        const amount = draft.amount.trim().replace(',', '.')
        if (!AMOUNT.test(amount) || Number(amount) <= 0) {
          setProblem('Monto positivo con hasta 2 decimales')
          return
        }
        setProblem(null)
        props.onSubmit({ ...draft, amount })
      }}
    >
      <div className="cr-form-grid">
        <CategorySelect
          kind="expense"
          label="Para"
          emptyLabel={`${GENERAL} (general)`}
          value={draft.category_id}
          onChange={(e) => setDraft({ ...draft, category_id: e.target.value })}
        />
        <Input
          label="Monto"
          inputMode="decimal"
          value={draft.amount}
          error={problem ?? undefined}
          onChange={(e) => setDraft({ ...draft, amount: e.target.value })}
        />
      </div>
      <Checkbox
        label={`Repetir ${EVERY[props.period]}`}
        checked={draft.recurring}
        onChange={(e) => setDraft({ ...draft, recurring: e.target.checked })}
      />
      <ErrorText error={props.error} />
      <div className="cr-dialog-actions">
        {props.onCancel && (
          <Button variant="ghost" onClick={props.onCancel}>
            Cancelar
          </Button>
        )}
        <Button type="submit" variant="primary" disabled={props.pending}>
          {props.submitLabel}
        </Button>
      </div>
    </form>
  )
}

export function BudgetsPage() {
  const [period, setPeriod] = useState<BudgetPeriod>('month')
  const [date, setDate] = useState(todayISO())
  const currency = useDisplayCurrency()
  const { data: budgets, isLoading } = useBudgetsFor(period, date)
  const { data: categories = [] } = useCategories()
  const create = useCreateBudget()
  const remove = useDeleteBudget()
  const update = useUpdateBudget()
  const [editing, setEditing] = useState<Budget | null>(null)
  const [pending, setPending] = useState<Budget | null>(null)
  const [formKey, setFormKey] = useState(0)
  const names = new Map(categories.map((c) => [c.id, c.name]))
  const nameOf = (b: Budget) =>
    b.category_id ? (names.get(b.category_id) ?? 'Categoría') : GENERAL
  // El general primero: es el límite de todo lo demás
  const sorted = [...(budgets ?? [])].sort(
    (a, b) => Number(a.category_id !== null) - Number(b.category_id !== null),
  )

  return (
    <>
      <div className="cr-page-head">
        <PageTitle title="Presupuestos" headline="Límites que *te cuidan*." />
        <PeriodPill
          name="Periodo del presupuesto"
          label={periodLabel(period, date)}
          onPrev={() => setDate(shiftPeriod(period, date, -1))}
          onNext={() => setDate(shiftPeriod(period, date, 1))}
        />
      </div>
      <Segmented<BudgetPeriod>
        label="Tipo de presupuesto"
        options={PERIOD_OPTIONS}
        value={period}
        onChange={setPeriod}
      />
      <CreateSection title="Nuevo presupuesto" hasData={!!budgets?.length}>
        <BudgetForm
          key={`${period}-${formKey}`}
          period={period}
          initial={{ category_id: '', amount: '', recurring: true }}
          submitLabel="Añadir"
          pending={create.isPending}
          error={create.error}
          onSubmit={(d) =>
            create.mutate(
              {
                category_id: d.category_id || null,
                period,
                start: date,
                amount: d.amount,
                recurring: d.recurring,
              },
              { onSuccess: () => setFormKey((k) => k + 1) },
            )
          }
        />
      </CreateSection>
      {isLoading ? (
        <Skeleton lines={2} />
      ) : !sorted.length ? (
        <Card>
          <Empty>
            {period === 'day'
              ? 'No hay presupuesto para este día.'
              : period === 'week'
                ? 'No hay presupuesto para esta semana.'
                : 'No hay presupuestos para este mes.'}{' '}
            Crea uno general para controlar todo lo que gastas, o uno por categoría.
          </Empty>
        </Card>
      ) : (
        <ul className="cr-stack cr-plain-list">
          {sorted.map((b) => (
            <li key={b.id}>
              <BudgetBar
                label={nameOf(b)}
                spent={Number(b.spent)}
                limit={Number(b.amount)}
                currency={currency}
                actions={
                  <span className="cr-actions-inline">
                    {b.recurring && (
                      <Badge icon="restore">{`Se repite ${EVERY[b.period as BudgetPeriod]}`}</Badge>
                    )}
                    <Button
                      variant="ghost"
                      size="sm"
                      icon="edit"
                      aria-label={`Editar ${nameOf(b)}`}
                      onClick={() => setEditing(b)}
                    />
                    <Button variant="danger" size="sm" onClick={() => setPending(b)}>
                      Eliminar
                    </Button>
                  </span>
                }
              />
            </li>
          ))}
        </ul>
      )}
      <FormDialog
        open={!!editing}
        title={`Editar presupuesto · ${editing ? nameOf(editing) : ''}`}
        onClose={() => setEditing(null)}
      >
        {editing && (
          <BudgetForm
            key={editing.id}
            period={editing.period as BudgetPeriod}
            initial={{
              category_id: editing.category_id ?? '',
              amount: String(Number(editing.amount)),
              recurring: !!editing.recurring,
            }}
            submitLabel="Guardar"
            pending={update.isPending}
            error={update.error}
            onCancel={() => setEditing(null)}
            onSubmit={(d) =>
              update.mutate(
                {
                  // Solo lo que cambió
                  id: editing.id,
                  ...(Number(d.amount) !== Number(editing.amount) && { amount: d.amount }),
                  ...((d.category_id || null) !== editing.category_id && {
                    category_id: d.category_id || null,
                  }),
                  ...(d.recurring !== !!editing.recurring && { recurring: d.recurring }),
                },
                { onSuccess: () => setEditing(null) },
              )
            }
          />
        )}
      </FormDialog>
      <ConfirmDialog
        open={!!pending}
        title={`¿Eliminar el presupuesto de ${pending ? nameOf(pending).toLowerCase() : ''}?`}
        onCancel={() => setPending(null)}
        onConfirm={() => {
          if (pending) remove.mutate(pending.id)
          setPending(null)
        }}
      >
        {pending?.recurring ? 'Se repite: dejará de aplicarse en todos los periodos.' : undefined}
      </ConfirmDialog>
    </>
  )
}
