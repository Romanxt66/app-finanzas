import { detectDelimiter, guessDateFormat, parseAmount, parseCsv, parseDate } from './csv'

describe('parseCsv', () => {
  it('lee comillas, comas internas, comillas escapadas y saltos dentro de un campo', () => {
    const rows = parseCsv('a,b,c\n"x, y","di ""hola""","l1\nl2"\n')
    expect(rows).toEqual([
      ['a', 'b', 'c'],
      ['x, y', 'di "hola"', 'l1\nl2'],
    ])
  })
  it('acepta CRLF, BOM y descarta líneas vacías', () => {
    expect(parseCsv('﻿a;b\r\n1;2\r\n\r\n3;4')).toEqual([
      ['a', 'b'],
      ['1', '2'],
      ['3', '4'],
    ])
  })
  it('conserva columnas vacías y descarta filas totalmente vacías', () => {
    expect(parseCsv('a,,c\n1,,3')).toEqual([
      ['a', '', 'c'],
      ['1', '', '3'],
    ])
    expect(parseCsv('a,b\n,,\n1,2')).toEqual([
      ['a', 'b'],
      ['1', '2'],
    ])
  })
  it('archivo vacío → sin filas', () => {
    expect(parseCsv('')).toEqual([])
  })
})

describe('detectDelimiter', () => {
  it.each([
    ['a,b,c\n1,2,3', ','],
    ['a;b;c\n1;2;3', ';'],
    ['a\tb\tc\n1\t2\t3', '\t'],
    ['"a,b";c;d\n"1,5";2;3', ';'], // las comas entre comillas no cuentan
  ])('%j → %j', (text, expected) => expect(detectDelimiter(text)).toBe(expected))
})

describe('parseAmount', () => {
  it.each([
    ['1.234,56', 1234.56],
    ['1,234.56', 1234.56],
    ['-$ 1.234', -1234],
    ['$ 4.850.000', 4850000],
    ['(500)', -500],
    ['500-', -500],
    ['12,5', 12.5],
    ['12.5', 12.5],
    ['1.234', 1234], // tres dígitos tras un único separador = miles
    ['+75', 75],
    ['0', 0],
  ])('%j → %j', (raw, expected) => expect(parseAmount(raw)).toBe(expected))

  it.each(['', '   ', 'abc', '1.2.3x', '--5'])('%j no es un monto', (raw) => {
    expect(parseAmount(raw)).toBeNull()
  })
})

describe('parseDate / guessDateFormat', () => {
  it('convierte según el formato y valida el calendario', () => {
    expect(parseDate('2026-03-05', 'ymd')).toBe('2026-03-05')
    expect(parseDate('05/03/2026', 'dmy')).toBe('2026-03-05')
    expect(parseDate('03/05/2026', 'mdy')).toBe('2026-03-05')
    expect(parseDate('5.3.26', 'dmy')).toBe('2026-03-05')
    expect(parseDate('31/02/2026', 'dmy')).toBeNull()
    expect(parseDate('2028-02-29', 'ymd')).toBe('2028-02-29')
    expect(parseDate('2026-02-29', 'ymd')).toBeNull()
    expect(parseDate('hola', 'dmy')).toBeNull()
  })
  it('ignora la hora al final', () => {
    expect(parseDate('2026-03-05 14:30:00', 'ymd')).toBe('2026-03-05')
  })
  it('adivina el orden por los valores imposibles en el otro formato', () => {
    expect(guessDateFormat(['2026-03-05'])).toBe('ymd')
    expect(guessDateFormat(['25/03/2026', '01/04/2026'])).toBe('dmy')
    expect(guessDateFormat(['03/25/2026', '04/01/2026'])).toBe('mdy')
    expect(guessDateFormat(['01/02/2026'])).toBe('dmy') // ambiguo: día primero
  })
})
