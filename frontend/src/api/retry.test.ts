import { vi } from 'vitest'
import { api, ApiError } from './client'

const ok = (body: unknown) => new Response(JSON.stringify(body), { status: 200 })
const down = () => new Response('', { status: 503 })

describe('reintentos ante fallos pasajeros', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => {
    vi.useRealTimers()
    vi.restoreAllMocks()
  })

  it('una lectura que falla por un momento se reintenta y llega el dato (no queda en cero)', async () => {
    const fetchMock = vi
      .spyOn(globalThis, 'fetch')
      .mockRejectedValueOnce(new TypeError('Failed to fetch'))
      .mockResolvedValueOnce(down())
      .mockResolvedValueOnce(ok({ balance: '100' }))
    const result = api<{ balance: string }>('/accounts', { auth: false })
    await vi.advanceTimersByTimeAsync(3000)
    await expect(result).resolves.toEqual({ balance: '100' })
    expect(fetchMock).toHaveBeenCalledTimes(3)
  })

  it('si el servidor sigue caído, el error llega (para mostrar el aviso)', async () => {
    vi.spyOn(globalThis, 'fetch').mockImplementation(async () => down())
    const result = api('/accounts', { auth: false }).catch((e) => e)
    await vi.advanceTimersByTimeAsync(3000)
    const error = await result
    expect(error).toBeInstanceOf(ApiError)
    expect((error as ApiError).status).toBe(503)
  })

  it('las escrituras no se repiten (podrían duplicarse)', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockImplementation(async () => down())
    await expect(
      api('/transactions', { method: 'POST', body: {}, auth: false }),
    ).rejects.toBeInstanceOf(ApiError)
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })
})
