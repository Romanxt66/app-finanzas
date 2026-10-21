from fastapi import APIRouter

from app.api.v1 import (
    accounts,
    auth,
    budgets,
    categories,
    currencies,
    goals,
    life_hours,
    recurring,
    reports,
    transactions,
)

api_router = APIRouter(prefix="/api/v1")
for module in (
    auth,
    accounts,
    categories,
    transactions,
    recurring,
    budgets,
    goals,
    reports,
    life_hours,
    currencies,
):
    api_router.include_router(module.router)
