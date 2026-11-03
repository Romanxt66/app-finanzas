from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, SessionDep
from app.schemas.notification import NotificationList
from app.services import notifications

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=NotificationList)
async def list_notifications(
    user: CurrentUser,
    session: SessionDep,
    today: Annotated[date | None, Query(description="Fecha local del usuario")] = None,
    days: Annotated[int, Query(ge=0, le=14, description="Días de antelación de los cobros")] = 3,
) -> NotificationList:
    """Avisos pendientes, de más a menos urgentes."""
    items = await notifications.list_notifications(
        session, user.id, today or date.today(), horizon=days
    )
    return NotificationList(items=items)
