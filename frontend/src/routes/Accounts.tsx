import { zodResolver } from '@hookform/resolvers/zod'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { useAccounts, useCreateAccount, useUpdateAccount } from '../api/hooks'
import { Button, Card, Empty, ErrorText, Glass, Icon, Input, Select } from '../design'
import { formatMoney } from '../lib/format'

const schema = z.object({
  name: z.string().min(1, 'Requerido').max(80),
  type: z.enum(['cash', 'bank', 'card', 'savings']),
  currency: z.string().regex(/^[A-Za-z]{3}$/, 'Código de 3 letras (ISO 4217)'),
  initial_balance: z.string().regex(/^-?\d+(\.\d{1,2})?$/, 'Número con hasta 2 decimales'),
})

const TYPE_LABELS = { cash: 'Efectivo', bank: 'Banco', card: 'Tarjeta', savings: 'Ahorro' } as const

export function AccountsPage() {
  const { data: accounts, isLoading } = useAccounts(true)
  const create = useCreateAccount()
  const update = useUpdateAccount()
  const { register, handleSubmit, reset, formState } = useForm({
    resolver: zodResolver(schema),
    defaultValues: { type: 'bank' as const, initial_balance: '0' },
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
            <Input
              label="Moneda"
              maxLength={3}
              placeholder="ISO 4217"
              error={formState.errors.currency?.message}
              {...register('currency')}
            />
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
      {isLoading ? (
        <Empty>Cargando…</Empty>
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
                <span className="cr-chip cr-chip-mint">
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
                  onClick={() => update.mutate({ id: a.id, archived: !a.archived })}
                >
                  {a.archived ? 'Restaurar' : 'Archivar'}
                </Button>
              </div>
            </li>
          ))}
        </Glass>
      )}
    </>
  )
}
