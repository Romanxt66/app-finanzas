import type { IconName } from '../design'

// Icono de cada categoría según su nombre (mismas reglas que la app Android). Las categorías no guardan
// icono en el servidor: se deduce aquí y, si no se reconoce, se usa una etiqueta.

const RULES: [string[], IconName][] = [
  [
    ['arriendo', 'alquiler', 'renta', 'hogar', 'casa', 'vivienda', 'hipoteca', 'administracion'],
    'home',
  ],
  [['restaurante', 'domicilio', 'rappi', 'cafe', 'comida rapida', 'almuerzo'], 'restaurant'],
  [['comida', 'mercado', 'supermercado', 'alimenta', 'viveres', 'fruta'], 'food'],
  [['salud', 'medic', 'farmacia', 'eps', 'doctor', 'odontolog', 'seguro medico'], 'health'],
  [
    [
      'transporte',
      'carro',
      'auto',
      'moto',
      'gasolina',
      'combustible',
      'taxi',
      'uber',
      'parqueadero',
      'peaje',
    ],
    'car',
  ],
  [['gimnasio', 'deporte', 'gym', 'futbol', 'tenis', 'yoga'], 'sport'],
  [['regalo', 'cumpleanos', 'donacion', 'navidad'], 'gift'],
  [['educacion', 'colegio', 'universidad', 'curso', 'libro', 'estudio', 'matricula'], 'school'],
  [['viaje', 'vacacion', 'vuelo', 'hotel', 'turismo'], 'travel'],
  [
    [
      'ocio',
      'entretenimiento',
      'cine',
      'netflix',
      'spotify',
      'streaming',
      'suscripcion',
      'juego',
      'concierto',
    ],
    'film',
  ],
  [['ropa', 'compras', 'shopping', 'tienda', 'calzado'], 'bag'],
  [['servicio', 'luz', 'agua', 'gas', 'energia', 'factura', 'internet'], 'bolt'],
  [['celular', 'telefono', 'plan movil', 'datos'], 'phone'],
  [['sueldo', 'salario', 'nomina', 'quincena'], 'salary'],
  [['freelance', 'trabajo', 'negocio', 'honorario', 'cliente'], 'briefcase'],
  [['ahorro', 'inversion', 'interes', 'rendimiento', 'cdt'], 'target'],
  [['transferencia'], 'swap'],
]

const fold = (s: string) => s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')

export function categoryIcon(name: string | null | undefined, kind?: string): IconName {
  const fallback: IconName = kind === 'income' ? 'receive' : 'tag'
  if (!name?.trim()) return fallback
  const n = fold(name)
  for (const [words, icon] of RULES) if (words.some((w) => n.includes(w))) return icon
  return fallback
}
