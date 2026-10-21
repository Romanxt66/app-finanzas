import uuid

from fastapi import APIRouter, Response, status

from app.api.deps import CurrentUser, SessionDep
from app.models import Category
from app.schemas.category import CategoryCreate, CategoryOut, CategoryUpdate
from app.services import categories

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("", response_model=list[CategoryOut])
async def list_categories(user: CurrentUser, session: SessionDep) -> list[Category]:
    return await categories.list_categories(session, user.id)


@router.post("", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
async def create_category(data: CategoryCreate, user: CurrentUser, session: SessionDep) -> Category:
    return await categories.create_category(session, user.id, data)


@router.patch("/{category_id}", response_model=CategoryOut)
async def update_category(
    category_id: uuid.UUID, data: CategoryUpdate, user: CurrentUser, session: SessionDep
) -> Category:
    return await categories.update_category(session, user.id, category_id, data)


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_category(
    category_id: uuid.UUID, user: CurrentUser, session: SessionDep
) -> Response:
    await categories.delete_category(session, user.id, category_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
