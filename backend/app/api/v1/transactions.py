import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query, Response, status

from app.api.deps import CurrentUser, SessionDep
from app.models import Transaction, TransactionType
from app.schemas.transaction import TransactionCreate, TransactionOut, TransactionPage
from app.services import export, transactions

router = APIRouter(prefix="/transactions", tags=["transactions"])


@router.get("", response_model=TransactionPage)
async def list_transactions(
    user: CurrentUser,
    session: SessionDep,
    account_id: uuid.UUID | None = None,
    category_id: uuid.UUID | None = None,
    type: TransactionType | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    search: Annotated[str | None, Query(max_length=100)] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> TransactionPage:
    items, total = await transactions.list_transactions(
        session,
        user.id,
        account_id=account_id,
        category_id=category_id,
        type_=type,
        date_from=date_from,
        date_to=date_to,
        search=search,
        limit=limit,
        offset=offset,
    )
    return TransactionPage(
        items=[TransactionOut.model_validate(t) for t in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get("/export")
async def export_transactions(
    user: CurrentUser,
    session: SessionDep,
    account_id: uuid.UUID | None = None,
    category_id: uuid.UUID | None = None,
    type: TransactionType | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    search: Annotated[str | None, Query(max_length=100)] = None,
) -> Response:
    """CSV (UTF-8 con BOM, para Excel) con los mismos filtros que el listado."""
    body = await export.transactions_csv(
        session,
        user.id,
        account_id=account_id,
        category_id=category_id,
        type_=type,
        date_from=date_from,
        date_to=date_to,
        search=search,
    )
    return Response(
        content="\ufeff" + body,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": 'attachment; filename="movimientos.csv"'},
    )


@router.post("", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
async def create_transaction(
    data: TransactionCreate, user: CurrentUser, session: SessionDep
) -> Transaction:
    return await transactions.create_transaction(session, user.id, data)


@router.get("/{transaction_id}", response_model=TransactionOut)
async def get_transaction(
    transaction_id: uuid.UUID, user: CurrentUser, session: SessionDep
) -> Transaction:
    return await transactions.get_owned(session, user.id, transaction_id)


@router.put("/{transaction_id}", response_model=TransactionOut)
async def update_transaction(
    transaction_id: uuid.UUID, data: TransactionCreate, user: CurrentUser, session: SessionDep
) -> Transaction:
    return await transactions.update_transaction(session, user.id, transaction_id, data)


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_transaction(
    transaction_id: uuid.UUID, user: CurrentUser, session: SessionDep
) -> Response:
    await transactions.delete_transaction(session, user.id, transaction_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
