import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import { z } from 'zod'
import {
  useAccounts,
  useCategories,
  useCreateRecurring,
  useDeleteRecurring,
  useRecurring,
  useUpdateRecurring,
  type Recurring,
} from '../api/hooks'
import {
  Badge,
  Button,
  Card,
  ConfirmDialog,
  Empty,
  ErrorText,
  FormDialog,
  Glass,
  Input,
  Select,
  Skeleton,
  TransactionRow,
  CreateSection,
  PageTitle,
} from '../design'
import { CategorySelect } from '../features/CategorySelect'
import { formatDate, todayISO } from '../lib/format'

const FREQUENCY_LABELS = {
  weekly: 'Cada semana',
  monthly: 'Cada mes',
  yearly: 'Cada año',
} as const
const TYPE_LABELS = { income: 'Ingreso', expense: 'Gasto', transfer: 'Transferencia' } as const

const schema = z
  .object({
    type: z.enum(['income', 'expense', 'transfer']),
    account_id: z.string().min(1, 'Elige una cuenta'),
    transfer_account_id: z.string().optional(),
    category_id: z.string().optional(),
    amount: z.string().regex(/^\d+(\.\d{1,2})?$/, 'Monto positivo con hasta 2 decimales'),
    description: z.string().max(255),
    frequency: z.enum(['weekly', 'monthly', 'yearly']),
    start_date: z.string().min(1, 'Requerida'),
    end_date: z.string().optional(),
  })
  .refine((d) => d.type !== 'transfer' || !!d.transfer_account_id, {
    path: ['transfer_account_id'],
    message: 'Elige la cuenta destino',
  })
  .refine((d) => !d.end_date || d.end_date >= d.start_date, {
    path: ['end_date'],
    message: 'La fecha final no puede ser anterior a la inicial',
  })

export function RecurringPage() {
  const { data: rules, isLoading } = useRecurring()
  const { data: accounts = [] } = useAccounts(true)
  const { data: categories = [] } = useCategories()
  const create = useCreateRecurring()
  const update = useUpdateRecurring()
  const remove = useDeleteRecurring()
  const [pendingDelete, setPendingDelete] = useState<Recurring | null>(null)
  const [editing, setEditing] = useState<Recurring | null>(null)
  const { register, handleSubmit, reset, control, formState } = useForm({
    resolver: zodResolver(schema),
    defaultValues: {
      type: 'expense' as const,
      frequency: 'monthly' as const,
      start_date: todayISO(),
      description: '',
    },
  })
  const type = useWatch({ control, name: 'type' })
  const accountById = new Map(accounts.map((a) => [a.id, a]))
  const categoryName = new Map(categories.map((c) => [c.id, c.name]))

  return (
    <>
      <PageTitle title="Recurrentes" headline="Lo que se repite, *se registra solo*." />
      <CreateSection title="Nuevo movimiento recurrente" hasData={!!rules?.length}>
        <form
          className="cr-stack"
          onSubmit={handleSubmit((d) =>
            create.mutate(
              {
                ...d,
                transfer_account_id: d.type === 'transfer' ? d.transfer_account_id : null,
                category_id: d.type === 'transfer' || !d.category_id ? null : d.category_id,
                end_date: d.end_date || null,
              },
              { onSuccess: () => reset() },
            ),
          )}
        >
          <div className="cr-form-grid">
            <Select label="Tipo" {...register('type')}>
              {Object.entries(TYPE_LABELS).map(([v, l]) => (
                <option key={v} value={v}>
                  {l}
                </option>
              ))}
            </Select>
            <Select
              label={type === 'transfer' ? 'Cuenta origen' : 'Cuenta'}
              error={formState.errors.account_id?.message}
              {...register('account_id')}
            >
              <option value="">Selecciona…</option>
              {accounts
                .filter((a) => !a.archived)
                .map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.name} ({a.currency})
                  </option>
                ))}
            </Select>
            {type === 'transfer' ? (
              <Select
                label="Cuenta destino"
                error={formState.errors.transfer_account_id?.message}
                {...register('transfer_account_id')}
              >
                <option value="">Selecciona…</option>
                {accounts
                  .filter((a) => !a.archived)
                  .map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.name} ({a.currency})
                    </option>
                  ))}
              </Select>
            ) : (
              <CategorySelect kind={type} {...register('category_id')} />
            )}
            <Input
              label="Monto"
              inputMode="decimal"
              error={formState.errors.amount?.message}
              {...register('amount')}
            />
            <Select label="Frecuencia" {...register('frequency')}>
              {Object.entries(FREQUENCY_LABELS).map(([v, l]) => (
                <option key={v} value={v}>
                  {l}
                </option>
              ))}
            </Select>
            <Input
              label="Primera fecha"
              type="date"
              error={formState.errors.start_date?.message}
              {...register('start_date')}
            />
            <Input
              label="Hasta (opcional)"
              type="date"
              error={formState.errors.end_date?.message}
              {...register('end_date')}
            />
            <Input
              label="Descripción"
              error={formState.errors.description?.message}
              {...register('description')}
            />
          </div>
          <div>
            <Button type="submit" variant="primary" disabled={create.isPending}>
              Crear recurrente
            </Button>
          </div>
          <ErrorText error={create.error} />
        </form>
      </CreateSection>

      {isLoading ? (
        <Skeleton lines={3} />
      ) : !rules?.length ? (
        <Card>
          <Empty>
            Aún no tienes movimientos recurrentes. Crea uno para tu sueldo, arriendo o
            suscripciones.
          </Empty>
        </Card>
      ) : (
        <Glass size="md" className="cr-list" role="list" aria-label="Movimientos recurrentes">
          {rules.map((r) => {
            const account = accountById.get(r.account_id)
            const category = r.category_id ? categoryName.get(r.category_id) : undefined
            return (
              <TransactionRow
                key={r.id}
                kind={r.type}
                title={r.description || category || TYPE_LABELS[r.type]}
                detail={[
                  FREQUENCY_LABELS[r.frequency],
                  r.active ? `próximo: ${formatDate(r.next_date)}` : 'pausado',
                  account?.name,
                ].join(' · ')}
                amount={Number(r.amount)}
                currency={account?.currency}
                actions={
                  <>
                    {!r.active && <Badge>Pausado</Badge>}
                    <Button
                      variant="ghost"
                      size="sm"
                      icon="edit"
                      aria-label={`Editar ${r.description || category || TYPE_LABELS[r.type]}`}
                      onClick={() => setEditing(r)}
                    />
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => update.mutate({ id: r.id, active: !r.active })}
                      aria-label={`${r.active ? 'Pausar' : 'Reanudar'} ${r.description || category || TYPE_LABELS[r.type]}`}
                    >
                      {r.active ? 'Pausar' : 'Reanudar'}
                    </Button>
                    <Button
                      variant="danger"
                      size="sm"
                      icon="trash"
                      aria-label="Eliminar"
                      onClick={() => setPendingDelete(r)}
                    />
                  </>
                }
              />
            )
          })}
        </Glass>
      )}
      <FormDialog
        open={!!editing}
        title="Editar movimiento recurrente"
        onClose={() => setEditing(null)}
      >
        {editing && (
          <RecurringEditForm
            key={editing.id}
            rule={editing}
            accounts={accounts.filter((a) => !a.archived || a.id === editing.account_id)}
            pending={update.isPending}
            error={update.error}
            onCancel={() => setEditing(null)}
            onSubmit={(changes) =>
              update.mutate({ id: editing.id, ...changes }, { onSuccess: () => setEditing(null) })
            }
          />
        )}
      </FormDialog>
      <ConfirmDialog
        open={!!pendingDelete}
        title="¿Eliminar este movimiento recurrente?"
        onCancel={() => setPendingDelete(null)}
        onConfirm={() => {
          if (pendingDelete) remove.mutate(pendingDelete.id)
          setPendingDelete(null)
        }}
      >
        Los movimientos ya registrados se conservan; solo dejará de generar nuevos.
      </ConfirmDialog>
      <ErrorText error={update.error ?? remove.error} />
    </>
  )
}

type RecurringChanges = {
  amount?: string
  description?: string
  account_id?: string
  category_id?: string | null
  next_date?: string
  end_date?: string | null
}

/** Editar un recurrente: monto, nota, cuenta, categoría y fechas (el próximo cobro fija el día). */
function RecurringEditForm(props: {
  rule: Recurring
  accounts: { id: string; name: string; currency: string }[]
  pending: boolean
  error: unknown
  onCancel: () => void
  onSubmit: (changes: RecurringChanges) => void
}) {
  const r = props.rule
  const [amount, setAmount] = useState(String(Number(r.amount)))
  const [description, setDescription] = useState(r.description)
  const [account, setAccount] = useState(r.account_id)
  const [category, setCategory] = useState(r.category_id ?? '')
  const [next, setNext] = useState(r.next_date)
  const [end, setEnd] = useState(r.end_date ?? '')
  const [problem, setProblem] = useState<string | null>(null)
  return (
    <form
      className="cr-stack"
      onSubmit={(e) => {
        e.preventDefault()
        const value = amount.trim().replace(',', '.')
        if (!/^\d+(\.\d{1,2})?$/.test(value) || Number(value) <= 0) {
          setProblem('Monto positivo con hasta 2 decimales')
          return
        }
        setProblem(null)
        props.onSubmit({
          ...(Number(value) !== Number(r.amount) && { amount: value }),
          ...(description !== r.description && { description }),
          ...(account !== r.account_id && { account_id: account }),
          ...(r.type !== 'transfer' &&
            category !== (r.category_id ?? '') && { category_id: category || null }),
          ...(next !== r.next_date && { next_date: next }),
          ...(end !== (r.end_date ?? '') && { end_date: end || null }),
        })
      }}
    >
      <div className="cr-form-grid">
        <Input
          label="Monto"
          inputMode="decimal"
          value={amount}
          error={problem ?? undefined}
          onChange={(e) => setAmount(e.target.value)}
        />
        <Input
          label="Descripción"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
        <Select label="Cuenta" value={account} onChange={(e) => setAccount(e.target.value)}>
          {props.accounts.map((a) => (
            <option key={a.id} value={a.id}>
              {a.name} ({a.currency})
            </option>
          ))}
        </Select>
        {r.type !== 'transfer' && (
          <CategorySelect
            kind={r.type === 'income' ? 'income' : 'expense'}
            value={category}
            onChange={(e) => setCategory(e.target.value)}
          />
        )}
        <Input
          label="Próximo cobro"
          type="date"
          value={next}
          onChange={(e) => setNext(e.target.value)}
        />
        <Input
          label="Hasta (opcional)"
          type="date"
          value={end}
          onChange={(e) => setEnd(e.target.value)}
        />
      </div>
      <ErrorText error={props.error} />
      <div className="cr-dialog-actions">
        <Button variant="ghost" onClick={props.onCancel}>
          Cancelar
        </Button>
        <Button type="submit" variant="primary" disabled={props.pending}>
          Guardar
        </Button>
      </div>
    </form>
  )
}
