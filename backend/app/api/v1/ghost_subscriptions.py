from datetime import date

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.schemas.ghost_subscriptions import GhostReport
from app.services import ghost_subscriptions

router = APIRouter(prefix="/ghost-subscriptions", tags=["ghost-subscriptions"])


@router.get("", response_model=GhostReport)
async def get_report(
    user: CurrentUser, session: SessionDep, today: date | None = None
) -> GhostReport:
    """`today` permite al cliente fijar su fecha local; por defecto, la del servidor."""
    return await ghost_subscriptions.report(session, user.id, today or date.today())
