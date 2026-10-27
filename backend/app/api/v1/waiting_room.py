import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Response, status

from app.api.deps import CurrentUser, SessionDep
from app.schemas.waiting_room import WaitingCreate, WaitingDecide, WaitingOut, WaitingRoom
from app.services import waiting_room

router = APIRouter(prefix="/waiting-room", tags=["waiting-room"])


@router.get("", response_model=WaitingRoom)
async def get_room(user: CurrentUser, session: SessionDep) -> WaitingRoom:
    return await waiting_room.room(session, user.id, datetime.now(UTC))


@router.post("", response_model=WaitingOut, status_code=status.HTTP_201_CREATED)
async def add_item(data: WaitingCreate, user: CurrentUser, session: SessionDep) -> WaitingOut:
    return await waiting_room.create(session, user.id, data, datetime.now(UTC))


@router.post("/{item_id}/decide", response_model=WaitingOut)
async def decide(
    item_id: uuid.UUID, data: WaitingDecide, user: CurrentUser, session: SessionDep
) -> WaitingOut:
    return await waiting_room.decide(session, user.id, item_id, data.decision, datetime.now(UTC))


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(item_id: uuid.UUID, user: CurrentUser, session: SessionDep) -> Response:
    await waiting_room.delete(session, user.id, item_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
