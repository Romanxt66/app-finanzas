import { passwordProblem, PASSWORD_RULES } from './password'

describe('passwordProblem', () => {
  it.each([
    ['corta1', 'al menos 8 caracteres'],
    ['soloLetrasAqui', 'al menos un número'],
    ['1234567890', 'al menos una letra'],
    ['a1'.repeat(70), 'no puede superar 128'],
  ])('"%s" → explica el motivo', (password, reason) => {
    expect(passwordProblem(password)).toContain(reason)
  })

  it('acepta una contraseña válida (con tildes y símbolos)', () => {
    expect(passwordProblem('Contraseña-2026')).toBeNull()
  })

  it('cada regla tiene etiqueta y mensaje propios', () => {
    expect(new Set(PASSWORD_RULES.map((r) => r.id)).size).toBe(PASSWORD_RULES.length)
  })
})
