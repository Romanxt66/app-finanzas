from collections.abc import Mapping
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class AppError(Exception):
    status_code = status.HTTP_400_BAD_REQUEST
    code = "bad_request"

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class NotFoundError(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "not_found"


class ConflictError(AppError):
    status_code = status.HTTP_409_CONFLICT
    code = "conflict"


class UnauthorizedError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "unauthorized"


def _translate(error: Mapping[str, Any]) -> str:
    """Mensaje en español para un error de validación de Pydantic."""
    kind = str(error.get("type", ""))
    ctx: Mapping[str, Any] = error.get("ctx") or {}
    msg = str(error.get("msg", ""))
    if kind == "value_error":
        if "email" in msg.lower():
            return "Correo electrónico inválido"
        return msg.removeprefix("Value error, ")
    if kind == "missing":
        return "Campo requerido"
    if kind == "string_too_short":
        return f"Debe tener al menos {ctx.get('min_length')} caracteres"
    if kind == "string_too_long":
        return f"No puede superar {ctx.get('max_length')} caracteres"
    if kind in ("greater_than", "greater_than_equal"):
        return "El valor debe ser mayor que cero"
    if kind in ("decimal_max_places", "decimal_max_digits"):
        return "Monto con demasiados dígitos o decimales"
    if kind in ("uuid_parsing", "uuid_type"):
        return "Identificador inválido"
    if kind in ("enum", "literal_error"):
        return "Valor no permitido"
    if kind in ("date_from_datetime_parsing", "date_parsing", "date_type"):
        return "Fecha inválida"
    if kind == "string_pattern_mismatch":
        return "Formato inválido"
    return msg


def _body(code: str, message: str, details: object | None = None) -> dict[str, object]:
    error: dict[str, object] = {"code": code, "message": message}
    if details is not None:
        error["details"] = details
    return {"error": error}


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(_body(exc.code, exc.message), status_code=exc.status_code)

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        details = [
            {"loc": e["loc"], "field": str(e["loc"][-1]), "msg": _translate(e)}
            for e in exc.errors()
        ]
        return JSONResponse(
            _body("validation_error", str(details[0]["msg"]), details),
            status_code=422,
        )


class TooManyRequestsError(AppError):
    status_code = 429
    code = "too_many_requests"


class TwoFactorRequiredError(UnauthorizedError):
    """La contraseña es correcta pero falta el código de verificación en dos pasos."""

    code = "otp_required"
