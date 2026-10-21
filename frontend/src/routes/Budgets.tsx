import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { useBudgets, useCategories, useCreateBudget, useDeleteBudget } from '../api/hooks'
import {
  BudgetBar,
  Button,
  Card,
  ConfirmDialog,
  Empty,
  ErrorText,
  Input,
  Select,
  Skeleton,
} from '../design'
import { monthStart } from '../lib/format'
import { useDisplayCurrency } from '../lib/useCurrency'

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
  const [pending, setPending] = useState<{ id: string; name: string } | null>(null)
  const { register, handleSubmit, reset, formState } = useForm({ resolver: zodResolver(schema) })
  const names = new Map(categories.map((c) => [c.id, c.name]))

  return (
    <>
      <div className="cr-page-head">
        <h1 className="title">Presupuestos</h1>
        <div className="cr-month">
          <Input
            label="Mes"
            type="month"
            value={month.slice(0, 7)}
            onChange={(e) => e.target.value && setMonth(`${e.target.value}-01`)}
          />
        </div>
      </div>
      <Card title="Nuevo presupuesto">
        <form
          className="cr-stack"
          onSubmit={handleSubmit((d) =>
            create.mutate({ ...d, month }, { onSuccess: () => reset() }),
          )}
        >
          <div className="cr-form-grid">
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
          </div>
          <div>
            <Button type="submit" variant="primary" disabled={create.isPending}>
              Añadir
            </Button>
          </div>
          <ErrorText error={create.error} />
        </form>
      </Card>
      {isLoading ? (
        <Skeleton lines={2} />
      ) : !budgets?.length ? (
        <Card>
          <Empty>No hay presupuestos para este mes.</Empty>
        </Card>
      ) : (
        <ul className="cr-stack" style={{ listStyle: 'none', margin: 0, padding: 0 }}>
          {budgets.map((b) => (
            <li key={b.id}>
              <BudgetBar
                label={names.get(b.category_id) ?? 'Categoría'}
                spent={Number(b.spent)}
                limit={Number(b.amount)}
                currency={currency}
                actions={
                  <Button
                    variant="danger"
                    size="sm"
                    onClick={() =>
                      setPending({ id: b.id, name: names.get(b.category_id) ?? 'este presupuesto' })
                    }
                  >
                    Eliminar
                  </Button>
                }
              />
            </li>
          ))}
        </ul>
      )}
      <ConfirmDialog
        open={!!pending}
        title={`¿Eliminar el presupuesto de ${pending?.name}?`}
        onCancel={() => setPending(null)}
        onConfirm={() => {
          if (pending) remove.mutate(pending.id)
          setPending(null)
        }}
      />
    </>
  )
}
