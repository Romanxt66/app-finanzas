import uuid

from fastapi import APIRouter, Response, status

from app.api.deps import CurrentUser, SessionDep
from app.schemas.account import AccountCreate, AccountOut, AccountUpdate
from app.services import accounts

router = APIRouter(prefix="/accounts", tags=["accounts"])


@router.get("", response_model=list[AccountOut])
async def list_accounts(
    user: CurrentUser, session: SessionDep, include_archived: bool = False
) -> list[AccountOut]:
    return await accounts.list_accounts(session, user.id, include_archived)


@router.post("", response_model=AccountOut, status_code=status.HTTP_201_CREATED)
async def create_account(data: AccountCreate, user: CurrentUser, session: SessionDep) -> AccountOut:
    return await accounts.create_account(session, user.id, data)


@router.get("/{account_id}", response_model=AccountOut)
async def get_account(account_id: uuid.UUID, user: CurrentUser, session: SessionDep) -> AccountOut:
    return await accounts.get_account(session, user.id, account_id)


@router.patch("/{account_id}", response_model=AccountOut)
async def update_account(
    account_id: uuid.UUID, data: AccountUpdate, user: CurrentUser, session: SessionDep
) -> AccountOut:
    return await accounts.update_account(session, user.id, account_id, data)


@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(account_id: uuid.UUID, user: CurrentUser, session: SessionDep) -> Response:
    await accounts.delete_account(session, user.id, account_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
