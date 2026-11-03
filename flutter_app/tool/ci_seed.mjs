// Datos de prueba para la revisión visual de la CI (backend local con SQLite).
// Crea un usuario con cuentas, movimientos de varios meses, presupuestos (uno excedido),
// una meta, un cobro recurrente para mañana y una compra en la Sala de espera.
//
// Uso: API_URL=http://localhost:8101 ALVEA_EMAIL=ci@example.com ALVEA_PASSWORD=... node tool/ci_seed.mjs
const { API_URL = 'http://localhost:8101', ALVEA_EMAIL, ALVEA_PASSWORD } = process.env
if (!ALVEA_EMAIL || !ALVEA_PASSWORD) throw new Error('Define ALVEA_EMAIL y ALVEA_PASSWORD (usuario de prueba)')

const iso = (d) => d.toISOString().slice(0, 10)
const addDays = (d, n) => new Date(d.getTime() + n * 864e5)
const today = new Date()

async function call(path, body, token, method = body === undefined ? 'GET' : 'POST') {
  const res = await fetch(`${API_URL}/api/v1${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token && { Authorization: `Bearer ${token}` }) },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const data = res.status === 204 ? null : await res.json()
  if (!res.ok) throw new Error(`${method} ${path}: ${JSON.stringify(data)}`)
  return data
}

await call('/auth/register', { email: ALVEA_EMAIL, password: ALVEA_PASSWORD, full_name: 'Persona Visual' })
const { access_token: t } = await call('/auth/login', { email: ALVEA_EMAIL, password: ALVEA_PASSWORD })

const bank = (await call('/accounts', { name: 'Bancolombia', type: 'bank', currency: 'COP', initial_balance: '2500000' }, t)).id
const wallet = (await call('/accounts', { name: 'Nequi', type: 'bank', currency: 'COP', initial_balance: '180000' }, t)).id
const category = async (name, kind) => (await call('/categories', { name, kind }, t)).id
const food = await category('Comida', 'expense')
const market = await category('Supermercado', 'expense')
const fun = await category('Ocio', 'expense')
const subs = await category('Suscripciones', 'expense')
const salary = await category('Nómina', 'income')

const month = iso(new Date(Date.UTC(today.getFullYear(), today.getMonth(), 1)))
await call('/budgets', { category_id: market, month, amount: '900000' }, t)
await call('/budgets', { category_id: fun, month, amount: '150000' }, t)

const tx = (account, type, amount, description, day, category_id) =>
  call('/transactions', { type, account_id: account, amount: String(amount), description, occurred_on: iso(day), category_id }, t)
for (let m = 3; m >= 0; m--) {
  await tx(bank, 'income', 4200000, 'Nómina', new Date(today.getFullYear(), today.getMonth() - m, 1), salary)
  await tx(bank, 'expense', 44900, 'Netflix', new Date(today.getFullYear(), today.getMonth() - m, 5), subs)
}
for (let i = 1; i <= 40; i++) {
  const d = addDays(today, -i)
  const weekend = [0, 6].includes(d.getDay())
  await tx(i % 2 ? bank : wallet, 'expense', weekend ? 85000 + (i % 5) * 9000 : 18000 + (i % 4) * 4000, i % 3 ? 'Éxito' : 'Rappi', d, i % 3 ? market : food)
}
await tx(wallet, 'expense', 210000, 'Concierto', today, fun) // presupuesto de Ocio excedido: aviso

await call('/goals', { name: 'Viaje a Cartagena', target_amount: '3000000', currency: 'COP' }, t).catch((e) => console.warn('meta:', e.message))
await call('/recurring', {
  type: 'expense', account_id: bank, category_id: subs, amount: '16900', description: 'Spotify',
  frequency: 'monthly', start_date: iso(addDays(today, 1)),
}, t)
await call('/waiting-room', { name: 'Audífonos inalámbricos', amount: '320000', currency: 'COP' }, t)
await call('/life-hours/profile', { monthly_net_income: '4200000', weekly_hours: '44' }, t, 'PUT').catch(() => {})

const notices = await call(`/notifications?today=${iso(today)}`, undefined, t)
console.log(`datos de prueba listos (${notices.items.length} avisos)`)
