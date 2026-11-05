"""Verificación del token de identidad de Google («Continuar con Google»).

La app obtiene de Google un ID token (un JWT firmado con RS256) y lo envía aquí. Se comprueba la
firma con las claves públicas de Google, el emisor, la caducidad y que vaya dirigido a uno de
nuestros IDs de cliente (`GOOGLE_CLIENT_IDS`).
"""

import asyncio
from typing import NamedTuple

import jwt
from jwt import PyJWKClient

from app.core.config import get_settings
from app.core.errors import AppError, UnauthorizedError

GOOGLE_CERTS = "https://www.googleapis.com/oauth2/v3/certs"
_ISSUERS = ("accounts.google.com", "https://accounts.google.com")
# Las claves rotan cada pocos días: PyJWKClient las guarda en caché y las recarga si cambian
_jwks = PyJWKClient(GOOGLE_CERTS, cache_keys=True, lifespan=6 * 3600)


class GoogleIdentity(NamedTuple):
    sub: str
    email: str
    email_verified: bool
    name: str | None


def _decode(token: str, audiences: list[str]) -> dict[str, object]:
    key = _jwks.get_signing_key_from_jwt(token).key
    claims: dict[str, object] = jwt.decode(
        token,
        key,
        algorithms=["RS256"],
        audience=audiences,
        options={"require": ["exp", "iat", "iss", "aud", "sub"]},
        leeway=30,
    )
    if claims.get("iss") not in _ISSUERS:
        raise jwt.InvalidIssuerError("emisor inesperado")
    return claims


async def verify_google_token(token: str) -> GoogleIdentity:
    audiences = get_settings().google_client_ids
    if not audiences:
        raise AppError("El inicio de sesión con Google no está configurado en este servidor")
    try:
        # Descargar las claves es E/S bloqueante: fuera del bucle de eventos
        claims = await asyncio.to_thread(_decode, token, audiences)
    except (jwt.PyJWTError, jwt.PyJWKClientError) as exc:
        raise UnauthorizedError("No se pudo verificar la cuenta de Google") from exc
    email = claims.get("email")
    if not isinstance(email, str) or not email:
        raise UnauthorizedError("La cuenta de Google no compartió su correo")
    name = claims.get("name")
    return GoogleIdentity(
        sub=str(claims["sub"]),
        email=email.lower(),
        email_verified=claims.get("email_verified") in (True, "true"),
        name=name if isinstance(name, str) and name.strip() else None,
    )
