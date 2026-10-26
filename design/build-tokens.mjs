// Genera frontend/src/design/tokens.css desde design/tokens.json (fuente única del diseño "Cristal").
// Android/otros: leer design/tokens.json directamente (ver design/README.md).
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)))
const tokens = JSON.parse(readFileSync(resolve(root, 'tokens.json'), 'utf8'))

// Capa cálida solo para la web React: sustituye por nombre (o añade) tokens de tokens.json.
// Flutter no la lee: sigue con tokens.json tal cual.
const overlay = JSON.parse(readFileSync(resolve(root, 'tokens.calido.json'), 'utf8'))
for (const family of ['color', 'spacing', 'radius', 'shadow', 'blur']) {
  const byName = new Map((tokens[family]?.tokens ?? []).map((t) => [t.name, t]))
  for (const t of overlay[family]?.tokens ?? []) byName.set(t.name, t)
  tokens[family] = { ...tokens[family], tokens: [...byName.values()] }
}
const out = resolve(root, '../frontend/src/design/tokens.css')

const [first, ...others] = tokens.color.themes.map((t) => t.id)
const alias = (v) => v.replace(/^\{(.+)\}$/, 'var(--$1)')
const themed = (list, theme) =>
  list
    .map((t) => {
      const value = typeof t.value === 'string' ? t.value : (t.value[theme] ?? t.value[first])
      return `  --${t.name}: ${alias(value)};`
    })
    .join('\n')

const plain = (list) => list.map((t) => `  --${t.name}: ${t.value};`).join('\n')
const themedShadows = (theme) => themed(tokens.shadow.tokens, theme)

const base = [
  `  --font-sans: ${tokens.type.families.sans};`,
  plain(tokens.spacing.tokens),
  plain(tokens.radius.tokens),
  plain(tokens.blur.tokens),
].join('\n')

const block = (theme) =>
  `${themed(tokens.color.tokens, theme)}\n${themedShadows(theme)}\n  color-scheme: ${theme};`

const css = `/* ${tokens.name} — generated from design/tokens.json. No editar a mano: npm run gen:tokens */
:root {
${base}
${block(first)}
}
${others
  .map(
    (theme) => `
@media (prefers-color-scheme: ${theme}) {
  :root:not([data-theme='${first}']) {
${block(theme).replace(/^/gm, '  ')}
  }
}
:root[data-theme='${theme}'] {
${block(theme)}
}
`,
  )
  .join('')}`

writeFileSync(out, css)
console.log(`tokens.css generado (${tokens.color.tokens.length} colores)`)
