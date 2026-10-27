from fastapi import APIRouter

from app.api.v1 import (
    accounts,
    auth,
    budgets,
    categories,
    client_errors,
    currencies,
    daily_allowance,
    ghost_subscriptions,
    goals,
    insights,
    life_hours,
    notifications,
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
    notifications,
    client_errors,
):
    api_router.include_router(module.router)
