import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { useBudgets, useCategories, useCreateBudget, useDeleteBudget } from '../api/hooks'
import { Button, Card, Empty, ErrorText, Input, Select } from '../components/ui'
import { monthStart } from '../lib/format'
import { money, useDisplayCurrency } from '../lib/useCurrency'

const schema = z.object({
  category_id: z.string().min(1, 'Elige una categoría'),
  amount: z.string().regex(/^\d+(\.\d{1,2})?$/, 'Monto positivo con hasta 2 decimales'),
})

export function BudgetsPage() {
  const [month, setMonth] = useState(monthStart())
  const currency = useDisplayCurrency()
  const { data: budgets, isLoading } = useBudgets(month)
  const { data: categories = [] } = useCategories()
  const create = useCreateBudget()
  const remove = useDeleteBudget()
  const { register, handleSubmit, reset, formState } = useForm({ resolver: zodResolver(schema) })
  const names = new Map(categories.map((c) => [c.id, c.name]))

  return (
    <>
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold">Presupuestos</h1>
        <input
          type="month"
          aria-label="Mes"
          className="rounded-md border border-slate-300 px-3 py-2 text-sm"
          value={month.slice(0, 7)}
          onChange={(e) => e.target.value && setMonth(`${e.target.value}-01`)}
        />
      </div>
      <Card title="Nuevo presupuesto">
        <form
          className="grid gap-3 sm:grid-cols-3"
          onSubmit={handleSubmit((d) =>
            create.mutate({ ...d, month }, { onSuccess: () => reset() }),
          )}
        >
          <Select
            label="Categoría de gasto"
            error={formState.errors.category_id?.message}
            {...register('category_id')}
          >
            <option value="">Selecciona…</option>
            {categories
              .filter((c) => c.kind === 'expense')
              .map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
          </Select>
          <Input
            label="Monto"
            inputMode="decimal"
            error={formState.errors.amount?.message}
            {...register('amount')}
          />
          <div className="flex items-end">
            <Button type="submit" disabled={create.isPending}>
              Añadir
            </Button>
          </div>
        </form>
        <ErrorText error={create.error} />
      </Card>
      <Card>
        {isLoading ? (
          <Empty>Cargando…</Empty>
        ) : !budgets?.length ? (
          <Empty>No hay presupuestos para este mes.</Empty>
        ) : (
          <ul className="space-y-4">
            {budgets.map((b) => {
              const pct = Math.min(100, (Number(b.spent) / Number(b.amount)) * 100)
              const over = Number(b.remaining) < 0
              return (
                <li key={b.id}>
                  <div className="mb-1 flex items-center justify-between text-sm">
                    <span className="font-medium">{names.get(b.category_id)}</span>
                    <span className={over ? 'text-red-600' : 'text-slate-600'}>
                      {money(b.spent, currency)} / {money(b.amount, currency)}
                    </span>
                  </div>
                  <div
                    role="progressbar"
                    aria-valuenow={Math.round(pct)}
                    aria-valuemin={0}
                    aria-valuemax={100}
                    className="h-2 overflow-hidden rounded bg-slate-200"
                  >
                    <div
                      className={`h-full ${over ? 'bg-red-500' : 'bg-emerald-500'}`}
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                  <div className="mt-1 flex items-center justify-between text-xs text-slate-500">
                    <span>
                      {over ? 'Excedido en' : 'Restante'}{' '}
                      {money(Math.abs(Number(b.remaining)), currency)}
                    </span>
                    <Button variant="danger" onClick={() => remove.mutate(b.id)}>
                      Eliminar
                    </Button>
                  </div>
                </li>
              )
            })}
          </ul>
        )}
      </Card>
    </>
  )
}
