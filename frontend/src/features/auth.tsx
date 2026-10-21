import { useQuery, useQueryClient } from '@tanstack/react-query'
import { createContext, useCallback, useContext, useEffect, type ReactNode } from 'react'
import { api, setUnauthorizedHandler, tokens, type Schemas } from '../api/client'

type User = Schemas['UserOut']

interface AuthValue {
  user: User | null
  loading: boolean
  login: (email: string, password: string) => Promise<void>
  register: (data: Schemas['RegisterIn']) => Promise<void>
  logout: () => void
}

const AuthContext = createContext<AuthValue | null>(null)
const ME_KEY = ['me']

export function AuthProvider({ children }: { children: ReactNode }) {
  const qc = useQueryClient()
  const { data, isLoading } = useQuery({
    queryKey: ME_KEY,
    queryFn: () => api<User>('/auth/me'),
    enabled: !!tokens.access,
    retry: false,
  })

  const logout = useCallback(() => {
    tokens.clear()
    qc.clear()
  }, [qc])

  useEffect(() => setUnauthorizedHandler(logout), [logout])

  const login = useCallback(
    async (email: string, password: string) => {
      const pair = await api<Schemas['TokenPair']>('/auth/login', {
        method: 'POST',
        body: { email, password },
        auth: false,
      })
      tokens.set(pair)
      await qc.invalidateQueries({ queryKey: ME_KEY })
    },
    [qc],
  )

  const register = useCallback(
    async (body: Schemas['RegisterIn']) => {
      await api('/auth/register', { method: 'POST', body, auth: false })
      await login(body.email, body.password)
    },
    [login],
  )

  const value: AuthValue = {
    user: tokens.access ? (data ?? null) : null,
    loading: !!tokens.access && isLoading,
    login,
    register,
    logout,
  }
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthValue {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth debe usarse dentro de AuthProvider')
  return ctx
}
