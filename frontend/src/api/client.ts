import type { components } from './schema'

export type Schemas = components['schemas']

const BASE = import.meta.env.VITE_API_URL ?? ''
const ACCESS = 'access_token'
const REFRESH = 'refresh_token'

export class ApiError extends Error {
  readonly status: number
  readonly code: string

  constructor(status: number, code: string, message: string) {
    super(message)
    this.status = status
    this.code = code
  }
}

export const tokens = {
  get access() {
    return localStorage.getItem(ACCESS)
  },
  get refresh() {
    return localStorage.getItem(REFRESH)
  },
  set(pair: { access_token: string; refresh_token: string }) {
    localStorage.setItem(ACCESS, pair.access_token)
    localStorage.setItem(REFRESH, pair.refresh_token)
  },
  clear() {
    localStorage.removeItem(ACCESS)
    localStorage.removeItem(REFRESH)
  },
}

let onUnauthorized: () => void = () => {}
export function setUnauthorizedHandler(fn: () => void) {
  onUnauthorized = fn
}

let refreshing: Promise<boolean> | null = null

async function refreshTokens(): Promise<boolean> {
  const refresh = tokens.refresh
  if (!refresh) return false
  const res = await fetch(`${BASE}/api/v1/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token: refresh }),
  })
  if (!res.ok) return false
  tokens.set(await res.json())
  return true
}

type Query = Record<string, string | number | boolean | undefined | null>

interface Options {
  method?: string
  body?: unknown
  query?: Query
  auth?: boolean
}

export async function api<T>(path: string, opts: Options = {}): Promise<T> {
  const { method = 'GET', body, query, auth = true } = opts
  const params = new URLSearchParams()
  for (const [k, v] of Object.entries(query ?? {})) {
    if (v !== undefined && v !== null && v !== '') params.set(k, String(v))
  }
  const url = `${BASE}/api/v1${path}${params.size ? `?${params}` : ''}`

  const send = () =>
    fetch(url, {
      method,
      headers: {
        ...(body !== undefined && { 'Content-Type': 'application/json' }),
        ...(auth && tokens.access && { Authorization: `Bearer ${tokens.access}` }),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    })

  let res = await send()
  if (res.status === 401 && auth && tokens.refresh) {
    refreshing ??= refreshTokens().finally(() => (refreshing = null))
    if (await refreshing) res = await send()
  }
  if (res.status === 401 && auth) {
    tokens.clear()
    onUnauthorized()
  }
  if (!res.ok) {
    const data = await res.json().catch(() => null)
    throw new ApiError(
      res.status,
      data?.error?.code ?? 'unknown',
      data?.error?.message ?? 'Error inesperado',
    )
  }
  return res.status === 204 ? (undefined as T) : ((await res.json()) as T)
}
