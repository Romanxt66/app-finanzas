import uuid
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundError
from app.models import Account, AccountType, Transaction, TransactionType
from app.schemas.account import AccountCreate, AccountOut, AccountUpdate


async def _balances(session: AsyncSession, user_id: uuid.UUID) -> dict[uuid.UUID, Decimal]:
    """Movimiento neto por cuenta: ingresos - gastos - transferencias salientes + entrantes."""
    delta: dict[uuid.UUID, Decimal] = {}
    rows = await session.execute(
        select(Transaction.account_id, Transaction.type, func.sum(Transaction.amount))
        .where(Transaction.user_id == user_id)
        .group_by(Transaction.account_id, Transaction.type)
    )
    for acc_id, ttype, total in rows:
        sign = 1 if ttype == TransactionType.income else -1
        delta[acc_id] = delta.get(acc_id, Decimal(0)) + sign * total
    incoming = await session.execute(
        select(Transaction.transfer_account_id, func.sum(Transaction.amount))
        .where(Transaction.user_id == user_id, Transaction.type == TransactionType.transfer)
        .group_by(Transaction.transfer_account_id)
    )
    for target_id, total in incoming:
        if target_id is not None:
            delta[target_id] = delta.get(target_id, Decimal(0)) + total
    return delta


def _out(account: Account, delta: dict[uuid.UUID, Decimal]) -> AccountOut:
    return AccountOut(
        id=account.id,
        created_at=account.created_at,
        name=account.name,
        type=AccountType(account.type),
        currency=account.currency,
        initial_balance=account.initial_balance,
        archived=account.archived,
        balance=account.initial_balance + delta.get(account.id, Decimal(0)),
    )


async def get_owned(session: AsyncSession, user_id: uuid.UUID, account_id: uuid.UUID) -> Account:
    account = await session.get(Account, account_id)
    if account is None or account.user_id != user_id:
        raise NotFoundError("Cuenta no encontrada")
    return account


async def list_accounts(
    session: AsyncSession, user_id: uuid.UUID, include_archived: bool
) -> list[AccountOut]:
    stmt = select(Account).where(Account.user_id == user_id).order_by(Account.created_at)
    if not include_archived:
        stmt = stmt.where(Account.archived.is_(False))
    accounts = (await session.scalars(stmt)).all()
    delta = await _balances(session, user_id)
    return [_out(a, delta) for a in accounts]


async def get_account(
    session: AsyncSession, user_id: uuid.UUID, account_id: uuid.UUID
) -> AccountOut:
    account = await get_owned(session, user_id, account_id)
    return _out(account, await _balances(session, user_id))


async def create_account(
    session: AsyncSession, user_id: uuid.UUID, data: AccountCreate
) -> AccountOut:
    account = Account(user_id=user_id, **data.model_dump())
    session.add(account)
    await session.commit()
    await session.refresh(account)
    return _out(account, await _balances(session, user_id))


async def update_account(
    session: AsyncSession, user_id: uuid.UUID, account_id: uuid.UUID, data: AccountUpdate
) -> AccountOut:
    account = await get_owned(session, user_id, account_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(account, field, value)
    await session.commit()
    return _out(account, await _balances(session, user_id))
