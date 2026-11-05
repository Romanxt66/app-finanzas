import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import { z } from 'zod'
import {
  useAccounts,
  useCategories,
  useDeleteTransaction,
  useSaveTransaction,
  useSummary,
  useTransactions,
  type Transaction,
} from '../api/hooks'
import { downloadFile } from '../api/client'
import {
  Button,
  Card,
  ConfirmDialog,
  Empty,
  ErrorText,
  Input,
  Select,
  Skeleton,
  TransactionList,
  TransactionRow,
  StatTile,
} from '../design'
import { CategorySelect } from '../features/CategorySelect'
import { WeekStrip } from '../features/WeekStrip'
import { dayLabel } from '../lib/dates'
import { useLifeHoursNote } from '../features/useLifeHoursNote'
import { formatDate, formatMoney, monthStart, todayISO } from '../lib/format'

const PAGE_SIZE = 20
const TYPE_LABELS = { income: 'Ingreso', expense: 'Gasto', transfer: 'Transferencia' } as const

const schema = z
  .object({
    type: z.enum(['income', 'expense', 'transfer']),
    account_id: z.string().min(1, 'Elige una cuenta'),
    transfer_account_id: z.string().optional(),
    category_id: z.string().optional(),
    amount: z.string().regex(/^\d+(\.\d{1,2})?$/, 'Monto positivo con hasta 2 decimales'),
    description: z.string().max(255),
    occurred_on: z.string().min(1, 'Requerida'),
  })
  .refine((d) => d.type !== 'transfer' || !!d.transfer_account_id, {
    path: ['transfer_account_id'],
    message: 'Elige la cuenta destino',
  })

type FormValues = z.infer<typeof schema>

function TransactionForm({ editing, onDone }: { editing: Transaction | null; onDone: () => void }) {
  const { data: accounts = [] } = useAccounts()
  const save = useSaveTransaction()
  const { register, handleSubmit, control, formState } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: editing
      ? {
          type: editing.type,
          account_id: editing.account_id,
          transfer_account_id: editing.transfer_account_id ?? '',
          category_id: editing.category_id ?? '',
          amount: String(editing.amount),
          description: editing.description,
          occurred_on: editing.occurred_on,
        }
      : { type: 'expense', description: '', occurred_on: todayISO(), amount: '' },
  })
  const type = useWatch({ control, name: 'type' })

  const submit = handleSubmit((d) =>
    save.mutate(
      {
        id: editing?.id,
        body: {
          ...d,
          transfer_account_id: d.type === 'transfer' ? d.transfer_account_id : null,
          category_id: d.type === 'transfer' || !d.category_id ? null : d.category_id,
        },
      },
      { onSuccess: onDone },
    ),
  )

  return (
    <Card title={editing ? 'Editar transacción' : 'Nueva transacción'}>
      <form className="cr-stack" onSubmit={submit}>
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
            {accounts.map((a) => (
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
              {accounts.map((a) => (
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
          <Input
            label="Fecha"
            type="date"
            error={formState.errors.occurred_on?.message}
            {...register('occurred_on')}
          />
          <Input
            label="Descripción"
            error={formState.errors.description?.message}
            {...register('description')}
          />
        </div>
        <div className="cr-row">
          <Button type="submit" variant="primary" disabled={save.isPending}>
            Guardar
          </Button>
          <Button type="button" variant="ghost" onClick={onDone}>
            Cancelar
          </Button>
        </div>
      </form>
      <ErrorText error={save.error} />
    </Card>
  )
}

/** Movimientos agrupados por día, en el orden en que llegan (del más reciente al más antiguo). */
function groupByDay(items: Transaction[]): [string, Transaction[]][] {
  const days = new Map<string, Transaction[]>()
  for (const t of items) {
    const day = t.occurred_on.slice(0, 10)
    days.set(day, [...(days.get(day) ?? []), t])
  }
  return [...days.entries()]
}

/** Neto del día (ingresos − gastos) si todo va en la misma moneda; las transferencias no cuentan. */
function dayNet(items: Transaction[], accounts: Map<string, { currency: string }>): string | null {
  const currencies = new Set(items.map((t) => accounts.get(t.account_id)?.currency))
  if (currencies.size !== 1) return null
  const net = items.reduce(
    (n, t) =>
      n + (t.type === 'income' ? Number(t.amount) : t.type === 'expense' ? -Number(t.amount) : 0),
    0,
  )
  return net ? formatMoney(net, [...currencies][0], { signed: true }) : null
}

/** Ingresos y gastos del mes en curso, arriba del historial. */
function MonthTotals() {
  const { data } = useSummary(monthStart())
  if (!data) return null
  return (
    <div className="cr-grid-kpi">
      <StatTile
        label="Ingresos del mes"
        value={Number(data.income)}
        currency={data.currency ?? undefined}
        icon="up"
      />
      <StatTile
        label="Gastos del mes"
        value={-Number(data.expense)}
        currency={data.currency ?? undefined}
        icon="down"
        tone="negative"
      />
    </div>
  )
}

export function TransactionsPage() {
  const lifeNote = useLifeHoursNote()
  const [filters, setFilters] = useState({
    search: '',
    type: '',
    account_id: '',
    date_from: '',
    date_to: '',
  })
  const [page, setPage] = useState(0)
  const [form, setForm] = useState<{ editing: Transaction | null } | null>(null)
  const { data: accounts = [] } = useAccounts(true)
  const { data: categories = [] } = useCategories()
  const { data, isLoading } = useTransactions({
    ...Object.fromEntries(Object.entries(filters).filter(([, v]) => v)),
    limit: PAGE_SIZE,
    offset: page * PAGE_SIZE,
  })
  const remove = useDeleteTransaction()
  const [exporting, setExporting] = useState(false)
  const [exportError, setExportError] = useState<unknown>(null)
  const [pendingDelete, setPendingDelete] = useState<Transaction | null>(null)

  const accountById = new Map(accounts.map((a) => [a.id, a]))
  const categoryById = new Map(categories.map((c) => [c.id, c.name]))
  const setFilter =
    (key: keyof typeof filters) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
      setFilters((f) => ({ ...f, [key]: e.target.value }))
      setPage(0)
    }
  const pages = data ? Math.max(1, Math.ceil(data.total / PAGE_SIZE)) : 1

  return (
    <>
      <div className="cr-page-head">
        <h1 className="title">Movimientos</h1>
        <div className="cr-row">
          <Button
            variant="ghost"
            icon="download"
            disabled={exporting}
            onClick={async () => {
              setExporting(true)
              setExportError(null)
              try {
                await downloadFile(
                  '/transactions/export',
                  Object.fromEntries(Object.entries(filters).filter(([, v]) => v)),
                  'movimientos.csv',
                )
              } catch (e) {
                setExportError(e)
              } finally {
                setExporting(false)
              }
            }}
          >
            Exportar CSV
          </Button>
          {!form && (
            <Button variant="primary" icon="plus" onClick={() => setForm({ editing: null })}>
              Nueva
            </Button>
          )}
        </div>
      </div>
      <ErrorText error={exportError} />
      {form && (
        <TransactionForm
          key={form.editing?.id ?? 'new'}
          editing={form.editing}
          onDone={() => setForm(null)}
        />
      )}
      <Card title="Filtros">
        <div className="cr-form-grid">
          <Input label="Buscar" value={filters.search} onChange={setFilter('search')} />
          <Select label="Tipo" value={filters.type} onChange={setFilter('type')}>
            <option value="">Todos</option>
            {Object.entries(TYPE_LABELS).map(([v, l]) => (
              <option key={v} value={v}>
                {l}
              </option>
            ))}
          </Select>
          <Select label="Cuenta" value={filters.account_id} onChange={setFilter('account_id')}>
            <option value="">Todas</option>
            {accounts.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name}
              </option>
            ))}
          </Select>
          <Input
            label="Desde"
            type="date"
            value={filters.date_from}
            onChange={setFilter('date_from')}
          />
          <Input
            label="Hasta"
            type="date"
            value={filters.date_to}
            onChange={setFilter('date_to')}
          />
        </div>
      </Card>
      <MonthTotals />
      <WeekStrip
        selected={
          filters.date_from && filters.date_from === filters.date_to ? filters.date_from : null
        }
        marked={new Set(data?.items.map((t) => t.occurred_on.slice(0, 10)) ?? [])}
        onChange={(day) => {
          setFilters((f) => ({ ...f, date_from: day ?? '', date_to: day ?? '' }))
          setPage(0)
        }}
      />
      {isLoading ? (
        <Skeleton lines={4} />
      ) : !data?.items.length ? (
        <Card>
          <Empty>No hay transacciones.</Empty>
        </Card>
      ) : (
        groupByDay(data.items).map(([day, items]) => {
          const { date, name } = dayLabel(day)
          return (
            <section key={day} aria-label={`${date}, ${name}`}>
              <div className="cr-day-head">
                <h2>{date}</h2>
                <span className="caption cr-muted">{name}</span>
                <span className="caption cr-muted cr-day-total">{dayNet(items, accountById)}</span>
              </div>
              <TransactionList label={`Movimientos del ${date}`}>
                {items.map((t) => {
                  const account = accountById.get(t.account_id)
                  const category = t.category_id ? categoryById.get(t.category_id) : undefined
                  const target = t.transfer_account_id
                    ? accountById.get(t.transfer_account_id)?.name
                    : undefined
                  return (
                    <TransactionRow
                      key={t.id}
                      kind={t.type}
                      title={t.description || category || TYPE_LABELS[t.type]}
                      detail={[
                        formatDate(t.occurred_on),
                        target ? `${account?.name} → ${target}` : account?.name,
                        category,
                        t.type === 'expense'
                          ? lifeNote(Number(t.amount), account?.currency)
                          : undefined,
                      ]
                        .filter(Boolean)
                        .join(' · ')}
                      amount={Number(t.amount)}
                      currency={account?.currency}
                      actions={
                        <>
                          <Button
                            variant="ghost"
                            size="sm"
                            icon="edit"
                            aria-label="Editar"
                            onClick={() => setForm({ editing: t })}
                          />
                          <Button
                            variant="danger"
                            size="sm"
                            icon="trash"
                            aria-label="Eliminar"
                            onClick={() => setPendingDelete(t)}
                          />
                        </>
                      }
                    />
                  )
                })}
              </TransactionList>
            </section>
          )
        })
      )}
      <ConfirmDialog
        open={!!pendingDelete}
        title="¿Eliminar este movimiento?"
        onCancel={() => setPendingDelete(null)}
        onConfirm={() => {
          if (pendingDelete) remove.mutate(pendingDelete.id)
          setPendingDelete(null)
        }}
      >
        Se ajustará el saldo de la cuenta. Esta acción no se puede deshacer.
      </ConfirmDialog>
      <ErrorText error={remove.error} />
      <div className="cr-pagination">
        <span className="label cr-muted">{data?.total ?? 0} resultados</span>
        <div className="cr-row">
          <Button variant="ghost" size="sm" disabled={page === 0} onClick={() => setPage(page - 1)}>
            Anterior
          </Button>
          <span className="label">
            {page + 1} / {pages}
          </span>
          <Button
            variant="ghost"
            size="sm"
            disabled={page + 1 >= pages}
            onClick={() => setPage(page + 1)}
          >
            Siguiente
          </Button>
        </div>
      </div>
    </>
  )
}
