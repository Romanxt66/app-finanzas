import logging
import re
import time
import uuid

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint

access_log = logging.getLogger("app.access")
error_log = logging.getLogger("app.error")

_SAFE_ID = re.compile(r"^[A-Za-z0-9._-]{8,64}$")
REQUEST_ID_HEADER = "X-Request-ID"


def _capture_current_exception(request_id: str) -> None:
    # El middleware convierte la excepción en un 500 y Sentry no llegaría a verla
    import sentry_sdk

    if sentry_sdk.is_initialized():
        with sentry_sdk.new_scope() as scope:
            scope.set_tag("request_id", request_id)
            sentry_sdk.capture_exception()


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Asigna un id a cada petición, lo devuelve en la cabecera y registra una línea de acceso.

    Solo se registra método, ruta (sin query string), estado y duración: nunca cabeceras ni cuerpos.
    """

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        incoming = request.headers.get(REQUEST_ID_HEADER, "")
        request_id = incoming if _SAFE_ID.match(incoming) else uuid.uuid4().hex
        request.state.request_id = request_id
        started = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            error_log.exception(
                "request_id=%s unhandled error on %s %s",
                request_id,
                request.method,
                request.url.path,
            )
            _capture_current_exception(request_id)
            response = JSONResponse(
                {
                    "error": {
                        "code": "internal_error",
                        "message": "Error interno del servidor",
                        "request_id": request_id,
                    }
                },
                status_code=500,
            )
        response.headers[REQUEST_ID_HEADER] = request_id
        elapsed_ms = (time.perf_counter() - started) * 1000
        access_log.info(
            "request_id=%s %s %s -> %s in %.1fms",
            request_id,
            request.method,
            request.url.path,
            response.status_code,
            elapsed_ms,
        )
        return response


def init_sentry(dsn: str | None, environment: str) -> bool:
    """Activa Sentry solo si hay DSN. Sin datos personales: ni cuerpos, ni cabeceras, ni IP."""
    if not dsn:
        return False
    import sentry_sdk

    sentry_sdk.init(
        dsn=dsn,
        environment=environment,
        send_default_pii=False,
        max_request_body_size="never",
        traces_sample_rate=0.0,
    )
    return True


def install_observability(app: FastAPI) -> None:
    app.add_middleware(RequestContextMiddleware)
