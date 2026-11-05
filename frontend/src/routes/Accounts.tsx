import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import {
  useAccounts,
  useCreateAccount,
  useDeleteAccount,
  useUpdateAccount,
  type Account,
} from '../api/hooks'
import {
  Button,
  Card,
  Empty,
  ErrorText,
  Glass,
  Icon,
  Input,
  Select,
  Skeleton,
  ConfirmDialog,
  Donut,
  DONUT_COLORS,
  FormDialog,
} from '../design'
import { CurrencySelect } from '../features/CurrencySelect'
import { RenameForm } from '../features/RenameForm'
import { formatMoney } from '../lib/format'

const schema = z.object({
  name: z.string().min(1, 'Requerido').max(80),
  type: z.enum(['cash', 'bank', 'card', 'savings']),
  currency: z.string().min(1, 'Selecciona una moneda'),
  initial_balance: z.string().regex(/^-?\d+(\.\d{1,2})?$/, 'Número con hasta 2 decimales'),
})

const TYPE_LABELS = { cash: 'Efectivo', bank: 'Banco', card: 'Tarjeta', savings: 'Ahorro' } as const

export function AccountsPage() {
  const { data: accounts, isLoading } = useAccounts(true)
  const create = useCreateAccount()
  const update = useUpdateAccount()
  const remove = useDeleteAccount()
  const [renaming, setRenaming] = useState<Account | null>(null)
  const [pendingDelete, setPendingDelete] = useState<Account | null>(null)
  const { register, handleSubmit, reset, formState } = useForm({
    resolver: zodResolver(schema),
    defaultValues: { type: 'bank' as const, currency: '', initial_balance: '0' },
  })

  return (
    <>
      <h1 className="title">Cuentas</h1>
      <Card title="Nueva cuenta">
        <form
          className="cr-stack"
          onSubmit={handleSubmit((d) => create.mutate(d, { onSuccess: () => reset() }))}
        >
          <div className="cr-form-grid">
            <Input label="Nombre" error={formState.errors.name?.message} {...register('name')} />
            <Select label="Tipo" {...register('type')}>
              {Object.entries(TYPE_LABELS).map(([v, l]) => (
                <option key={v} value={v}>
                  {l}
                </option>
              ))}
            </Select>
            <CurrencySelect error={formState.errors.currency?.message} {...register('currency')} />
            <Input
              label="Saldo inicial"
              inputMode="decimal"
              error={formState.errors.initial_balance?.message}
              {...register('initial_balance')}
            />
          </div>
          <div>
            <Button type="submit" variant="primary" disabled={create.isPending}>
              Crear cuenta
            </Button>
          </div>
          <ErrorText error={create.error} />
        </form>
      </Card>
      {!!accounts?.length && <BalancesDonut accounts={accounts} />}
      {isLoading ? (
        <Skeleton lines={3} />
      ) : !accounts?.length ? (
        <Card>
          <Empty>Aún no tienes cuentas.</Empty>
        </Card>
      ) : (
        <Glass
          size="md"
          as="ul"
          style={{ listStyle: 'none', margin: 0, padding: 'var(--space-1) 0' }}
        >
          {accounts.map((a) => (
            <li key={a.id} className={`cr-row-split${a.archived ? ' is-archived' : ''}`}>
              <div className="cr-row" style={{ flexWrap: 'nowrap' }}>
                <span className="cr-chip cr-chip-brand">
                  <Icon name="wallet" />
                </span>
                <div>
                  <p className="body" style={{ margin: 0 }}>
                    {a.name}
                  </p>
                  <p className="caption cr-muted" style={{ margin: 0 }}>
                    {TYPE_LABELS[a.type]} · {a.currency}
                  </p>
                </div>
              </div>
              <div className="cr-row" style={{ flexWrap: 'nowrap' }}>
                <span className="amount-sm">{formatMoney(a.balance, a.currency)}</span>
                <Button
                  variant="ghost"
                  size="sm"
                  icon="edit"
                  aria-label={`Renombrar ${a.name}`}
                  onClick={() => setRenaming(a)}
                />
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => update.mutate({ id: a.id, archived: !a.archived })}
                >
                  {a.archived ? 'Restaurar' : 'Archivar'}
                </Button>
                <Button
                  variant="danger"
                  size="sm"
                  icon="trash"
                  aria-label={`Eliminar ${a.name}`}
                  onClick={() => setPendingDelete(a)}
                />
              </div>
            </li>
          ))}
        </Glass>
      )}
      <FormDialog open={!!renaming} title="Renombrar cuenta" onClose={() => setRenaming(null)}>
        {renaming && (
          <RenameForm
            key={renaming.id}
            initial={renaming.name}
            label="Nombre"
            pending={update.isPending}
            error={update.error}
            onCancel={() => setRenaming(null)}
            onSubmit={(name) =>
              update.mutate({ id: renaming.id, name }, { onSuccess: () => setRenaming(null) })
            }
          />
        )}
      </FormDialog>
      <ConfirmDialog
        open={!!pendingDelete}
        title={`¿Eliminar la cuenta «${pendingDelete?.name}»?`}
        onCancel={() => setPendingDelete(null)}
        onConfirm={() => {
          if (pendingDelete) remove.mutate(pendingDelete.id)
          setPendingDelete(null)
        }}
      >
        Solo se puede eliminar si no tiene movimientos; si los tiene, archívala.
      </ConfirmDialog>
      <ErrorText error={remove.error} />
    </>
  )
}

/** Reparto del saldo entre las cuentas activas (moneda principal), con el total en el centro. */
function BalancesDonut({ accounts }: { accounts: Account[] }) {
  const active = accounts.filter((a) => !a.archived)
  if (!active.length) return null
  const currency = active[0].currency
  const mine = active
    .filter((a) => a.currency === currency)
    .sort((a, b) => Number(b.balance) - Number(a.balance))
  const total = mine.reduce((t, a) => t + Number(a.balance), 0)
  const positive = mine.filter((a) => Number(a.balance) > 0)
  const sum = positive.reduce((t, a) => t + Number(a.balance), 0)
  return (
    <Card title="Saldos">
      <div className="cr-donut-wrap">
        <div className="cr-donut-center">
          <Donut
            size={180}
            label={`Reparto del saldo: ${positive.map((a) => `${a.name} ${Math.round((Number(a.balance) / sum) * 100)} %`).join(', ')}`}
            data={positive.map((a) => ({ key: a.id, value: Number(a.balance) }))}
          />
          <span className="cr-donut-total">
            <span className="caption cr-muted">saldo total</span>
            <strong>{formatMoney(total, currency)}</strong>
          </span>
        </div>
        <div className="cr-donut-legend">
          {mine
            .map((a) => {
              const share = Number(a.balance) > 0 && sum > 0 ? Number(a.balance) / sum : 0
              const idx = positive.findIndex((p) => p.id === a.id)
              return (
                <div key={a.id} className="cr-donut-row">
                  <span
                    className="cr-dot"
                    style={{
                      background:
                        idx >= 0 ? DONUT_COLORS[idx % DONUT_COLORS.length] : 'var(--hairline)',
                    }}
                    aria-hidden="true"
                  />
                  <span className="cr-donut-name">
                    <span className="body">{a.name}</span>
                    <span className="caption cr-muted">
                      {TYPE_LABELS[a.type as keyof typeof TYPE_LABELS] ?? a.type}
                    </span>
                  </span>
                  <span className="cr-donut-amount">
                    <span>{formatMoney(a.balance, a.currency)}</span>
                    <span className="caption cr-muted">{Math.round(share * 100)} %</span>
                  </span>
                </div>
              )
            })
            .slice(0, 8)}
        </div>
      </div>
    </Card>
  )
}
