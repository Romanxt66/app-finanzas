from fastapi import APIRouter

from app.api.v1 import accounts, auth, budgets, categories, goals, reports, transactions

api_router = APIRouter(prefix="/api/v1")
for module in (auth, accounts, categories, transactions, budgets, goals, reports):
    api_router.include_router(module.router)
