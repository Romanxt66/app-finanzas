import { useState } from 'react'
import { zodResolver } from '@hookform/resolvers/zod'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { useCategories, useCreateCategory, useDeleteCategory } from '../api/hooks'
import { Button, Card, ConfirmDialog, Empty, ErrorText, Input, Select, Skeleton } from '../design'

const schema = z.object({
  name: z.string().min(1, 'Requerido').max(80),
  kind: z.enum(['income', 'expense']),
})

const KIND_LABELS = { income: 'Ingresos', expense: 'Gastos' } as const

export function CategoriesPage() {
  const { data: categories, isLoading } = useCategories()
  const create = useCreateCategory()
  const remove = useDeleteCategory()
  const [pending, setPending] = useState<{ id: string; name: string } | null>(null)
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
        <Skeleton lines={3} />
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
                        <Button
                          variant="danger"
                          size="sm"
                          onClick={() => setPending({ id: c.id, name: c.name })}
                        >
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
      <ConfirmDialog
        open={!!pending}
        title={`¿Eliminar la categoría "${pending?.name}"?`}
        onCancel={() => setPending(null)}
        onConfirm={() => {
          if (pending) remove.mutate(pending.id)
          setPending(null)
        }}
      >
        Solo se puede eliminar si no tiene movimientos asociados.
      </ConfirmDialog>
      <ErrorText error={remove.error} />
    </>
  )
}
