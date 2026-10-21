import { zodResolver } from '@hookform/resolvers/zod'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { useAccounts, useCreateAccount, useUpdateAccount } from '../api/hooks'
import { Button, Card, Empty, ErrorText, Input, Select } from '../components/ui'
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
      <h1 className="text-xl font-bold">Cuentas</h1>
      <Card title="Nueva cuenta">
        <form
          className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4"
          onSubmit={handleSubmit((d) => create.mutate(d, { onSuccess: () => reset() }))}
        >
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
          <div className="sm:col-span-2 lg:col-span-4">
            <Button type="submit" disabled={create.isPending}>
              Crear cuenta
            </Button>
            <ErrorText error={create.error} />
          </div>
        </form>
      </Card>
      <Card>
        {isLoading ? (
          <Empty>Cargando…</Empty>
        ) : !accounts?.length ? (
          <Empty>Aún no tienes cuentas.</Empty>
        ) : (
          <ul className="divide-y divide-slate-100">
            {accounts.map((a) => (
              <li key={a.id} className="flex items-center justify-between gap-3 py-3">
                <div className={a.archived ? 'opacity-50' : ''}>
                  <p className="font-medium">{a.name}</p>
                  <p className="text-xs text-slate-500">
                    {TYPE_LABELS[a.type]} · {a.currency}
                  </p>
                </div>
                <div className="flex items-center gap-3">
                  <span className="font-semibold tabular-nums">
                    {formatMoney(a.balance, a.currency)}
                  </span>
                  <Button
                    variant="ghost"
                    onClick={() => update.mutate({ id: a.id, archived: !a.archived })}
                  >
                    {a.archived ? 'Restaurar' : 'Archivar'}
                  </Button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </>
  )
}
