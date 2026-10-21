from datetime import date

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.schemas.common import Currency
from app.schemas.daily_allowance import DailyAllowance
from app.services import daily_allowance

router = APIRouter(prefix="/daily-allowance", tags=["daily-allowance"])


@router.get("", response_model=DailyAllowance)
async def get_daily_allowance(
    user: CurrentUser,
    session: SessionDep,
    today: date | None = None,
    currency: Currency | None = None,
) -> DailyAllowance:
    """`today` fija la fecha local del cliente; `currency`, por defecto, la de su primera cuenta."""
    return await daily_allowance.daily_allowance(session, user.id, today or date.today(), currency)
