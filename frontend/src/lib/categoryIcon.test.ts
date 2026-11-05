import { categoryIcon } from './categoryIcon'

describe('categoryIcon', () => {
  it('deduce el icono del nombre, con o sin tildes', () => {
    expect(categoryIcon('Comida')).toBe('food')
    expect(categoryIcon('Educación')).toBe('school')
    expect(categoryIcon('Arriendo apartamento')).toBe('home')
    expect(categoryIcon('Netflix')).toBe('film')
    expect(categoryIcon('Gasolina')).toBe('car')
    expect(categoryIcon('Sueldo', 'income')).toBe('salary')
    expect(categoryIcon('Cosas raras')).toBe('tag')
    expect(categoryIcon('Cosas raras', 'income')).toBe('receive')
  })
})
