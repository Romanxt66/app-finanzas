export function formatMoney(value: string | number, currency: string): string {
  return new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(Number(value))
}

/** "USD" -> "US Dollar" (o su equivalente en el idioma del navegador). */
export function currencyLabel(code: string): string {
  const name = new Intl.DisplayNames(undefined, { type: 'currency' }).of(code)
  return name ? `${code} · ${name}` : code
}

export function formatDate(iso: string): string {
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(
    new Date(`${iso}T00:00:00`),
  )
}

/** Primer día del mes como YYYY-MM-DD, en hora local. */
export function monthStart(date = new Date()): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-01`
}

export function todayISO(): string {
  const d = new Date()
  return `${monthStart(d).slice(0, 8)}${String(d.getDate()).padStart(2, '0')}`
}
