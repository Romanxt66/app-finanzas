import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import { z } from 'zod'
import {
  useAccounts,
  useCategories,
  useDeleteTransaction,
  useSaveTransaction,
  useTransactions,
  type Transaction,
} from '../api/hooks'
import { Button, Card, Empty, ErrorText, Input, Select } from '../components/ui'
import { formatDate, formatMoney, todayISO } from '../lib/format'

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
  const { data: categories = [] } = useCategories()
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
      <form className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3" onSubmit={submit}>
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
          <Select label="Categoría" {...register('category_id')}>
            <option value="">Sin categoría</option>
            {categories
              .filter((c) => c.kind === type)
              .map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
          </Select>
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
        <div className="flex gap-2 sm:col-span-2 lg:col-span-3">
          <Button type="submit" disabled={save.isPending}>
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

export function TransactionsPage() {
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
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold">Transacciones</h1>
        {!form && <Button onClick={() => setForm({ editing: null })}>Nueva</Button>}
      </div>
      {form && (
        <TransactionForm
          key={form.editing?.id ?? 'new'}
          editing={form.editing}
          onDone={() => setForm(null)}
        />
      )}
      <Card>
        <div className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
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
        {isLoading ? (
          <Empty>Cargando…</Empty>
        ) : !data?.items.length ? (
          <Empty>No hay transacciones.</Empty>
        ) : (
          <ul className="divide-y divide-slate-100">
            {data.items.map((t) => {
              const account = accountById.get(t.account_id)
              const sign = t.type === 'income' ? '+' : t.type === 'expense' ? '−' : ''
              const tone =
                t.type === 'income'
                  ? 'text-emerald-700'
                  : t.type === 'expense'
                    ? 'text-red-600'
                    : 'text-slate-600'
              return (
                <li key={t.id} className="flex items-center justify-between gap-3 py-3">
                  <div>
                    <p className="font-medium">
                      {t.description ||
                        (t.category_id && categoryById.get(t.category_id)) ||
                        TYPE_LABELS[t.type]}
                    </p>
                    <p className="text-xs text-slate-500">
                      {formatDate(t.occurred_on)} · {account?.name}
                      {t.transfer_account_id &&
                        ` → ${accountById.get(t.transfer_account_id)?.name}`}
                      {t.category_id && ` · ${categoryById.get(t.category_id)}`}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`font-semibold tabular-nums ${tone}`}>
                      {sign}
                      {account ? formatMoney(t.amount, account.currency) : t.amount}
                    </span>
                    <Button variant="ghost" onClick={() => setForm({ editing: t })}>
                      Editar
                    </Button>
                    <Button variant="danger" onClick={() => remove.mutate(t.id)}>
                      Eliminar
                    </Button>
                  </div>
                </li>
              )
            })}
          </ul>
        )}
        <ErrorText error={remove.error} />
        <div className="mt-4 flex items-center justify-between text-sm">
          <span className="text-slate-500">{data?.total ?? 0} resultados</span>
          <div className="flex items-center gap-2">
            <Button variant="ghost" disabled={page === 0} onClick={() => setPage(page - 1)}>
              Anterior
            </Button>
            <span>
              {page + 1} / {pages}
            </span>
            <Button variant="ghost" disabled={page + 1 >= pages} onClick={() => setPage(page + 1)}>
              Siguiente
            </Button>
          </div>
        </div>
      </Card>
    </>
  )
}
