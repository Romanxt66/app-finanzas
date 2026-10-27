from datetime import date

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.schemas.insights import PersonalInflation, SpendingMoodReport
from app.services import insights

router = APIRouter(tags=["insights"])


@router.get("/personal-inflation", response_model=PersonalInflation)
async def personal_inflation(
    user: CurrentUser, session: SessionDep, today: date | None = None
) -> PersonalInflation:
    """`today` permite al cliente fijar su fecha local; por defecto, la del servidor."""
    return await insights.personal_inflation(session, user.id, today or date.today())


@router.get("/spending-mood", response_model=SpendingMoodReport)
async def spending_mood(
    user: CurrentUser, session: SessionDep, today: date | None = None
) -> SpendingMoodReport:
    """`today` permite al cliente fijar su fecha local; por defecto, la del servidor."""
    return await insights.spending_mood(session, user.id, today or date.today())
