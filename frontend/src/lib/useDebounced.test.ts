import { act, renderHook } from '@testing-library/react'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'
import { useDebounced } from './useDebounced'

beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())

test('solo entrega el valor cuando deja de cambiar', () => {
  const { result, rerender } = renderHook(({ v }) => useDebounced(v, 300), {
    initialProps: { v: '' },
  })
  rerender({ v: 'ca' })
  act(() => vi.advanceTimersByTime(200))
  rerender({ v: 'caf' })
  act(() => vi.advanceTimersByTime(200))
  expect(result.current).toBe('')
  act(() => vi.advanceTimersByTime(100))
  expect(result.current).toBe('caf')
})
