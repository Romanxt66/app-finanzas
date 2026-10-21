import { zodResolver } from '@hookform/resolvers/zod'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { useCategories, useCreateCategory, useDeleteCategory } from '../api/hooks'
import { Button, Card, Empty, ErrorText, Input, Select } from '../design'

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
      <h1 className="title">Categorías</h1>
      <Card title="Nueva categoría">
        <form
          className="cr-stack"
          onSubmit={handleSubmit((d) =>
            create.mutate(d, { onSuccess: () => reset({ kind: d.kind, name: '' }) }),
          )}
        >
          <div className="cr-form-grid">
            <Input label="Nombre" error={formState.errors.name?.message} {...register('name')} />
            <Select label="Tipo" {...register('kind')}>
              <option value="expense">Gasto</option>
              <option value="income">Ingreso</option>
            </Select>
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
        <Empty>Cargando…</Empty>
      ) : (
        <div className="cr-grid-cols">
          {(['expense', 'income'] as const).map((kind) => {
            const items = categories?.filter((c) => c.kind === kind) ?? []
            return (
              <Card key={kind} title={KIND_LABELS[kind]}>
                {!items.length ? (
                  <Empty>Sin categorías.</Empty>
                ) : (
                  <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
                    {items.map((c) => (
                      <li
                        key={c.id}
                        className="cr-row-split"
                        style={{ padding: 'var(--space-2) 0' }}
                      >
                        <span className="body">{c.name}</span>
                        <Button variant="danger" size="sm" onClick={() => remove.mutate(c.id)}>
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
