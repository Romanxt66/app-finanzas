// Lectura de extractos CSV en el navegador (sin enviar el archivo al servidor hasta confirmar).

export type Delimiter = ',' | ';' | '\t'

/** Elige el separador que más aparece fuera de comillas en las primeras líneas. */
export function detectDelimiter(text: string): Delimiter {
  const sample = text.split(/\r?\n/).slice(0, 5).join('\n')
  const counts: Record<Delimiter, number> = { ',': 0, ';': 0, '\t': 0 }
  let quoted = false
  for (const ch of sample) {
    if (ch === '"') quoted = !quoted
    else if (!quoted && ch in counts) counts[ch as Delimiter]++
  }
  return (Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0] as Delimiter) || ','
}

/** Parser RFC 4180 mínimo: comillas dobles, saltos de línea dentro de campos, BOM. */
export function parseCsv(input: string, delimiter: Delimiter = detectDelimiter(input)): string[][] {
  const text = input.replace(/^﻿/, '')
  const rows: string[][] = []
  let row: string[] = []
  let field = ''
  let quoted = false
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') {
        field += '"'
        i++
      } else if (ch === '"') quoted = false
      else field += ch
    } else if (ch === '"') quoted = true
    else if (ch === delimiter) {
      row.push(field)
      field = ''
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++
      row.push(field)
      rows.push(row)
      row = []
      field = ''
    } else field += ch
  }
  if (field !== '' || row.length) {
    row.push(field)
    rows.push(row)
  }
  return rows.filter((r) => r.some((c) => c.trim() !== ''))
}

/**
 * Convierte "1.234,56", "1,234.56", "-$ 1.234", "(500)", "12,5" a número.
 * Devuelve null si no es un monto reconocible.
 */
export function parseAmount(raw: string): number | null {
  let s = raw.trim()
  if (!s) return null
  let negative = false
  if (/^\(.*\)$/.test(s)) {
    negative = true
    s = s.slice(1, -1)
  }
  if (/-$/.test(s)) {
    negative = true
    s = s.slice(0, -1)
  }
  s = s.replace(/[^\d.,+-]/g, '')
  if (s.startsWith('-')) {
    negative = true
    s = s.slice(1)
  }
  s = s.replace(/^\+/, '')
  if (!/^\d[\d.,]*$/.test(s)) return null
  const lastDot = s.lastIndexOf('.')
  const lastComma = s.lastIndexOf(',')
  let decimalSep: '.' | ',' | null = null
  if (lastDot >= 0 && lastComma >= 0) decimalSep = lastDot > lastComma ? '.' : ','
  else {
    const sep = lastDot >= 0 ? '.' : lastComma >= 0 ? ',' : null
    if (sep) {
      const parts = s.split(sep)
      // un único separador con 1-2 dígitos al final es decimal; con 3 dígitos (y repetido o no) es de miles
      decimalSep = parts.length === 2 && parts[1].length !== 3 ? sep : null
    }
  }
  // Con separadores de miles, cada grupo tras el primero debe tener exactamente 3 dígitos
  const integerPart = decimalSep ? s.slice(0, s.lastIndexOf(decimalSep)) : s
  if (!/^\d+$/.test(integerPart) && !/^\d{1,3}([.,]\d{3})+$/.test(integerPart)) return null
  const normalized = decimalSep
    ? s
        .split(decimalSep === '.' ? ',' : '.')
        .join('')
        .replace(decimalSep, '.')
    : s.replace(/[.,]/g, '')
  const value = Number(normalized)
  if (!Number.isFinite(value)) return null
  return negative ? -value : value
}

export type DateFormat = 'ymd' | 'dmy' | 'mdy'

/** Fecha a YYYY-MM-DD según el formato elegido; null si no es válida (31/02, etc.). */
export function parseDate(raw: string, format: DateFormat): string | null {
  const m = raw.trim().match(/^(\d{1,4})[-/.](\d{1,2})[-/.](\d{1,4})/)
  if (!m) return null
  let [y, mo, d] = [0, 0, 0]
  if (format === 'ymd') [y, mo, d] = [+m[1], +m[2], +m[3]]
  else if (format === 'dmy') [d, mo, y] = [+m[1], +m[2], +m[3]]
  else [mo, d, y] = [+m[1], +m[2], +m[3]]
  if (y < 100) y += 2000
  const date = new Date(Date.UTC(y, mo - 1, d))
  if (date.getUTCFullYear() !== y || date.getUTCMonth() !== mo - 1 || date.getUTCDate() !== d)
    return null
  return `${String(y).padStart(4, '0')}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`
}

/** Adivina el formato de fecha mirando si algún valor solo puede ser día-primero o mes-primero. */
export function guessDateFormat(samples: string[]): DateFormat {
  if (samples.some((s) => /^\d{4}[-/.]/.test(s.trim()))) return 'ymd'
  let dmy = 0
  let mdy = 0
  for (const s of samples) {
    const m = s.trim().match(/^(\d{1,2})[-/.](\d{1,2})[-/.]/)
    if (!m) continue
    if (+m[1] > 12) dmy++
    else if (+m[2] > 12) mdy++
  }
  return mdy > dmy ? 'mdy' : 'dmy'
}
