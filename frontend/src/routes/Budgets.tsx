import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import {
  useBudgets,
  useCategories,
  useCreateBudget,
  useDeleteBudget,
  useUpdateBudget,
} from '../api/hooks'
import {
  BudgetBar,
  Button,
  Card,
  ConfirmDialog,
  Empty,
  ErrorText,
  Input,
  Skeleton,
  FormDialog,
} from '../design'
import { CategorySelect } from '../features/CategorySelect'
import { RenameForm } from '../features/RenameForm'
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
  const update = useUpdateBudget()
  const [editing, setEditing] = useState<{ id: string; name: string; amount: string } | null>(null)
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
            <CategorySelect
              kind="expense"
              label="Categoría de gasto"
              emptyLabel="Selecciona…"
              error={formState.errors.category_id?.message}
              {...register('category_id')}
            />
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
                  <span className="cr-actions-inline">
                    <Button
                      variant="ghost"
                      size="sm"
                      icon="edit"
                      aria-label={`Editar ${names.get(b.category_id) ?? 'presupuesto'}`}
                      onClick={() =>
                        setEditing({
                          id: b.id,
                          name: names.get(b.category_id) ?? 'presupuesto',
                          amount: String(Number(b.amount)),
                        })
                      }
                    />
                    <Button
                      variant="danger"
                      size="sm"
                      onClick={() =>
                        setPending({
                          id: b.id,
                          name: names.get(b.category_id) ?? 'este presupuesto',
                        })
                      }
                    >
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
        title={`Editar presupuesto de ${editing?.name}`}
        onClose={() => setEditing(null)}
      >
        {editing && (
          <RenameForm
            key={editing.id}
            initial={editing.amount}
            label="Monto"
            inputMode="decimal"
            validate={(v) =>
              /^\d+(\.\d{1,2})?$/.test(v) && Number(v) > 0
                ? null
                : 'Monto positivo con hasta 2 decimales'
            }
            pending={update.isPending}
            error={update.error}
            onCancel={() => setEditing(null)}
            onSubmit={(amount) =>
              update.mutate({ id: editing.id, amount }, { onSuccess: () => setEditing(null) })
            }
          />
        )}
      </FormDialog>
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
