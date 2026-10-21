import {
  forwardRef,
  useId,
  type ButtonHTMLAttributes,
  type ElementType,
  type HTMLAttributes,
  type InputHTMLAttributes,
  type ReactNode,
  type SelectHTMLAttributes,
} from 'react'
import { NavLink } from 'react-router-dom'
import { formatMoney } from '../lib/format'
import { Icon, type IconName } from './Icon'
import { useCountUp } from './useCountUp'

const cx = (...parts: (string | false | null | undefined)[]) => parts.filter(Boolean).join(' ')

/** Raíz de tema: aplica tipografía y variables de Cristal a todo lo que contiene. */
export function Backdrop({ children }: { children: ReactNode }) {
  return <div className="cr cr-backdrop">{children}</div>
}

type GlassProps = HTMLAttributes<HTMLElement> & {
  as?: ElementType
  strong?: boolean
  size?: 'lg' | 'md'
  padded?: boolean
}

export function Glass({ as: Tag = 'div', strong, size, padded, className, ...rest }: GlassProps) {
  return (
    <Tag
      className={cx(
        'cr-glass',
        strong && 'cr-glass-strong',
        size === 'md' && 'cr-glass-md',
        padded && 'cr-pad',
        className,
      )}
      {...rest}
    />
  )
}

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'glass' | 'ghost' | 'danger'
  size?: 'md' | 'sm'
  icon?: IconName
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'glass', size, icon, className, children, ...rest },
  ref,
) {
  return (
    <button
      ref={ref}
      type="button"
      className={cx(
        'cr-btn',
        `cr-btn-${variant}`,
        size === 'sm' && 'cr-btn-sm',
        icon && !children && 'cr-btn-icon',
        className,
      )}
      {...rest}
    >
      {icon && <Icon name={icon} />}
      {children}
    </button>
  )
})

export function Badge({
  tone = 'neutral',
  icon,
  children,
}: {
  tone?: 'neutral' | 'positive' | 'negative' | 'warning'
  icon?: IconName
  children: ReactNode
}) {
  return (
    <span className={cx('cr-badge', tone !== 'neutral' && `cr-badge-${tone}`)}>
      {icon && <Icon name={icon} />}
      {children}
    </span>
  )
}

/** Variación porcentual con flecha y signo (no solo color). */
export function Delta({ value, invert }: { value: number; invert?: boolean }) {
  const up = value >= 0
  const good = invert ? !up : up
  return (
    <Badge tone={good ? 'positive' : 'negative'} icon={up ? 'up' : 'down'}>
      {up ? '+' : '−'}
      {Math.abs(value).toLocaleString('es-CO', { maximumFractionDigits: 1 })} %
    </Badge>
  )
}

export function Sparkline({ data, label }: { data: number[]; label: string }) {
  const w = 120
  const h = 40
  const pad = 3
  if (data.length < 2) return null
  const min = Math.min(...data)
  const span = Math.max(...data) - min || 1
  const pts = data.map((v, i) => [
    pad + (i * (w - pad * 2)) / (data.length - 1),
    pad + (1 - (v - min) / span) * (h - pad * 2),
  ])
  const line = pts.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`).join(' ')
  const last = pts[pts.length - 1]
  return (
    <svg
      viewBox={`0 0 ${w} ${h}`}
      width={w}
      height={h}
      className="cr-balance-spark"
      role="img"
      aria-label={label}
    >
      <path
        d={`${line} L${last[0]} ${h} L${pts[0][0]} ${h} Z`}
        fill="currentColor"
        opacity={0.12}
      />
      <path
        d={line}
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx={last[0]} cy={last[1]} r={3} fill="currentColor" />
    </svg>
  )
}

export function BalanceCard(props: {
  value: number
  currency?: string
  label: string
  note?: string
  trend?: number[]
  trendLabel?: string
  hidden?: boolean
  onToggleHidden?: () => void
}) {
  return (
    <Glass strong className="cr-balance">
      <div className="cr-balance-top">
        <span className="label cr-muted">{props.label}</span>
        {props.onToggleHidden && (
          <Button
            variant="ghost"
            size="sm"
            icon="eye"
            aria-label={props.hidden ? 'Mostrar saldo' : 'Ocultar saldo'}
            aria-pressed={props.hidden}
            onClick={props.onToggleHidden}
          />
        )}
      </div>
      <div className="amount-xl cr-balance-value">
        {props.hidden ? '••••••' : <AnimatedMoney value={props.value} currency={props.currency} />}
      </div>
      <div className="cr-balance-foot">
        {props.note ? <span className="caption cr-muted">{props.note}</span> : <span />}
        {props.trend && <Sparkline data={props.trend} label={props.trendLabel ?? 'Tendencia'} />}
      </div>
    </Glass>
  )
}

export function StatTile(props: {
  label: string
  value: number
  currency?: string
  delta?: number | null
  invertDelta?: boolean
  icon?: IconName
  tone?: 'mint' | 'amber' | 'negative'
}) {
  return (
    <Glass size="md" className="cr-stat">
      <div className="cr-stat-head">
        <span className={cx('cr-chip', props.tone && `cr-chip-${props.tone}`)}>
          <Icon name={props.icon ?? 'chart'} />
        </span>
        {props.delta != null && <Delta value={props.delta} invert={props.invertDelta} />}
      </div>
      <div>
        <div className="label cr-muted">{props.label}</div>
        <div className="amount">
          <AnimatedMoney value={props.value} currency={props.currency} />
        </div>
      </div>
    </Glass>
  )
}

export type TxKind = 'income' | 'expense' | 'transfer'
const KIND_ICON: Record<TxKind, IconName> = { income: 'salary', expense: 'card', transfer: 'swap' }
const KIND_TONE: Record<TxKind, string | undefined> = {
  income: 'mint',
  expense: undefined,
  transfer: 'amber',
}

export function TransactionRow(props: {
  kind: TxKind
  title: string
  detail?: string
  amount: number
  currency?: string
  actions?: ReactNode
}) {
  const signed =
    props.kind === 'income' ? props.amount : props.kind === 'expense' ? -props.amount : props.amount
  return (
    <div className="cr-txn" role="listitem">
      <span className={cx('cr-chip', KIND_TONE[props.kind] && `cr-chip-${KIND_TONE[props.kind]}`)}>
        <Icon name={KIND_ICON[props.kind]} />
      </span>
      <div className="cr-txn-main">
        <div className="body cr-txn-title">{props.title}</div>
        {props.detail && <div className="caption cr-muted">{props.detail}</div>}
      </div>
      <div className={cx('amount-sm cr-txn-amt', props.kind === 'income' ? 'cr-pos' : 'cr-neg')}>
        {formatMoney(signed, props.currency, { signed: props.kind === 'income' })}
      </div>
      {props.actions && <div className="cr-actions-inline">{props.actions}</div>}
    </div>
  )
}

export function TransactionList({ children, label }: { children: ReactNode; label: string }) {
  return (
    <Glass size="md" className="cr-list" role="list" aria-label={label}>
      {children}
    </Glass>
  )
}

export function BudgetBar(props: {
  label: string
  spent: number
  limit: number
  currency?: string
  actions?: ReactNode
}) {
  const ratio = props.limit ? props.spent / props.limit : 0
  const state = ratio > 1 ? 'is-over' : ratio >= 0.8 ? 'is-warn' : ''
  const note =
    ratio > 1
      ? `Excedido en ${formatMoney(props.spent - props.limit, props.currency)}`
      : `Quedan ${formatMoney(props.limit - props.spent, props.currency)}`
  return (
    <Glass size="md" className={cx('cr-budget', state)}>
      <div className="cr-budget-head">
        <span className="body">{props.label}</span>
        <span className="label cr-muted">
          {formatMoney(props.spent, props.currency)} / {formatMoney(props.limit, props.currency)}
        </span>
      </div>
      <div
        className="cr-track"
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.round(Math.min(ratio, 1) * 100)}
        aria-label={props.label}
      >
        <div className="cr-fill" style={{ width: `${Math.min(ratio, 1) * 100}%` }} />
      </div>
      <div className="cr-row-split" style={{ padding: 0 }}>
        <span className="caption cr-muted">
          {Math.round(ratio * 100)} % · {note}
        </span>
        {props.actions}
      </div>
    </Glass>
  )
}

export function Segmented<T extends string>(props: {
  options: { value: T; label: string }[]
  value: T
  onChange: (v: T) => void
  label: string
}) {
  return (
    <Glass className="cr-seg" role="group" aria-label={props.label}>
      {props.options.map((o) => (
        <button
          key={o.value}
          type="button"
          aria-pressed={o.value === props.value}
          onClick={() => props.onChange(o.value)}
        >
          {o.label}
        </button>
      ))}
    </Glass>
  )
}

export interface NavItem {
  to: string
  label: string
  icon: IconName
  end?: boolean
}

/** Barra de pestañas flotante (móvil). En pantallas anchas se usa la navegación superior. */
export function TabBar({ items }: { items: NavItem[] }) {
  return (
    <Glass as="nav" className="cr-tabbar" aria-label="Navegación principal">
      {items.map((t) => (
        <NavLink key={t.to} to={t.to} end={t.end} className="cr-tab">
          <Icon name={t.icon} />
          {t.label}
        </NavLink>
      ))}
    </Glass>
  )
}

export function TopNav({ items }: { items: NavItem[] }) {
  return (
    <nav className="cr-nav" aria-label="Principal">
      {items.map((t) => (
        <NavLink key={t.to} to={t.to} end={t.end}>
          <Icon name={t.icon} />
          {t.label}
        </NavLink>
      ))}
    </nav>
  )
}

interface FieldProps {
  label: string
  error?: string
}

export const Input = forwardRef<
  HTMLInputElement,
  FieldProps & InputHTMLAttributes<HTMLInputElement>
>(({ label, error, className, ...props }, ref) => {
  const id = useId()
  return (
    <div className="cr-field">
      <label htmlFor={id}>{label}</label>
      <input
        id={id}
        ref={ref}
        className={cx('cr-input', className)}
        aria-invalid={!!error}
        {...props}
      />
      {error && <p className="cr-error">{error}</p>}
    </div>
  )
})

export const Select = forwardRef<
  HTMLSelectElement,
  FieldProps & SelectHTMLAttributes<HTMLSelectElement>
>(({ label, error, className, children, ...props }, ref) => {
  const id = useId()
  return (
    <div className="cr-field">
      <label htmlFor={id}>{label}</label>
      <select
        id={id}
        ref={ref}
        className={cx('cr-input', className)}
        aria-invalid={!!error}
        {...props}
      >
        {children}
      </select>
      {error && <p className="cr-error">{error}</p>}
    </div>
  )
})

export function Card({
  title,
  action,
  children,
  flush,
}: {
  title?: string
  action?: ReactNode
  children: ReactNode
  flush?: boolean
}) {
  return (
    <Glass as="section" padded={!flush} className={flush ? 'cr-bleed' : undefined}>
      {(title || action) && (
        <div className={cx('cr-card-title', flush && 'cr-row-split')}>
          <h2 className="heading">{title}</h2>
          {action}
        </div>
      )}
      {children}
    </Glass>
  )
}

export function ErrorText({ error }: { error: unknown }) {
  if (!error) return null
  return (
    <p role="alert" className="cr-error">
      {error instanceof Error ? error.message : 'Error inesperado'}
    </p>
  )
}

export function Empty({ children }: { children: ReactNode }) {
  return <p className="cr-empty">{children}</p>
}

export function Skeleton({ lines = 3, height = 56 }: { lines?: number; height?: number }) {
  return (
    <div className="cr-skeleton-stack" role="status">
      <span className="cr-sr">Cargando…</span>
      {Array.from({ length: lines }, (_, i) => (
        <span key={i} className="cr-skeleton" style={{ height }} aria-hidden="true" />
      ))}
    </div>
  )
}

/** Cifra que cuenta hasta su valor al aparecer o cambiar. */
export function AnimatedMoney({ value, currency }: { value: number; currency?: string }) {
  return <>{formatMoney(useCountUp(value), currency)}</>
}
