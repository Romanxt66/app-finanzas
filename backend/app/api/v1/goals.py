import uuid

from fastapi import APIRouter, Response, status

from app.api.deps import CurrentUser, SessionDep
from app.models import GoalContribution
from app.schemas.goal import (
    ContributionCreate,
    ContributionOut,
    GoalCreate,
    GoalOut,
    GoalUpdate,
)
from app.services import goals

router = APIRouter(prefix="/goals", tags=["goals"])


@router.get("", response_model=list[GoalOut])
async def list_goals(user: CurrentUser, session: SessionDep) -> list[GoalOut]:
    return await goals.list_goals(session, user.id)


@router.post("", response_model=GoalOut, status_code=status.HTTP_201_CREATED)
async def create_goal(data: GoalCreate, user: CurrentUser, session: SessionDep) -> GoalOut:
    return await goals.create_goal(session, user.id, data)


@router.patch("/{goal_id}", response_model=GoalOut)
async def update_goal(
    goal_id: uuid.UUID, data: GoalUpdate, user: CurrentUser, session: SessionDep
) -> GoalOut:
    return await goals.update_goal(session, user.id, goal_id, data)


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_goal(goal_id: uuid.UUID, user: CurrentUser, session: SessionDep) -> Response:
    await goals.delete_goal(session, user.id, goal_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{goal_id}/contributions", response_model=list[ContributionOut])
async def list_contributions(
    goal_id: uuid.UUID, user: CurrentUser, session: SessionDep
) -> list[GoalContribution]:
    return await goals.list_contributions(session, user.id, goal_id)


@router.post(
    "/{goal_id}/contributions",
    response_model=ContributionOut,
    status_code=status.HTTP_201_CREATED,
)
async def add_contribution(
    goal_id: uuid.UUID, data: ContributionCreate, user: CurrentUser, session: SessionDep
) -> GoalContribution:
    return await goals.add_contribution(session, user.id, goal_id, data)


@router.delete("/{goal_id}/contributions/{contribution_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_contribution(
    goal_id: uuid.UUID, contribution_id: uuid.UUID, user: CurrentUser, session: SessionDep
) -> Response:
    await goals.delete_contribution(session, user.id, goal_id, contribution_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
