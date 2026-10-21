import { afterEach, beforeEach, vi } from 'vitest'
import { api, ApiError, tokens } from './client'

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

describe('api client', () => {
  beforeEach(() => localStorage.clear())
  afterEach(() => vi.restoreAllMocks())

  it('envía el token y serializa query ignorando vacíos', async () => {
    tokens.set({ access_token: 'a', refresh_token: 'r' })
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValue(json(200, []))
    await api('/accounts', { query: { include_archived: true, x: '' } })
    const [url, init] = fetchMock.mock.calls[0]
    expect(url).toBe('/api/v1/accounts?include_archived=true')
    expect((init?.headers as Record<string, string>).Authorization).toBe('Bearer a')
  })

  it('renueva el token ante un 401 y reintenta', async () => {
    tokens.set({ access_token: 'old', refresh_token: 'r' })
    vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(json(401, { error: { code: 'unauthorized', message: 'x' } }))
      .mockResolvedValueOnce(
        json(200, { access_token: 'new', refresh_token: 'r2', token_type: 'bearer' }),
      )
      .mockResolvedValueOnce(json(200, { ok: true }))
    expect(await api('/auth/me')).toEqual({ ok: true })
    expect(tokens.access).toBe('new')
  })

  it('mapea el formato de error de la API', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      json(409, { error: { code: 'conflict', message: 'Duplicado' } }),
    )
    await expect(api('/categories', { method: 'POST', body: {} })).rejects.toMatchObject({
      status: 409,
      code: 'conflict',
      message: 'Duplicado',
    })
    expect(ApiError).toBeDefined()
  })
})
