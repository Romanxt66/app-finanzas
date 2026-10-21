import { zodResolver } from '@hookform/resolvers/zod'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { useCategories, useCreateCategory, useDeleteCategory } from '../api/hooks'
import { Button, Card, Empty, ErrorText, Input, Select } from '../components/ui'

const schema = z.object({
  name: z.string().min(1, 'Requerido').max(80),
  kind: z.enum(['income', 'expense']),
})

const KIND_LABELS = { income: 'Ingresos', expense: 'Gastos' } as const

export function CategoriesPage() {
  const { data: categories, isLoading } = useCategories()
  const create = useCreateCategory()
  const remove = useDeleteCategory()
  const { register, handleSubmit, reset, formState } = useForm({
    resolver: zodResolver(schema),
    defaultValues: { kind: 'expense' as const },
  })

  return (
    <>
      <h1 className="text-xl font-bold">Categorías</h1>
      <Card title="Nueva categoría">
        <form
          className="grid gap-3 sm:grid-cols-3"
          onSubmit={handleSubmit((d) =>
            create.mutate(d, { onSuccess: () => reset({ kind: d.kind, name: '' }) }),
          )}
        >
          <Input label="Nombre" error={formState.errors.name?.message} {...register('name')} />
          <Select label="Tipo" {...register('kind')}>
            <option value="expense">Gasto</option>
            <option value="income">Ingreso</option>
          </Select>
          <div className="flex items-end">
            <Button type="submit" disabled={create.isPending}>
              Añadir
            </Button>
          </div>
        </form>
        <ErrorText error={create.error} />
      </Card>
      {isLoading ? (
        <Empty>Cargando…</Empty>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {(['expense', 'income'] as const).map((kind) => {
            const items = categories?.filter((c) => c.kind === kind) ?? []
            return (
              <Card key={kind} title={KIND_LABELS[kind]}>
                {!items.length ? (
                  <Empty>Sin categorías.</Empty>
                ) : (
                  <ul className="divide-y divide-slate-100">
                    {items.map((c) => (
                      <li key={c.id} className="flex items-center justify-between py-2">
                        <span>{c.name}</span>
                        <Button variant="danger" onClick={() => remove.mutate(c.id)}>
                          Eliminar
                        </Button>
                      </li>
                    ))}
                  </ul>
                )}
              </Card>
            )
          })}
        </div>
      )}
      <ErrorText error={remove.error} />
    </>
  )
}
