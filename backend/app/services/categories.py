import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ConflictError, NotFoundError
from app.models import Category, Transaction
from app.schemas.category import CategoryCreate, CategoryUpdate


async def get_owned(session: AsyncSession, user_id: uuid.UUID, category_id: uuid.UUID) -> Category:
    category = await session.get(Category, category_id)
    if category is None or category.user_id != user_id:
        raise NotFoundError("Categoría no encontrada")
    return category


async def list_categories(session: AsyncSession, user_id: uuid.UUID) -> list[Category]:
    stmt = select(Category).where(Category.user_id == user_id).order_by(Category.name)
    return list((await session.scalars(stmt)).all())


async def create_category(
    session: AsyncSession, user_id: uuid.UUID, data: CategoryCreate
) -> Category:
    category = Category(user_id=user_id, **data.model_dump())
    session.add(category)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise ConflictError("Ya existe una categoría con ese nombre") from exc
    return category


async def update_category(
    session: AsyncSession, user_id: uuid.UUID, category_id: uuid.UUID, data: CategoryUpdate
) -> Category:
    category = await get_owned(session, user_id, category_id)
    category.name = data.name
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise ConflictError("Ya existe una categoría con ese nombre") from exc
    return category


async def delete_category(
    session: AsyncSession, user_id: uuid.UUID, category_id: uuid.UUID
) -> None:
    category = await get_owned(session, user_id, category_id)
    in_use = await session.scalar(
        select(Transaction.id).where(Transaction.category_id == category_id).limit(1)
    )
    if in_use is not None:
        raise ConflictError("La categoría tiene transacciones asociadas")
    await session.delete(category)
    await session.commit()
