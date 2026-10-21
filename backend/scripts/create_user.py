"""Crea un usuario. Uso: python -m scripts.create_user EMAIL PASSWORD "Nombre"."""

import asyncio
import sys

from app.db.session import get_sessionmaker
from app.schemas.auth import RegisterIn
from app.services.auth import register


async def main(email: str, password: str, full_name: str) -> None:
    async with get_sessionmaker()() as session:
        user = await register(
            session, RegisterIn(email=email, password=password, full_name=full_name)
        )
        print(f"Usuario creado: {user.email} ({user.id})")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    asyncio.run(main(*sys.argv[1:]))
