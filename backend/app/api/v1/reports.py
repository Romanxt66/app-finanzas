from datetime import date

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.schemas.report import Summary
from app.services import reports

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/summary", response_model=Summary)
async def summary(
    user: CurrentUser, session: SessionDep, month: date, currency: str | None = None
) -> Summary:
    """Resumen del mes en una moneda (por defecto la de la primera cuenta)."""
    return await reports.summary(session, user.id, month, currency)
