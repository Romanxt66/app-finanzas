// Iconos de Cristal: trazo de 1.8 en caja de 24, currentColor, sin rellenos.
const PATHS = {
  home: 'M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z',
  chart: 'M4 20V10M10 20V4M16 20v-7M22 20H2',
  wallet: 'M3 7a2 2 0 0 1 2-2h13v4M3 7v11a2 2 0 0 0 2 2h15V9H5a2 2 0 0 1-2-2zM16 14.5h.01',
  card: 'M3 6h18v12H3zM3 10h18M7 15h4',
  user: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0',
  plus: 'M12 5v14M5 12h14',
  send: 'M7 17 17 7M9 7h8v8',
  receive: 'M17 7 7 17M15 17H7V9',
  swap: 'M7 4 3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7',
  up: 'M12 19V5M6 11l6-6 6 6',
  down: 'M12 5v14M6 13l6 6 6-6',
  salary: 'M3 7h18v10H3zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM6 10v.01M18 14v.01',
  target: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM12 12h.01',
  eye: 'M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  // Ampliación del sistema para las pantallas de la app (mismo trazo y caja)
  tag: 'M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9zM8 8h.01',
  list: 'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01',
  logout: 'M9 21H5a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h4M16 17l5-5-5-5M21 12H9',
  edit: 'M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4',
  trash: 'M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3',
  archive: 'M3 5h18v4H3zM5 9v10h14V9M10 13h4',
  restore: 'M3 12a9 9 0 1 0 3-6.7L3 8M3 3v5h5',
  check: 'M5 12.5l4.5 4.5L19 7.5',
  sun: 'M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4',
  moon: 'M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z',
  download: 'M12 4v11M7 10l5 5 5-5M4 20h16',
  mail: 'M3 6h18v12H3zM3 7l9 6 9-6',
  lock: 'M5 11h14v10H5zM8 11V8a4 4 0 0 1 8 0v3M12 15v2',
  arrow: 'M5 12h14M13 6l6 6-6 6',
  eyeOff:
    'M3 3l18 18M10.6 6.1A10 10 0 0 1 12 6c6.5 0 10 6 10 6a17 17 0 0 1-3.2 3.9M6.6 7.7A17 17 0 0 0 2 12s3.5 7 10 7a9.6 9.6 0 0 0 4.2-1M9.9 9.9a3 3 0 0 0 4.2 4.2',
  shield: 'M12 3l8 3v6c0 4.5-3.2 8-8 9-4.8-1-8-4.5-8-9V6zM9 12l2 2 4-4',
  fingerprint:
    'M12 11a2 2 0 0 0-2 2c0 2-.4 4-1.2 5.5M12 8a5 5 0 0 0-5 5c0 1.5-.2 3-.7 4.3M12 5a8 8 0 0 0-8 8M15 17.5c.6-1.3 1-2.8 1-4.5a4 4 0 0 0-1.2-2.8M20 13c0-3.9-3.6-8-8-8',
  key: 'M15 8a4 4 0 1 1-1.2 2.8L4 20v-3h3v-3h3l1.8-1.8M16.5 7.5h.01',
  search: 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM21 21l-4.3-4.3',
} as const

export type IconName = keyof typeof PATHS

export function Icon({ name, className }: { name: IconName; className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className={className}
    >
      <path d={PATHS[name]} />
    </svg>
  )
}
