import os
from collections.abc import AsyncIterator

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

os.environ["DATABASE_URL"] = "sqlite+aiosqlite://"
os.environ["SECRET_KEY"] = "test-secret-key-only-for-pytest-0123456789"

from app.api.v1.auth import email_limiter, login_limiter  # noqa: E402
from app.db.base import Base  # noqa: E402
from app.db.session import get_session  # noqa: E402
from app.main import create_app  # noqa: E402


@pytest.fixture
async def client() -> AsyncIterator[AsyncClient]:
    login_limiter._failures.clear()
    email_limiter._failures.clear()  # el límite es global al proceso: aislar cada test
    engine = create_async_engine(
        "sqlite+aiosqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False}
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)

    async def _session() -> AsyncIterator[AsyncSession]:
        async with maker() as session:
            yield session

    app = create_app()
    app.dependency_overrides[get_session] = _session
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    await engine.dispose()


async def register_and_login(client: AsyncClient, email: str = "a@example.com") -> dict[str, str]:
    await client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "password-123", "full_name": "Test User"},
    )
    resp = await client.post(
        "/api/v1/auth/login", json={"email": email, "password": "password-123"}
    )
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


@pytest.fixture
async def auth(client: AsyncClient) -> dict[str, str]:
    return await register_and_login(client)
