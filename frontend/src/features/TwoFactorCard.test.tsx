import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, expect, test, vi } from 'vitest'
import { mockApi, renderApp, user } from '../test-utils'
import { TwoFactorCard } from './TwoFactorCard'

afterEach(() => vi.restoreAllMocks())

test('activa la verificación con el QR, muestra los códigos y queda activa', async () => {
  let enabled = false
  const calls = mockApi({
    'GET /auth/me': () => ({ ...user, two_factor_enabled: enabled }),
    'POST /auth/2fa/setup': {
      secret: 'JBSWY3DPEHPK3PXP',
      otpauth_uri: 'otpauth://totp/Alvea:x@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Alvea',
    },
    'POST /auth/2fa/enable': () => {
      enabled = true
      return { recovery_codes: ['aaaa-bbbb', 'cccc-dddd'] }
    },
  })
  renderApp(<TwoFactorCard />)
  await userEvent.click(await screen.findByRole('button', { name: 'Activar' }))
  expect(await screen.findByRole('img', { name: /Código QR/ })).toBeInTheDocument()
  expect(screen.getByText('JBSW Y3DP EHPK 3PXP')).toBeInTheDocument()
  await userEvent.type(screen.getByLabelText('Código de 6 dígitos'), '123 456')
  await userEvent.click(screen.getByRole('button', { name: 'Activar' }))
  expect(await screen.findByText('aaaa-bbbb')).toBeInTheDocument()
  expect(calls.find((c) => c.path === '/auth/2fa/enable')?.body).toEqual({ code: '123456' })
  await userEvent.click(screen.getByRole('button', { name: 'Ya los guardé' }))
  expect(await screen.findByText('Activa')).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Desactivar' })).toBeInTheDocument()
})

test('desactivar pide contraseña y código', async () => {
  const calls = mockApi({
    'GET /auth/me': { ...user, two_factor_enabled: true },
    'POST /auth/2fa/disable': { status: 204, body: null },
  })
  renderApp(<TwoFactorCard />)
  await userEvent.click(await screen.findByRole('button', { name: 'Desactivar' }))
  await userEvent.type(screen.getByLabelText('Contraseña'), 'password-123')
  await userEvent.type(screen.getByLabelText('Código de 6 dígitos'), '654321')
  await userEvent.click(screen.getByRole('button', { name: 'Desactivar' }))
  await vi.waitFor(() =>
    expect(calls.find((c) => c.path === '/auth/2fa/disable')?.body).toEqual({
      password: 'password-123',
      code: '654321',
    }),
  )
})
