import uuid
from collections import Counter
from datetime import date
from decimal import Decimal

from sqlalchemy import ColumnElement, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFoundError
from app.models import CategoryKind, Transaction, TransactionType
from app.schemas.transaction import BulkCreate, BulkItem, BulkResult, TransactionCreate
from app.services import accounts, categories


async def validate(session: AsyncSession, user_id: uuid.UUID, data: TransactionCreate) -> None:
    source = await accounts.get_owned(session, user_id, data.account_id)
    if data.transfer_account_id is not None:
        target = await accounts.get_owned(session, user_id, data.transfer_account_id)
        if target.currency != source.currency:
            raise AppError("Las transferencias entre monedas distintas no están soportadas")
    if data.category_id is not None:
        category = await categories.get_owned(session, user_id, data.category_id)
        if category.kind != CategoryKind(data.type.value):
            raise AppError("El tipo de la categoría no coincide con el de la transacción")


async def get_owned(
    session: AsyncSession, user_id: uuid.UUID, transaction_id: uuid.UUID
) -> Transaction:
    tx = await session.get(Transaction, transaction_id)
    if tx is None or tx.user_id != user_id:
        raise NotFoundError("Transacción no encontrada")
    return tx


def build_conditions(
    user_id: uuid.UUID,
    *,
    account_id: uuid.UUID | None,
    category_id: uuid.UUID | None,
    type_: TransactionType | None,
    date_from: date | None,
    date_to: date | None,
    search: str | None,
) -> list[ColumnElement[bool]]:
    conditions: list[ColumnElement[bool]] = [Transaction.user_id == user_id]
    if account_id:
        conditions.append(
            (Transaction.account_id == account_id) | (Transaction.transfer_account_id == account_id)
        )
    if category_id:
        conditions.append(Transaction.category_id == category_id)
    if type_:
        conditions.append(Transaction.type == type_)
    if date_from:
        conditions.append(Transaction.occurred_on >= date_from)
    if date_to:
        conditions.append(Transaction.occurred_on <= date_to)
    if search:
        conditions.append(Transaction.description.ilike(f"%{search}%"))
    return conditions


async def list_transactions(
    session: AsyncSession,
    user_id: uuid.UUID,
    *,
    account_id: uuid.UUID | None,
    category_id: uuid.UUID | None,
    type_: TransactionType | None,
    date_from: date | None,
    date_to: date | None,
    search: str | None,
    limit: int,
    offset: int,
) -> tuple[list[Transaction], int]:
    conditions = build_conditions(
        user_id,
        account_id=account_id,
        category_id=category_id,
        type_=type_,
        date_from=date_from,
        date_to=date_to,
        search=search,
    )
    total = await session.scalar(select(func.count()).select_from(Transaction).where(*conditions))
    stmt = (
        select(Transaction)
        .where(*conditions)
        .order_by(Transaction.occurred_on.desc(), Transaction.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    return list((await session.scalars(stmt)).all()), total or 0


async def create_transaction(
    session: AsyncSession, user_id: uuid.UUID, data: TransactionCreate
) -> Transaction:
    await validate(session, user_id, data)
    tx = Transaction(user_id=user_id, **data.model_dump())
    session.add(tx)
    await session.commit()
    await session.refresh(tx)
    return tx


async def update_transaction(
    session: AsyncSession, user_id: uuid.UUID, transaction_id: uuid.UUID, data: TransactionCreate
) -> Transaction:
    tx = await get_owned(session, user_id, transaction_id)
    await validate(session, user_id, data)
    for field, value in data.model_dump().items():
        setattr(tx, field, value)
    await session.commit()
    return tx


async def delete_transaction(
    session: AsyncSession, user_id: uuid.UUID, transaction_id: uuid.UUID
) -> None:
    tx = await get_owned(session, user_id, transaction_id)
    await session.delete(tx)
    await session.commit()


async def bulk_create(session: AsyncSession, user_id: uuid.UUID, data: BulkCreate) -> BulkResult:
    """Importa movimientos de un extracto: positivo = ingreso, negativo = gasto.

    Con `skip_duplicates` se omiten filas que ya existen (misma cuenta, fecha, tipo, monto y
    descripción); es un multiconjunto, así que dos cafés idénticos el mismo día siguen siendo dos.
    """
    await accounts.get_owned(session, user_id, data.account_id)
    category_ids = {i.category_id for i in data.items if i.category_id}
    kinds: dict[uuid.UUID, CategoryKind] = {}
    for cid in category_ids:
        kinds[cid] = (await categories.get_owned(session, user_id, cid)).kind

    prepared: list[tuple[TransactionType, BulkItem]] = []
    for index, item in enumerate(data.items, start=1):
        ttype = TransactionType.income if item.amount > 0 else TransactionType.expense
        if item.category_id and kinds[item.category_id] != CategoryKind(ttype.value):
            raise AppError(f"Fila {index}: la categoría no corresponde a un {ttype.value}")
        prepared.append((ttype, item))

    existing: Counter[tuple[date, str, Decimal, str]] = Counter()
    if data.skip_duplicates:
        first = min(i.occurred_on for i in data.items)
        last = max(i.occurred_on for i in data.items)
        rows = await session.execute(
            select(
                Transaction.occurred_on,
                Transaction.type,
                Transaction.amount,
                Transaction.description,
            ).where(
                Transaction.user_id == user_id,
                Transaction.account_id == data.account_id,
                Transaction.occurred_on >= first,
                Transaction.occurred_on <= last,
            )
        )
        for occurred_on, ttype_value, amount, description in rows:
            existing[(occurred_on, ttype_value, Decimal(amount), description)] += 1

    created = skipped = 0
    for ttype, item in prepared:
        amount = abs(item.amount)
        key = (item.occurred_on, ttype.value, amount, item.description)
        if data.skip_duplicates and existing[key] > 0:
            existing[key] -= 1
            skipped += 1
            continue
        session.add(
            Transaction(
                user_id=user_id,
                account_id=data.account_id,
                category_id=item.category_id,
                type=ttype,
                amount=amount,
                description=item.description,
                occurred_on=item.occurred_on,
            )
        )
        created += 1
    await session.commit()
    return BulkResult(created=created, skipped=skipped)
