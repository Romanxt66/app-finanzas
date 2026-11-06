import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { CreateSection } from '.'

describe('CreateSection', () => {
  it('sin datos sale abierta y sin botón de cerrar', () => {
    render(
      <CreateSection title="Nueva meta" hasData={false}>
        <p>formulario</p>
      </CreateSection>,
    )
    expect(screen.getByText('formulario')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Cerrar' })).not.toBeInTheDocument()
  })

  it('con datos queda tras su botón; se abre y se vuelve a cerrar', async () => {
    render(
      <CreateSection title="Nueva meta" hasData>
        <input aria-label="Nombre" />
      </CreateSection>,
    )
    expect(screen.queryByLabelText('Nombre')).not.toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Nueva meta' }))
    expect(screen.getByLabelText('Nombre')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Cerrar' }))
    expect(screen.queryByLabelText('Nombre')).not.toBeInTheDocument()
  })

  it('si se empieza a escribir, no se pliega aunque lleguen datos', async () => {
    const { rerender } = render(
      <CreateSection title="Nueva cuenta" hasData={false}>
        <input aria-label="Nombre" />
      </CreateSection>,
    )
    await userEvent.type(screen.getByLabelText('Nombre'), 'Caja')
    rerender(
      <CreateSection title="Nueva cuenta" hasData>
        <input aria-label="Nombre" />
      </CreateSection>,
    )
    expect(screen.getByLabelText('Nombre')).toBeInTheDocument()
  })
})
