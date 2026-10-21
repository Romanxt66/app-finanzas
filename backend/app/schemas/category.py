from pydantic import BaseModel, Field

from app.models.category import CategoryKind
from app.schemas.common import Entity


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    kind: CategoryKind


class CategoryUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=80)


class CategoryOut(Entity):
    name: str
    kind: CategoryKind
