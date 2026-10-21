import uuid
from datetime import date

from fastapi import APIRouter, Response, status

from app.api.deps import CurrentUser, SessionDep
from app.models import RecurringRule
from app.schemas.recurring import RecurringCreate, RecurringOut, RecurringUpdate, RunResult
from app.services import recurring

router = APIRouter(prefix="/recurring", tags=["recurring"])


@router.get("", response_model=list[RecurringOut])
async def list_rules(user: CurrentUser, session: SessionDep) -> list[RecurringRule]:
    return await recurring.list_rules(session, user.id)


@router.post("", response_model=RecurringOut, status_code=status.HTTP_201_CREATED)
async def create_rule(
    data: RecurringCreate, user: CurrentUser, session: SessionDep
) -> RecurringRule:
    return await recurring.create_rule(session, user.id, data)


@router.post("/run", response_model=RunResult)
async def run_due(user: CurrentUser, session: SessionDep, today: date | None = None) -> RunResult:
    """Materializa los movimientos vencidos. `today` permite al cliente usar su fecha local."""
    return RunResult(created=await recurring.run_due(session, user.id, today or date.today()))


@router.patch("/{rule_id}", response_model=RecurringOut)
async def update_rule(
    rule_id: uuid.UUID, data: RecurringUpdate, user: CurrentUser, session: SessionDep
) -> RecurringRule:
    return await recurring.update_rule(session, user.id, rule_id, data)


@router.delete("/{rule_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_rule(rule_id: uuid.UUID, user: CurrentUser, session: SessionDep) -> Response:
    await recurring.delete_rule(session, user.id, rule_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
