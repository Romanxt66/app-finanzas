import { useMemo, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useAccounts, useBulkImport } from '../api/hooks'
import { Badge, Button, Card, Empty, ErrorText, Glass, Select } from '../design'
import {
  detectDelimiter,
  guessDateFormat,
  parseCsv,
  type DateFormat,
  type Delimiter,
} from '../lib/csv'
import { buildItems, guessMapping, looksLikeHeader, type Mapping } from '../lib/importRows'
import { formatMoney } from '../lib/format'

/** File.text() no existe en todos los entornos (p. ej. jsdom): se usa FileReader como respaldo. */
function readText(file: File): Promise<string> {
  if (typeof file.text === 'function') return file.text()
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result))
    reader.onerror = () => reject(reader.error)
    reader.readAsText(file)
  })
}

const MAX_FILE_BYTES = 2 * 1024 * 1024
const PREVIEW_ROWS = 8

const DELIMITERS: { value: Delimiter; label: string }[] = [
  { value: ',', label: 'Coma (,)' },
  { value: ';', label: 'Punto y coma (;)' },
  { value: '\t', label: 'Tabulador' },
]
const DATE_FORMATS: { value: DateFormat; label: string }[] = [
  { value: 'dmy', label: 'Día/Mes/Año' },
  { value: 'mdy', label: 'Mes/Día/Año' },
  { value: 'ymd', label: 'Año-Mes-Día' },
]

export function ImportPage() {
  const { data: accounts = [] } = useAccounts()
  const bulk = useBulkImport()
  const qc = useQueryClient()
  const [accountId, setAccountId] = useState('')
  const [text, setText] = useState<string | null>(null)
  const [fileName, setFileName] = useState('')
  const [fileError, setFileError] = useState<string | null>(null)
  const [delimiter, setDelimiter] = useState<Delimiter>(',')
  const [hasHeader, setHasHeader] = useState(true)
  const [mapping, setMapping] = useState<Mapping | null>(null)
  const [result, setResult] = useState<{ created: number; skipped: number } | null>(null)

  const rows = useMemo(() => (text ? parseCsv(text, delimiter) : []), [text, delimiter])
  const header = hasHeader ? rows[0] : undefined
  const data = useMemo(() => (hasHeader ? rows.slice(1) : rows), [rows, hasHeader])
  const columns = Math.max(0, ...rows.map((r) => r.length))
  const columnLabel = (i: number) => header?.[i]?.trim() || `Columna ${i + 1}`

  const parsed = useMemo(
    () => (mapping ? buildItems(data, mapping, hasHeader ? 2 : 1) : { items: [], errors: [] }),
    [data, mapping, hasHeader],
  )
  const account = accounts.find((a) => a.id === accountId)

  async function onFile(file: File | undefined) {
    setResult(null)
    setFileError(null)
    if (!file) return
    if (file.size > MAX_FILE_BYTES) return setFileError('El archivo supera los 2 MB')
    const content = await readText(file)
    const sep = detectDelimiter(content)
    const parsedRows = parseCsv(content, sep)
    if (parsedRows.length < 2) return setFileError('El archivo no tiene filas de datos')
    const headerRow = looksLikeHeader(parsedRows[0])
    const body = headerRow ? parsedRows.slice(1) : parsedRows
    const dateGuess = guessMapping(headerRow ? parsedRows[0] : [], 'dmy')
    const samples = body.slice(0, 20).map((r) => r[Math.max(dateGuess.date, 0)] ?? '')
    setText(content)
    setFileName(file.name)
    setDelimiter(sep)
    setHasHeader(headerRow)
    setMapping(
      headerRow
        ? guessMapping(parsedRows[0], guessDateFormat(samples))
        : {
            date: 0,
            description: 1,
            amount: 2,
            debit: -1,
            credit: -1,
            dateFormat: guessDateFormat(samples),
          },
    )
  }

  const set = (patch: Partial<Mapping>) => setMapping((m) => (m ? { ...m, ...patch } : m))
  const ready = !!account && !!mapping && parsed.items.length > 0 && mapping.date >= 0

  async function run() {
    if (!account) return
    let created = 0
    let skipped = 0
    try {
      for (let i = 0; i < parsed.items.length; i += 500) {
        const res = await bulk.mutateAsync({
          account_id: account.id,
          items: parsed.items.slice(i, i + 500),
          skip_duplicates: true,
        })
        created += res.created
        skipped += res.skipped
      }
    } catch {
      // El mensaje del servidor ya se muestra con <ErrorText error={bulk.error} />
      if (created > 0) setResult({ created, skipped }) // tandas anteriores sí se guardaron
      return
    }
    setResult({ created, skipped })
    setText(null)
    await qc.invalidateQueries()
  }

  return (
    <>
      <h1 className="title">Importar movimientos</h1>
      <Card title="1. Cuenta y archivo">
        <div className="cr-stack">
          <Select
            label="Cuenta de destino"
            value={accountId}
            onChange={(e) => setAccountId(e.target.value)}
          >
            <option value="">Selecciona…</option>
            {accounts.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name} ({a.currency})
              </option>
            ))}
          </Select>
          <div className="cr-field">
            <label htmlFor="csv-file">Archivo CSV del banco</label>
            <input
              id="csv-file"
              className="cr-input"
              type="file"
              accept=".csv,text/csv,text/plain"
              onChange={(e) => void onFile(e.target.files?.[0])}
            />
          </div>
          {fileError && (
            <p role="alert" className="cr-error">
              {fileError}
            </p>
          )}
          <p className="caption cr-muted">
            El archivo se lee en tu navegador; solo se envían las filas que confirmes. Máximo 2 MB y
            1000 filas por envío.
          </p>
        </div>
      </Card>

      {result && (
        <Card>
          <p role="status" className="body">
            Se importaron <strong>{result.created}</strong> movimientos
            {result.skipped > 0 && <> ({result.skipped} ya existían y se omitieron)</>}.
          </p>
        </Card>
      )}

      {text && mapping && (
        <Card title={`2. Columnas · ${fileName}`}>
          <div className="cr-stack">
            <div className="cr-form-grid">
              <Select
                label="Separador"
                value={delimiter}
                onChange={(e) => setDelimiter(e.target.value as Delimiter)}
              >
                {DELIMITERS.map((d) => (
                  <option key={d.value} value={d.value}>
                    {d.label}
                  </option>
                ))}
              </Select>
              <Select
                label="Formato de fecha"
                value={mapping.dateFormat}
                onChange={(e) => set({ dateFormat: e.target.value as DateFormat })}
              >
                {DATE_FORMATS.map((d) => (
                  <option key={d.value} value={d.value}>
                    {d.label}
                  </option>
                ))}
              </Select>
              <Select
                label="Columna de fecha"
                value={mapping.date}
                onChange={(e) => set({ date: Number(e.target.value) })}
              >
                <option value={-1}>—</option>
                {Array.from({ length: columns }, (_, i) => (
                  <option key={i} value={i}>
                    {columnLabel(i)}
                  </option>
                ))}
              </Select>
              <Select
                label="Columna de descripción"
                value={mapping.description}
                onChange={(e) => set({ description: Number(e.target.value) })}
              >
                <option value={-1}>(sin descripción)</option>
                {Array.from({ length: columns }, (_, i) => (
                  <option key={i} value={i}>
                    {columnLabel(i)}
                  </option>
                ))}
              </Select>
              <Select
                label="Columna de monto (con signo)"
                value={mapping.amount}
                onChange={(e) => set({ amount: Number(e.target.value) })}
              >
                <option value={-1}>Usar débito y crédito</option>
                {Array.from({ length: columns }, (_, i) => (
                  <option key={i} value={i}>
                    {columnLabel(i)}
                  </option>
                ))}
              </Select>
              {mapping.amount < 0 && (
                <>
                  <Select
                    label="Columna de débito (gasto)"
                    value={mapping.debit}
                    onChange={(e) => set({ debit: Number(e.target.value) })}
                  >
                    <option value={-1}>—</option>
                    {Array.from({ length: columns }, (_, i) => (
                      <option key={i} value={i}>
                        {columnLabel(i)}
                      </option>
                    ))}
                  </Select>
                  <Select
                    label="Columna de crédito (ingreso)"
                    value={mapping.credit}
                    onChange={(e) => set({ credit: Number(e.target.value) })}
                  >
                    <option value={-1}>—</option>
                    {Array.from({ length: columns }, (_, i) => (
                      <option key={i} value={i}>
                        {columnLabel(i)}
                      </option>
                    ))}
                  </Select>
                </>
              )}
            </div>
            <label className="label cr-row">
              <input
                type="checkbox"
                checked={hasHeader}
                onChange={(e) => setHasHeader(e.target.checked)}
              />{' '}
              La primera fila es el encabezado
            </label>
          </div>
        </Card>
      )}

      {text && mapping && (
        <Card title="3. Vista previa">
          {parsed.items.length === 0 ? (
            <Empty>No hay filas válidas con esta configuración.</Empty>
          ) : (
            <Glass size="md" as="ul" className="cr-more" aria-label="Vista previa">
              {parsed.items.slice(0, PREVIEW_ROWS).map((it, i) => (
                <li key={i} className="cr-row-split">
                  <span className="body">{it.description || '(sin descripción)'}</span>
                  <span className="cr-row">
                    <span className="caption cr-muted">{it.occurred_on}</span>
                    <span className={`amount-sm ${Number(it.amount) > 0 ? 'cr-pos' : ''}`}>
                      {formatMoney(it.amount, account?.currency, { signed: Number(it.amount) > 0 })}
                    </span>
                  </span>
                </li>
              ))}
            </Glass>
          )}
          <div className="cr-row" style={{ marginTop: 'var(--space-3)' }}>
            <Badge tone="positive">{parsed.items.length} filas válidas</Badge>
            {parsed.errors.length > 0 && (
              <Badge tone="negative">{parsed.errors.length} con errores (se omiten)</Badge>
            )}
          </div>
          {parsed.errors.length > 0 && (
            <ul className="caption cr-muted" aria-label="Filas con errores">
              {parsed.errors.slice(0, 5).map((e) => (
                <li key={e.row}>
                  Fila {e.row}: {e.reason}
                </li>
              ))}
              {parsed.errors.length > 5 && <li>…y {parsed.errors.length - 5} más</li>}
            </ul>
          )}
          <div style={{ marginTop: 'var(--space-4)' }}>
            <Button
              variant="primary"
              disabled={!ready || bulk.isPending}
              onClick={() => void run()}
            >
              Importar {parsed.items.length} movimientos
            </Button>
            {!account && <p className="cr-error">Elige la cuenta de destino.</p>}
          </div>
          <ErrorText error={bulk.error} />
        </Card>
      )}
    </>
  )
}
