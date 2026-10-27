from fastapi import APIRouter

from app.api.v1 import (
    accounts,
    auth,
    budgets,
    categories,
    currencies,
    daily_allowance,
    ghost_subscriptions,
    goals,
    insights,
    life_hours,
    recurring,
    reports,
    transactions,
    waiting_room,
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
    ghost_subscriptions,
    daily_allowance,
    insights,
    waiting_room,
):
    api_router.include_router(module.router)
