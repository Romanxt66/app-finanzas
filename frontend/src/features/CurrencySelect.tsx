import { forwardRef, type SelectHTMLAttributes } from 'react'
import { useCurrencies } from '../api/hooks'
import { Select } from '../design'
import { currencyLabel } from '../lib/format'

/** Selector de moneda alimentado por la lista que expone la API. */
export const CurrencySelect = forwardRef<
  HTMLSelectElement,
  { label?: string; error?: string } & SelectHTMLAttributes<HTMLSelectElement>
>(function CurrencySelect({ label = 'Moneda', ...props }, ref) {
  const { data: currencies } = useCurrencies()
  return (
    <Select label={label} ref={ref} {...props}>
      <option value="">Selecciona…</option>
      {currencies?.map((code) => (
        <option key={code} value={code}>
          {currencyLabel(code)}
        </option>
      ))}
    </Select>
  )
})
