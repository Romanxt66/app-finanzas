import { useEffect, useState } from 'react'

/** El valor, pero solo cuando lleva `ms` sin cambiar (p. ej. buscar al dejar de escribir). */
export function useDebounced<T>(value: T, ms = 300): T {
  const [settled, setSettled] = useState(value)
  useEffect(() => {
    const id = setTimeout(() => setSettled(value), ms)
    return () => clearTimeout(id)
  }, [value, ms])
  return settled
}
