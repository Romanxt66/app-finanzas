import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useForm, useWatch } from 'react-hook-form'
import { vi } from 'vitest'
import { mockApi, renderApp } from '../test-utils'
import { CategorySelect } from './CategorySelect'

afterEach(() => vi.restoreAllMocks())

type Cat = { id: string; created_at: string; name: string; kind: 'income' | 'expense' }
let store: Cat[]

const SUGGESTIONS = { expense: ['Comida', 'Transporte', 'Ocio'], income: ['Nómina'] }

function api() {
  return mockApi({
    'GET /categories': () => store,
    'GET /categories/suggestions': SUGGESTIONS,
    'POST /categories': ({ body }) => {
      const input = body as { name: string; kind: Cat['kind'] }
      const created: Cat = { id: `nueva-${store.length}`, created_at: '', ...input }
      store = [...store, created]
      return { status: 201, body: created }
    },
  })
}

function Form({ onSubmit }: { onSubmit: (values: { category_id: string }) => void }) {
  const { register, handleSubmit, control } = useForm({ defaultValues: { category_id: '' } })
  const value = useWatch({ control, name: 'category_id' })
  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <CategorySelect kind="expense" {...register('category_id')} />
      <output aria-label="valor del formulario">{value}</output>
      <button type="submit">Guardar</button>
    </form>
  )
}

const select = () => screen.getByLabelText('Categoría') as HTMLSelectElement
const formValue = () => screen.getByLabelText('valor del formulario')

beforeEach(() => {
  store = [{ id: 'c1', created_at: '', name: 'Comida', kind: 'expense' }]
})

describe('CategorySelect', () => {
  it('ofrece las del usuario, las sugeridas que faltan y crear una nueva', async () => {
    api()
    renderApp(<Form onSubmit={() => {}} />)
    await waitFor(() => expect(select().options.length).toBeGreaterThan(2))
    expect(Array.from(select().options).map((o) => o.textContent)).toEqual([
      'Sin categoría',
      'Comida', // ya existe: no se repite como sugerida
      'Transporte · sugerida',
      'Ocio · sugerida',
      '＋ Nueva categoría…',
    ])
  })

  it('solo muestra las sugeridas del tipo pedido', async () => {
    api()
    renderApp(<Form onSubmit={() => {}} />)
    await waitFor(() => expect(select().options.length).toBeGreaterThan(2))
    expect(screen.queryByText(/Nómina/)).not.toBeInTheDocument()
  })

  it('elegir una sugerida la crea y la deja seleccionada en el formulario', async () => {
    const calls = api()
    renderApp(<Form onSubmit={() => {}} />)
    await waitFor(() => expect(select().options.length).toBeGreaterThan(2))
    await userEvent.selectOptions(select(), 'suggested:Transporte')
    await waitFor(() => expect(formValue()).toHaveTextContent('nueva-1'))
    expect(calls.find((c) => c.method === 'POST')?.body).toEqual({
      name: 'Transporte',
      kind: 'expense',
    })
    expect(select().value).toBe('nueva-1')
    // ya es una categoría propia: deja de ofrecerse como sugerida
    expect(screen.queryByText('Transporte · sugerida')).not.toBeInTheDocument()
  })

  it('«Nueva categoría…» abre un diálogo, crea la categoría y la selecciona sin enviar el formulario', async () => {
    const calls = api()
    const onSubmit = vi.fn()
    renderApp(<Form onSubmit={onSubmit} />)
    await waitFor(() => expect(select().options.length).toBeGreaterThan(2))
    await userEvent.selectOptions(select(), '__new__')
    expect(formValue()).toHaveTextContent('') // el valor especial nunca llega al formulario
    const dialog = await screen.findByRole('dialog', { name: 'Nueva categoría' })
    await userEvent.type(screen.getByLabelText('Nombre de la categoría'), 'Mascotas')
    await userEvent.click(screen.getByRole('button', { name: 'Crear' }))
    await waitFor(() => expect(formValue()).toHaveTextContent('nueva-1'))
    expect(calls.find((c) => c.method === 'POST')?.body).toEqual({
      name: 'Mascotas',
      kind: 'expense',
    })
    expect(dialog).not.toBeInTheDocument()
    expect(onSubmit).not.toHaveBeenCalled()
  })

  it('si el nombre ya existe, selecciona esa categoría en vez de duplicarla', async () => {
    const calls = api()
    renderApp(<Form onSubmit={() => {}} />)
    await waitFor(() => expect(select().options.length).toBeGreaterThan(2))
    await userEvent.selectOptions(select(), '__new__')
    await userEvent.type(await screen.findByLabelText('Nombre de la categoría'), 'comida')
    await userEvent.click(screen.getByRole('button', { name: 'Crear' }))
    await waitFor(() => expect(formValue()).toHaveTextContent('c1'))
    expect(calls.some((c) => c.method === 'POST')).toBe(false)
  })

  it('cancelar el diálogo deja el valor como estaba', async () => {
    api()
    renderApp(<Form onSubmit={() => {}} />)
    await waitFor(() => expect(select().options.length).toBeGreaterThan(2))
    await userEvent.selectOptions(select(), 'c1')
    await userEvent.selectOptions(select(), '__new__')
    await userEvent.click(await screen.findByRole('button', { name: 'Cancelar' }))
    expect(formValue()).toHaveTextContent('c1')
    expect(select().value).toBe('c1')
  })

  it('con el servidor de sugerencias caído sigue ofreciendo crear una propia', async () => {
    mockApi({ 'GET /categories': () => store })
    renderApp(<Form onSubmit={() => {}} />)
    await waitFor(() => expect(select().options.length).toBe(3))
    expect(Array.from(select().options).map((o) => o.textContent)).toEqual([
      'Sin categoría',
      'Comida',
      '＋ Nueva categoría…',
    ])
  })
})
