import uuid
from datetime import date

from fastapi import APIRouter, Response, status

from app.api.deps import CurrentUser, SessionDep
from app.schemas.budget import BudgetCreate, BudgetOut, BudgetUpdate
from app.services import budgets

router = APIRouter(prefix="/budgets", tags=["budgets"])


@router.get("", response_model=list[BudgetOut])
async def list_budgets(
    user: CurrentUser, session: SessionDep, month: date | None = None
) -> list[BudgetOut]:
    return await budgets.list_budgets(session, user.id, month)


@router.post("", response_model=BudgetOut, status_code=status.HTTP_201_CREATED)
async def create_budget(data: BudgetCreate, user: CurrentUser, session: SessionDep) -> BudgetOut:
    return await budgets.create_budget(session, user.id, data)


@router.patch("/{budget_id}", response_model=BudgetOut)
async def update_budget(
    budget_id: uuid.UUID, data: BudgetUpdate, user: CurrentUser, session: SessionDep
) -> BudgetOut:
    return await budgets.update_budget(session, user.id, budget_id, data.amount)


@router.delete("/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_budget(budget_id: uuid.UUID, user: CurrentUser, session: SessionDep) -> Response:
    await budgets.delete_budget(session, user.id, budget_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
