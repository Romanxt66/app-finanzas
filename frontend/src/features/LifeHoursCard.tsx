import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import { z } from 'zod'
import {
  useCategories,
  useLifeHoursMonth,
  useLifeHoursProfile,
  useSaveLifeHours,
} from '../api/hooks'
import { Button, Card, Empty, ErrorText, FormDialog, Input, Skeleton } from '../design'
import { formatMoney } from '../lib/format'
import { formatHours, hourlyRate } from '../lib/hours'
import { useDisplayCurrency } from '../lib/useCurrency'

const schema = z.object({
  monthly_net_income: z.string().regex(/^\d+(\.\d{1,2})?$/, 'Monto positivo con hasta 2 decimales'),
  weekly_hours: z
    .string()
    .regex(/^\d+(\.\d{1,2})?$/, 'Número válido')
    .refine((v) => Number(v) > 0 && Number(v) <= 168, 'Entre 1 y 168 horas'),
})

function RateDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { data: profile } = useLifeHoursProfile()
  const save = useSaveLifeHours()
  const currency = useDisplayCurrency()
  const { register, handleSubmit, control, formState } = useForm({
    resolver: zodResolver(schema),
    values: {
      monthly_net_income: profile?.monthly_net_income ?? '',
      weekly_hours: profile?.weekly_hours ?? '40',
    },
  })
  const [income, weekly] = useWatch({ control, name: ['monthly_net_income', 'weekly_hours'] })
  const preview = hourlyRate(Number(income), Number(weekly))
  return (
    <FormDialog open={open} title="¿Cuánto vale tu hora?" onClose={onClose}>
      <form
        className="cr-stack"
        onSubmit={handleSubmit((d) =>
          save.mutate(
            { monthly_net_income: d.monthly_net_income, weekly_hours: d.weekly_hours },
            { onSuccess: onClose },
          ),
        )}
      >
        <Input
          label="Ingreso neto mensual"
          inputMode="decimal"
          error={formState.errors.monthly_net_income?.message}
          {...register('monthly_net_income')}
        />
        <Input
          label="Horas de trabajo por semana"
          inputMode="decimal"
          error={formState.errors.weekly_hours?.message}
          {...register('weekly_hours')}
        />
        <p className="label cr-muted" aria-live="polite">
          {preview
            ? `Tu hora vale ≈ ${formatMoney(preview, currency)}`
            : 'Escribe tu ingreso para ver el valor de tu hora.'}
        </p>
        <ErrorText error={save.error} />
        <div className="cr-row">
          <Button type="submit" variant="primary" disabled={save.isPending}>
            Guardar
          </Button>
          <Button onClick={onClose}>Cancelar</Button>
        </div>
      </form>
    </FormDialog>
  )
}

/** Cuánto trabajo cuestan los gastos del mes, y el valor de la hora que lo calcula. */
export function LifeHoursCard({ month }: { month: string }) {
  const [editing, setEditing] = useState(false)
  const { data: profile, isLoading } = useLifeHoursProfile()
  const { data: summary } = useLifeHoursMonth(month, !!profile)
  const { data: categories = [] } = useCategories()
  const currency = useDisplayCurrency()
  const names = new Map(categories.map((c) => [c.id, c.name]))
  const top = (summary?.by_category ?? []).slice(0, 3)

  return (
    <>
      <Card
        title="Horas de vida"
        action={
          !isLoading && (
            <Button variant="ghost" size="sm" icon="edit" onClick={() => setEditing(true)}>
              {profile ? 'Editar' : 'Configurar'}
            </Button>
          )
        }
      >
        {isLoading ? (
          <Skeleton lines={2} height={28} />
        ) : !profile ? (
          <Empty>
            Descubre cuántas horas de trabajo cuesta cada gasto. Indica tu ingreso para empezar.
          </Empty>
        ) : (
          <div className="cr-stack">
            <div>
              <div className="amount-xl">{formatHours(Number(summary?.total_hours ?? 0))}</div>
              <p className="label cr-muted">de trabajo se fueron en gastos este mes</p>
            </div>
            {top.length > 0 && (
              <ul className="cr-lh-list" aria-label="Categorías que más horas cuestan">
                {top.map((c) => (
                  <li key={c.category_id ?? 'none'} className="cr-row-split">
                    <span className="body">
                      {c.category_id ? names.get(c.category_id) : 'Sin categoría'}
                    </span>
                    <span className="amount-sm">{formatHours(Number(c.hours))}</span>
                  </li>
                ))}
              </ul>
            )}
            <p className="caption cr-muted">
              Tu hora vale {formatMoney(profile.hourly_rate, currency)}
            </p>
          </div>
        )}
      </Card>
      <RateDialog open={editing} onClose={() => setEditing(false)} />
    </>
  )
}
