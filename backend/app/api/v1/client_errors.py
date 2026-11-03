"""Errores que la app (navegador o móvil) reporta para poder arreglarlos sin que nadie avise."""

import logging
import re

from fastapi import APIRouter, Request, status
from pydantic import BaseModel, Field

from app.core.ratelimit import FailureLimiter

router = APIRouter(prefix="/client-errors", tags=["observability"])
client_log = logging.getLogger("app.client")
# Por IP: como mucho 30 reportes cada 10 min (los demás se descartan en silencio)
report_limiter = FailureLimiter(max_failures=30, window_seconds=10 * 60)

# Nada que parezca un token o un correo llega al registro
_SECRETS = re.compile(r"(eyJ[\w-]+\.[\w-]+\.[\w-]+|Bearer\s+\S+|[\w.+-]+@[\w-]+\.[\w.-]+)")


class ClientError(BaseModel):
    message: str = Field(max_length=1000)
    stack: str = Field(default="", max_length=8000)
    # Ruta de la app (sin query string) y versión de la compilación
    route: str = Field(default="", max_length=200)
    release: str = Field(default="", max_length=40)
    platform: str = Field(default="", max_length=40)


def _clean(text: str) -> str:
    return _SECRETS.sub("[redacted]", text)


@router.post("", status_code=status.HTTP_204_NO_CONTENT)
async def report(data: ClientError, request: Request) -> None:
    key = request.client.host if request.client else "?"
    if report_limiter.retry_after(key):
        return
    report_limiter.record_failure(key)
    message = _clean(data.message)
    route = _clean(data.route.split("?", 1)[0])
    client_log.warning(
        "client error route=%s release=%s platform=%s: %s\n%s",
        route,
        data.release,
        data.platform,
        message,
        _clean(data.stack),
    )
    import sentry_sdk

    if sentry_sdk.is_initialized():
        with sentry_sdk.new_scope() as scope:
            scope.set_tag("source", "client")
            scope.set_tag("route", route)
            scope.set_tag("platform", data.platform)
            if data.release:
                scope.set_tag("client_release", data.release)
            scope.set_extra("stack", _clean(data.stack))
            sentry_sdk.capture_message(message, level="error")
