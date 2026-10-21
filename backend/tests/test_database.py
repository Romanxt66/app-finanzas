import asyncio
import os
from pathlib import Path

import pytest
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from sqlalchemy import create_engine, inspect
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

import app.models  # noqa: F401
from alembic import command
from app.db.base import Base
from app.models import Account, Transaction, User

BACKEND = Path(__file__).resolve().parents[1]


@pytest.fixture
def migrated_url(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> str:
    url = f"sqlite+aiosqlite:///{tmp_path / 'm.db'}"
    monkeypatch.setenv("DATABASE_URL", url)
    from app.core.config import get_settings

    get_settings.cache_clear()
    cfg = Config(str(BACKEND / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND / "alembic"))
    # alembic usa asyncio.run, por eso se ejecuta fuera del loop de pytest
    command.upgrade(cfg, "head")
    get_settings.cache_clear()
    return url


def test_migrations_match_models(migrated_url: str) -> None:
    sync_url = migrated_url.replace("+aiosqlite", "")
    engine = create_engine(sync_url)
    with engine.connect() as conn:
        diff = compare_metadata(MigrationContext.configure(conn), Base.metadata)
    assert diff == [], f"Los modelos difieren de las migraciones: {diff}"
    assert set(inspect(engine).get_table_names()) >= {
        "users",
        "accounts",
        "categories",
        "transactions",
        "budgets",
    }


def test_migration_downgrade(migrated_url: str, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", migrated_url)
    cfg = Config(str(BACKEND / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND / "alembic"))
    command.downgrade(cfg, "base")
    tables = set(inspect(create_engine(migrated_url.replace("+aiosqlite", ""))).get_table_names())
    assert tables <= {"alembic_version"}


async def test_db_constraints_enforced(tmp_path: Path) -> None:
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'c.db'}")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as s:  # type: AsyncSession
        user = User(email="a@example.com", hashed_password="x", full_name="A")
        s.add(user)
        await s.commit()
        user_id = user.id
        acc = Account(user_id=user_id, name="C", type="cash", currency="USD")
        s.add(acc)
        await s.commit()
        acc_id = acc.id
        s.add(User(email="a@example.com", hashed_password="x", full_name="B"))
        with pytest.raises(IntegrityError):
            await s.commit()
        await s.rollback()
        from datetime import date
        from decimal import Decimal

        s.add(
            Transaction(
                user_id=user_id,
                account_id=acc_id,
                type="expense",
                amount=Decimal("-1"),
                occurred_on=date(2026, 1, 1),
            )
        )
        with pytest.raises(IntegrityError):
            await s.commit()
    await engine.dispose()


def test_session_factory_uses_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    from app.db import session

    session.get_engine.cache_clear()
    session.get_sessionmaker.cache_clear()
    monkeypatch.setenv("DATABASE_URL", "sqlite+aiosqlite://")

    async def run() -> None:
        agen = session.get_session()
        s = await anext(agen)
        assert isinstance(s, AsyncSession)
        await agen.aclose()

    asyncio.run(run())
    session.get_engine.cache_clear()
    session.get_sessionmaker.cache_clear()
    assert os.environ["DATABASE_URL"]
