import { useId } from 'react'
import type { Face } from '../lib/mood'

// Alvi, la gotita de malvavisco del resumen (el mismo dibujo que en la app Android). Se pinta en SVG con
// el radio de la panza = 1; respira, parpadea y, según su ánimo, salta, tiembla o suda (todo con CSS, que
// se detiene con «reducir movimiento»).

const INK = '#181818'

function mix(a: string, b: string, t: number): string {
  const pa = [1, 3, 5].map((i) => parseInt(a.slice(i, i + 2), 16))
  const pb = [1, 3, 5].map((i) => parseInt(b.slice(i, i + 2), 16))
  return `#${pa
    .map((v, i) =>
      Math.round(v + (pb[i] - v) * t)
        .toString(16)
        .padStart(2, '0'),
    )
    .join('')}`
}

/** Silueta regordeta de gota con la puntita arriba. */
function drop(r: number, dx = 0, dy = 0): string {
  const p = (x: number, y: number) => `${(x * r + dx).toFixed(3)} ${(y * r + dy).toFixed(3)}`
  return [
    `M${p(0, -1.45)}`,
    `C${p(0.32, -1.22)} ${p(1.05, -0.72)} ${p(1.05, -0.02)}`,
    `C${p(1.05, 0.62)} ${p(0.6, 1)} ${p(0, 1)}`,
    `C${p(-0.6, 1)} ${p(-1.05, 0.62)} ${p(-1.05, -0.02)}`,
    `C${p(-1.05, -0.72)} ${p(-0.32, -1.22)} ${p(0, -1.45)}Z`,
  ].join(' ')
}

function star(x: number, y: number, k: number): string {
  return `M${x} ${y - k * 1.6} Q${x} ${y} ${x + k * 1.6} ${y} Q${x} ${y} ${x} ${y + k * 1.6} Q${x} ${y} ${x - k * 1.6} ${y} Q${x} ${y} ${x} ${y - k * 1.6}Z`
}

export function Alvi({ face, size = 104, label }: { face: Face; size?: number; label?: string }) {
  const id = useId().replace(/:/g, '')
  const f = {
    mouthOpen: 0,
    eyeHappy: 0,
    brow: 0,
    blush: 0,
    sweat: 0,
    tear: 0,
    sparkle: 0,
    bounce: 0,
    shiver: 0,
    ...face,
  }
  const soft = mix(f.color, '#f9f9f9', 0.38)
  const deep = mix(f.color, '#404040', 0.22)
  const motion = f.bounce > 0.3 ? 'is-bouncy' : f.shiver > 0.3 ? 'is-nervous' : ''

  // Boca: «ω» al sonreír, abierta al reír o asustarse, curva si no
  const my = 0.3
  let mouth: React.ReactNode
  if (f.mouthOpen > 0.05) {
    const half = 0.12 + 0.05 * f.mouthOpen
    const curve = f.smile * 0.12
    const dropY = 0.22 * f.mouthOpen
    mouth = (
      <path
        d={`M${-half} ${my - curve * 0.2} Q0 ${my + curve * 0.3 - dropY * 0.15} ${half} ${my - curve * 0.2} Q0 ${my + curve + dropY} ${-half} ${my - curve * 0.2}Z`}
        fill={INK}
      />
    )
  } else if (f.smile > 0.2) {
    const w = 0.08
    const h = 0.06 * f.smile
    mouth = (
      <path
        d={`M${-w * 2} ${my - h * 0.2} Q${-w} ${my + h * 1.6} 0 ${my} Q${w} ${my + h * 1.6} ${w * 2} ${my - h * 0.2}`}
        fill="none"
        stroke={INK}
        strokeWidth={0.06}
        strokeLinecap="round"
      />
    )
  } else {
    const half = 0.1 + 0.05 * Math.abs(f.smile)
    const curve = f.smile * 0.14
    mouth = (
      <path
        d={`M${-half} ${my - curve * 0.2} Q0 ${my + curve} ${half} ${my - curve * 0.2}`}
        fill="none"
        stroke={INK}
        strokeWidth={0.06}
        strokeLinecap="round"
      />
    )
  }

  return (
    <svg
      className={`cr-alvi ${motion}`}
      viewBox="-1.75 -1.95 3.5 3.3"
      width={size}
      height={size * (3.3 / 3.5)}
      role={label ? 'img' : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    >
      <defs>
        <linearGradient
          id={`b${id}`}
          x1="0"
          y1="-1.45"
          x2="0"
          y2="1"
          gradientUnits="userSpaceOnUse"
        >
          <stop offset="0" stopColor={mix(soft, '#ffffff', 0.35)} />
          <stop offset="0.5" stopColor={soft} />
          <stop offset="1" stopColor={mix(soft, deep, 0.25)} />
        </linearGradient>
        <filter id={`s${id}`} x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="0.08" />
        </filter>
        <filter id={`a${id}`} x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="0.2" />
        </filter>
        <clipPath id={`c${id}`}>
          <path d={drop(1)} />
        </clipPath>
      </defs>
      {/* Sombra en el suelo */}
      <ellipse
        className="cr-alvi-shadow"
        cx="0"
        cy="1.08"
        rx="0.8"
        ry="0.12"
        fill={deep}
        opacity="0.3"
        filter={`url(#s${id})`}
      />
      <g className="cr-alvi-body">
        {/* Piececitos y bracitos */}
        {[-1, 1].map((s) => (
          <ellipse
            key={`f${s}`}
            cx={s * 0.38}
            cy="0.93"
            rx="0.21"
            ry="0.12"
            fill={deep}
            opacity="0.9"
          />
        ))}
        {[-1, 1].map((s) => (
          <rect
            key={`a${s}`}
            className={s === 1 ? 'cr-alvi-wave' : undefined}
            x={s === 1 ? 0.98 - 0.07 : -0.98 - 0.39}
            y={0.12 - 0.14}
            width="0.46"
            height="0.28"
            rx="0.14"
            fill={mix(soft, deep, 0.35)}
            transform={`rotate(${s * 28} ${s * 0.98} 0.12)`}
          />
        ))}
        {/* Aura esponjosa y cuerpo de malvavisco */}
        <path d={drop(1)} fill={f.color} opacity="0.45" filter={`url(#a${id})`} />
        <path d={drop(1)} fill={`url(#b${id})`} />
        <g clipPath={`url(#c${id})`}>
          <path
            d={drop(1, 0.1, 0.16)}
            fill="none"
            stroke={deep}
            strokeOpacity="0.22"
            strokeWidth="0.5"
            filter={`url(#a${id})`}
          />
          <ellipse
            cx="-0.42"
            cy="-0.55"
            rx="0.22"
            ry="0.15"
            fill="#fff"
            opacity="0.75"
            filter={`url(#s${id})`}
          />
          <circle cx="-0.18" cy="-0.82" r="0.05" fill="#fff" opacity="0.8" />
        </g>
        {/* Mejillas */}
        {f.blush > 0.01 &&
          [-1, 1].map((s) => (
            <ellipse
              key={`k${s}`}
              cx={s * 0.6}
              cy="0.32"
              rx="0.18"
              ry="0.105"
              fill="#9d9d9d"
              opacity={0.55 * f.blush}
            />
          ))}
        {/* Ojos (parpadean) o arcos felices */}
        {[-1, 1].map((s) => {
          const x = s * 0.36
          const y = 0.04
          if (f.eyeHappy > 0.5) {
            return (
              <path
                key={`e${s}`}
                d={`M${x - 0.14} ${y + 0.05} Q${x} ${y - 0.17 * f.eyeHappy} ${x + 0.14} ${y + 0.05}`}
                fill="none"
                stroke={INK}
                strokeWidth="0.08"
                strokeLinecap="round"
              />
            )
          }
          return (
            <g key={`e${s}`} className="cr-alvi-eye" style={{ transformOrigin: `${x}px ${y}px` }}>
              <ellipse cx={x} cy={y} rx="0.15" ry="0.19" fill={INK} />
              <circle cx={x - 0.05} cy={y - 0.08} r="0.075" fill="#fff" />
              <circle cx={x + 0.06} cy={y + 0.07} r="0.03" fill="#fff" opacity="0.9" />
            </g>
          )
        })}
        {/* Cejitas de preocupación */}
        {f.brow !== 0 &&
          [-1, 1].map((s) => {
            const x = s * 0.36
            return (
              <line
                key={`w${s}`}
                x1={x - s * 0.09}
                y1={0.04 - 0.31 + f.brow * 0.08}
                x2={x + s * 0.14}
                y2={0.04 - 0.31 - f.brow * 0.05}
                stroke={INK}
                strokeWidth="0.07"
                strokeLinecap="round"
              />
            )
          })}
        {mouth}
        {f.sweat > 0.05 && (
          <path
            className="cr-alvi-sweat"
            d={drop(0.11, 0.8, -0.55)}
            fill="#e6e6e6"
            opacity={f.sweat}
          />
        )}
        {f.tear > 0.05 && (
          <path
            className="cr-alvi-tear"
            d={drop(0.09, -0.4, 0.22)}
            fill="#e6e6e6"
            opacity={f.tear}
          />
        )}
      </g>
      {/* Destellos (radiante) */}
      {f.sparkle > 0.05 &&
        [0, 1, 2, 3].map((i) => {
          const a = (i * Math.PI) / 2 + 0.4
          return (
            <path
              key={`z${i}`}
              className="cr-alvi-spark"
              style={{ animationDelay: `${i * 0.35}s` }}
              d={star(Math.cos(a) * 1.5, -0.35 + Math.sin(a) * 1.3, 0.12 * f.sparkle)}
              fill={i % 2 ? '#e0e0e0' : '#ffffff'}
            />
          )
        })}
    </svg>
  )
}
