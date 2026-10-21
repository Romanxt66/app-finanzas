import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { useState } from 'react'
import { MemoryRouter } from 'react-router-dom'
import { formatMoney } from '../lib/format'
import {
  BalanceCard,
  BudgetBar,
  Delta,
  Segmented,
  Sparkline,
  TabBar,
  TransactionRow,
} from './components'

const plain = (s: string) => s.replace(/\s/g, ' ')

describe('formatMoney', () => {
  it('usa signo tipográfico y es-CO', () => {
    expect(plain(formatMoney(-18900, 'COP'))).toBe('− $ 18.900')
    expect(plain(formatMoney(4850000, 'COP', { signed: true }))).toBe('+ $ 4.850.000')
  })
  it('COP sin decimales, otras monedas con decimales', () => {
    expect(formatMoney(12.5, 'COP')).not.toMatch(/,/)
    expect(formatMoney('12.5', 'EUR')).toMatch(/12,50/)
  })
  it('sin moneda muestra solo el número', () => {
    expect(formatMoney(1234.5)).toBe('1.234,5')
  })
})

describe('componentes Cristal', () => {
  it('Delta indica dirección con flecha y signo, no solo color', () => {
    const { rerender } = render(<Delta value={4.2} />)
    expect(screen.getByText(/^\+4,2/)).toHaveClass('cr-badge-positive', { exact: false })
    rerender(<Delta value={-3} />)
    expect(screen.getByText(/^−3/)).toHaveClass('cr-badge-negative', { exact: false })
    rerender(<Delta value={3} invert />)
    expect(screen.getByText(/^\+3/)).toHaveClass('cr-badge-negative', { exact: false })
  })

  it('TransactionRow: ingreso con +, gasto con −, transferencia sin signo', () => {
    render(
      <div>
        <TransactionRow kind="income" title="Nómina" amount={100} currency="COP" />
        <TransactionRow kind="expense" title="Café" amount={5} currency="COP" />
        <TransactionRow kind="transfer" title="Ahorro" amount={7} currency="COP" />
      </div>,
    )
    expect(screen.getByText(/^\+ \$ 100/)).toHaveClass('cr-pos')
    expect(screen.getByText(/^− \$ 5/)).toHaveClass('cr-neg')
    expect(screen.getByText('$ 7')).toBeInTheDocument()
  })

  it.each([
    [50, '', 'Quedan'],
    [85, 'is-warn', 'Quedan'],
    [120, 'is-over', 'Excedido en'],
  ])('BudgetBar con gasto %i/100 → estado "%s"', (spent, state, text) => {
    const { container } = render(
      <BudgetBar label="Comida" spent={spent} limit={100} currency="COP" />,
    )
    expect(screen.getByRole('progressbar')).toHaveAttribute(
      'aria-valuenow',
      String(Math.min(spent, 100)),
    )
    expect(screen.getByText(new RegExp(text))).toBeInTheDocument()
    if (state) expect(container.querySelector(`.${state}`)).not.toBeNull()
  })

  it('BudgetBar sin límite no divide por cero', () => {
    render(<BudgetBar label="X" spent={10} limit={0} />)
    expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '0')
  })

  it('Sparkline necesita al menos dos puntos', () => {
    const { container, rerender } = render(<Sparkline data={[1]} label="t" />)
    expect(container.querySelector('svg')).toBeNull()
    rerender(<Sparkline data={[1, 3, 2]} label="t" />)
    expect(screen.getByRole('img', { name: 't' })).toBeInTheDocument()
  })

  it('BalanceCard oculta la cifra y expone el estado del botón', async () => {
    function Harness() {
      const [hidden, setHidden] = useState(false)
      return (
        <BalanceCard
          label="Saldo total"
          value={1000}
          currency="COP"
          hidden={hidden}
          onToggleHidden={() => setHidden(!hidden)}
        />
      )
    }
    render(<Harness />)
    expect(screen.getByText('$ 1.000')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Ocultar saldo' }))
    expect(screen.queryByText('$ 1.000')).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Mostrar saldo' })).toHaveAttribute(
      'aria-pressed',
      'true',
    )
  })

  it('Segmented marca la opción activa', async () => {
    function Harness() {
      const [v, setV] = useState<'a' | 'b'>('a')
      return (
        <Segmented<'a' | 'b'>
          label="Periodo"
          value={v}
          onChange={setV}
          options={[
            { value: 'a', label: 'Mes' },
            { value: 'b', label: 'Año' },
          ]}
        />
      )
    }
    render(<Harness />)
    await userEvent.click(screen.getByRole('button', { name: 'Año' }))
    expect(screen.getByRole('button', { name: 'Año' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByRole('button', { name: 'Mes' })).toHaveAttribute('aria-pressed', 'false')
  })

  it('TabBar marca la pestaña actual con aria-current', () => {
    render(
      <MemoryRouter initialEntries={['/cuentas']}>
        <TabBar
          items={[
            { to: '/', label: 'Inicio', icon: 'home', end: true },
            { to: '/cuentas', label: 'Cuentas', icon: 'wallet' },
          ]}
        />
      </MemoryRouter>,
    )
    expect(screen.getByRole('link', { name: 'Cuentas' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: 'Inicio' })).not.toHaveAttribute('aria-current')
  })
})

const here = dirname(fileURLToPath(import.meta.url))

describe('tokens compartidos (web y Android)', () => {
  const tokens = JSON.parse(readFileSync(resolve(here, '../../../design/tokens.json'), 'utf8'))
  const css = readFileSync(resolve(here, 'tokens.css'), 'utf8')

  it('tokens.css está sincronizado con design/tokens.json (npm run gen:tokens)', () => {
    const names = [
      ...tokens.color.tokens,
      ...tokens.spacing.tokens,
      ...tokens.radius.tokens,
      ...tokens.shadow.tokens,
      ...tokens.blur.tokens,
    ].map((t: { name: string }) => t.name)
    for (const n of names) expect(css).toContain(`--${n}:`)
  })

  it('define tema claro y oscuro, sin alias sin resolver', () => {
    expect(css).toContain("data-theme='light'")
    expect(css).toContain('prefers-color-scheme: light')
    expect(css).not.toMatch(/\{[a-z-]+\}/)
  })

  it('todo color tiene valor para el primer tema y nombres únicos', () => {
    const names = tokens.color.tokens.map((t: { name: string }) => t.name)
    expect(new Set(names).size).toBe(names.length)
    const first = tokens.color.themes[0].id
    for (const t of tokens.color.tokens)
      expect(typeof t.value === 'string' || !!t.value[first]).toBe(true)
  })
})
