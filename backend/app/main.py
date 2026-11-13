from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.errors import register_error_handlers
from app.core.idempotency import IdempotencyMiddleware
from app.core.no_store import NoStoreMiddleware
from app.core.observability import init_sentry, install_observability
from app.db.session import get_session


def create_app() -> FastAPI:
    settings = get_settings()
    init_sentry(settings.sentry_dsn, settings.environment)
    # En producción no se publica la documentación interactiva (es un mapa de la API)
    public_docs = settings.environment.lower() not in ("production", "prod")
    app = FastAPI(
        title="App de Finanzas",
        version="0.1.0",
        docs_url="/docs" if public_docs else None,
        redoc_url="/redoc" if public_docs else None,
        openapi_url="/openapi.json" if public_docs else None,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    # Reenvíos de la app sin conexión: la misma `Idempotency-Key` no aplica un cambio dos veces
    app.add_middleware(IdempotencyMiddleware)
    app.add_middleware(NoStoreMiddleware)
    # El último añadido es el más externo: comprime al final (la idempotencia guarda el cuerpo sin
    # comprimir). Útil cuando la app Android llama a la API sin pasar por el nginx de la web.
    app.add_middleware(GZipMiddleware, minimum_size=1024)
    register_error_handlers(app)
    install_observability(app)
    app.include_router(api_router)

    @app.get("/health", tags=["health"])
    async def health() -> dict[str, str]:
        """Liveness: el proceso responde (lo usa el healthcheck del contenedor)."""
        return {"status": "ok"}

    @app.get("/health/ready", tags=["health"])
    async def ready(session: Annotated[AsyncSession, Depends(get_session)]) -> dict[str, str]:
        """Readiness: además comprueba que la base de datos responde."""
        try:
            await session.execute(text("SELECT 1"))
        except Exception as exc:  # noqa: BLE001 - cualquier fallo de BD significa "no listo"
            raise HTTPException(status_code=503, detail="database unavailable") from exc
        return {"status": "ok", "database": "ok"}

    return app


app = create_app()
