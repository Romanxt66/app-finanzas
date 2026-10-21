from fastapi import APIRouter

from app.core.currencies import SUPPORTED_CURRENCIES

router = APIRouter(prefix="/currencies", tags=["currencies"])


@router.get("", response_model=list[str])
async def list_currencies() -> list[str]:
    return list(SUPPORTED_CURRENCIES)
