import { financeMood } from './mood'

describe('ánimo de Alvi', () => {
  it('radiante si ahorra, va en ritmo, sin excesos y con saldo', () => {
    const m = financeMood({
      income: 1000,
      expense: 500,
      balance: 100,
      allowanceStatus: 'ok',
      budgets: [{ amount: 100, spent: 50 }],
    })
    expect(m.level).toBe(4)
    expect(m.reasons).toContain('ahorras el 50 %')
  })

  it('agobiada si gasta más de lo que entra, sin margen y en negativo', () => {
    const m = financeMood({
      income: 100,
      expense: 300,
      balance: -50,
      allowanceStatus: 'over',
      budgets: [{ amount: 10, spent: 20 }],
    })
    expect(m.level).toBe(0)
    expect(m.reasons).toEqual(
      expect.arrayContaining(['saldo en negativo', '1 presupuesto excedido']),
    )
  })

  it('sin datos queda tranquila', () => {
    expect(financeMood({ income: 0, expense: 0, balance: 0 }).level).toBe(2)
  })
})
