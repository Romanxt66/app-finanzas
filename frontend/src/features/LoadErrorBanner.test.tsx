import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useQuery } from '@tanstack/react-query'
import { renderApp } from '../test-utils'
import { LoadErrorBanner } from './LoadErrorBanner'

let fail = true
function Probe() {
  const { data } = useQuery({
    queryKey: ['probe'],
    queryFn: async () => {
      if (fail) throw new Error('caído')
      return 'datos'
    },
    retry: false,
  })
  return <p>{data ?? 'sin datos'}</p>
}

it('si una consulta falla avisa en vez de mostrar ceros, y «Reintentar» la vuelve a pedir', async () => {
  renderApp(
    <>
      <LoadErrorBanner />
      <Probe />
    </>,
  )
  expect(await screen.findByText('No pudimos cargar tus datos.')).toBeInTheDocument()
  fail = false
  await userEvent.click(screen.getByRole('button', { name: 'Reintentar' }))
  expect(await screen.findByText('datos')).toBeInTheDocument()
  expect(screen.queryByText('No pudimos cargar tus datos.')).not.toBeInTheDocument()
})
