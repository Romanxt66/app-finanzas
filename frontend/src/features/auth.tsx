import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useCallback, useEffect, useState, type ReactNode } from 'react'
import { AuthContext } from './authContext'
import { api, setUnauthorizedHandler, tokens, type Schemas } from '../api/client'

type User = Schemas['UserOut']

export interface AuthValue {
  user: User | null
  loading: boolean
  login: (email: string, password: string) => Promise<void>
  register: (data: Schemas['RegisterIn']) => Promise<void>
  logout: () => void
}

const ME_KEY = ['me']

export function AuthProvider({ children }: { children: ReactNode }) {
  const qc = useQueryClient()
  // Estado reactivo: leer localStorage en el render no provoca re-render al iniciar sesión.
  const [authed, setAuthed] = useState(() => !!tokens.access)
  const { data, isLoading } = useQuery({
    queryKey: ME_KEY,
    queryFn: () => api<User>('/auth/me'),
    enabled: authed,
    retry: false,
  })

  const logout = useCallback(() => {
    tokens.clear()
    setAuthed(false)
    qc.clear()
  }, [qc])

  useEffect(() => setUnauthorizedHandler(logout), [logout])

  const login = useCallback(async (email: string, password: string) => {
    const pair = await api<Schemas['TokenPair']>('/auth/login', {
      method: 'POST',
      body: { email, password },
      auth: false,
    })
    tokens.set(pair)
    setAuthed(true)
  }, [])

  const register = useCallback(
    async (body: Schemas['RegisterIn']) => {
      await api('/auth/register', { method: 'POST', body, auth: false })
      await login(body.email, body.password)
    },
    [login],
  )

  const value: AuthValue = {
    user: authed ? (data ?? null) : null,
    loading: authed && isLoading,
    login,
    register,
    logout,
  }
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
