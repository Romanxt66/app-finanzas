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
  CreateSection,
  PageTitle,
} from '../design'
import { CurrencySelect } from '../features/CurrencySelect'
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
      <PageTitle title="Cuentas" headline="Tus cuentas, *de un vistazo*." />
      <CreateSection title="Nueva cuenta" hasData={!!accounts?.length}>
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
      </CreateSection>
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
                  aria-label={`Editar ${a.name}`}
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
      <FormDialog open={!!renaming} title="Editar cuenta" onClose={() => setRenaming(null)}>
        {renaming && (
          <AccountEditForm
            key={renaming.id}
            account={renaming}
            pending={update.isPending}
            error={update.error}
            onCancel={() => setRenaming(null)}
            onSubmit={(changes) =>
              update.mutate({ id: renaming.id, ...changes }, { onSuccess: () => setRenaming(null) })
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

/** Editar una cuenta: nombre, tipo y saldo real de hoy (se cuadra sin inventar movimientos). */
function AccountEditForm(props: {
  account: Account
  pending: boolean
  error: unknown
  onCancel: () => void
  onSubmit: (changes: { name?: string; type?: Account['type']; balance?: string }) => void
}) {
  const a = props.account
  const [name, setName] = useState(a.name)
  const [type, setType] = useState<Account['type']>(a.type)
  const [balance, setBalance] = useState(String(Number(a.balance)))
  const [problem, setProblem] = useState<{ name?: string; balance?: string }>({})
  return (
    <form
      className="cr-stack"
      onSubmit={(e) => {
        e.preventDefault()
        const value = balance.trim().replace(',', '.')
        const errors = {
          name: name.trim() ? undefined : 'Escribe un nombre',
          balance: /^-?\d+(\.\d{1,2})?$/.test(value) ? undefined : 'Saldo con hasta 2 decimales',
        }
        setProblem(errors)
        if (errors.name || errors.balance) return
        // Solo se envía lo que cambió
        props.onSubmit({
          ...(name.trim() !== a.name && { name: name.trim() }),
          ...(type !== a.type && { type }),
          ...(Number(value) !== Number(a.balance) && { balance: value }),
        })
      }}
    >
      <Input
        label="Nombre"
        value={name}
        error={problem.name}
        onChange={(e) => setName(e.target.value)}
      />
      <Select
        label="Tipo"
        value={type}
        onChange={(e) => setType(e.target.value as Account['type'])}
      >
        {Object.entries(TYPE_LABELS).map(([v, l]) => (
          <option key={v} value={v}>
            {l}
          </option>
        ))}
      </Select>
      <Input
        label={`Saldo actual (${a.currency})`}
        inputMode="decimal"
        value={balance}
        error={problem.balance}
        onChange={(e) => setBalance(e.target.value)}
      />
      <p className="caption cr-muted cr-tight">
        Si cambias el saldo se ajusta el saldo inicial; tus movimientos no se tocan.
      </p>
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
