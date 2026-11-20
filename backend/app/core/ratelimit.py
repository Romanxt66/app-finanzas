import random
import time
from collections.abc import Callable

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AuthFailure

# Los registros más viejos que esto no cuentan para ningún límite (la ventana más larga es 1 h)
_KEEP_SECONDS = 24 * 60 * 60
# De vez en cuando, al anotar, se borran los caducados (sin tarea programada aparte)
_SWEEP_PROBABILITY = 0.02


class FailureLimiter:
    """Ventana deslizante de fallos por clave (p. ej. IP + correo), guardada en la base de datos.

    Es compartida por todos los procesos de la API, así que el límite no cambia al poner varios
    workers o réplicas. Cada límite tiene su `scope` para que las claves no se mezclen.
    """

    def __init__(
        self,
        scope: str,
        max_failures: int = 5,
        window_seconds: int = 15 * 60,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self.scope = scope
        self.max_failures = max_failures
        self.window = window_seconds
        self.clock = clock

    async def retry_after(self, session: AsyncSession, key: str) -> int:
        """Segundos hasta poder reintentar (0 si no está bloqueado)."""
        since = self.clock() - self.window
        count, oldest = (
            await session.execute(
                select(func.count(), func.min(AuthFailure.at)).where(
                    AuthFailure.scope == self.scope, AuthFailure.key == key, AuthFailure.at > since
                )
            )
        ).one()
        if count < self.max_failures or oldest is None:
            return 0
        # Se desbloquea cuando el fallo más viejo de la ventana deja de contar
        return max(1, int(oldest + self.window - self.clock()) + 1)

    async def record_failure(self, session: AsyncSession, key: str) -> None:
        """Anota un fallo y lo guarda ya.

        Descarta antes lo que la petición tuviera a medio guardar: se llama justo cuando algo falló
        (o antes de empezar), y el fallo debe quedar anotado aunque la petición termine en error.
        """
        await session.rollback()
        now = self.clock()
        session.add(AuthFailure(scope=self.scope, key=key, at=now))
        if random.random() < _SWEEP_PROBABILITY:  # noqa: S311 - no es criptográfico
            await session.execute(delete(AuthFailure).where(AuthFailure.at < now - _KEEP_SECONDS))
        await session.commit()

    async def reset(self, session: AsyncSession, key: str) -> None:
        """Olvida los fallos de la clave (tras entrar bien)."""
        await session.execute(
            delete(AuthFailure).where(AuthFailure.scope == self.scope, AuthFailure.key == key)
        )
        await session.commit()
