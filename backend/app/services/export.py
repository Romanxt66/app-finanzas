import csv
import io
import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Account, Category, Transaction, TransactionType
from app.services.transactions import build_conditions

HEADER = [
    "fecha",
    "tipo",
    "cuenta",
    "cuenta_destino",
    "categoria",
    "descripcion",
    "monto",
    "moneda",
]
TYPE_LABELS = {"income": "ingreso", "expense": "gasto", "transfer": "transferencia"}
_FORMULA_PREFIXES = ("=", "+", "-", "@", "\t", "\r")


def safe_cell(value: str) -> str:
    """Evita inyección de fórmulas al abrir el CSV en Excel/Sheets."""
    return f"'{value}" if value.startswith(_FORMULA_PREFIXES) else value


async def transactions_csv(
    session: AsyncSession,
    user_id: uuid.UUID,
    *,
    account_id: uuid.UUID | None,
    category_id: uuid.UUID | None,
    type_: TransactionType | None,
    date_from: date | None,
    date_to: date | None,
    search: str | None,
) -> str:
    conditions = build_conditions(
        user_id,
        account_id=account_id,
        category_id=category_id,
        type_=type_,
        date_from=date_from,
        date_to=date_to,
        search=search,
    )
    accounts = {
        a.id: a for a in (await session.scalars(select(Account).where(Account.user_id == user_id)))
    }
    categories = {
        c.id: c.name
        for c in (await session.scalars(select(Category).where(Category.user_id == user_id)))
    }
    rows = await session.scalars(
        select(Transaction)
        .where(*conditions)
        .order_by(Transaction.occurred_on.desc(), Transaction.created_at.desc())
    )
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(HEADER)
    for t in rows:
        account = accounts.get(t.account_id)
        target = accounts.get(t.transfer_account_id) if t.transfer_account_id else None
        writer.writerow(
            [
                t.occurred_on.isoformat(),
                TYPE_LABELS[t.type],
                safe_cell(account.name if account else ""),
                safe_cell(target.name if target else ""),
                safe_cell(categories.get(t.category_id, "") if t.category_id else ""),
                safe_cell(t.description),
                f"{t.amount:.2f}",
                account.currency if account else "",
            ]
        )
    return out.getvalue()
