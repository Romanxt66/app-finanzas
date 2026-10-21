from datetime import date

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.schemas.common import PositiveMoney
from app.schemas.life_hours import Conversion, MonthHours, ProfileIn, ProfileOut
from app.services import life_hours

router = APIRouter(prefix="/life-hours", tags=["life-hours"])


@router.get("/profile", response_model=ProfileOut)
async def get_profile(user: CurrentUser, session: SessionDep) -> ProfileOut:
    return await life_hours.get_profile(session, user.id)


@router.put("/profile", response_model=ProfileOut)
async def save_profile(data: ProfileIn, user: CurrentUser, session: SessionDep) -> ProfileOut:
    return await life_hours.save_profile(session, user.id, data)


@router.get("/convert", response_model=Conversion)
async def convert(amount: PositiveMoney, user: CurrentUser, session: SessionDep) -> Conversion:
    return await life_hours.convert(session, user.id, amount)


@router.get("/summary", response_model=MonthHours)
async def summary(user: CurrentUser, session: SessionDep, month: date) -> MonthHours:
    return await life_hours.month_summary(session, user.id, month)
