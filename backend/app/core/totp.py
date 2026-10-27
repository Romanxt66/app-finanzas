"""Códigos de un solo uso (TOTP, RFC 6238) para la verificación en dos pasos.

Compatible con Google Authenticator, Microsoft Authenticator, 1Password, Aegis…: SHA-1, 6 dígitos
y pasos de 30 s. Se implementa con la biblioteca estándar para no añadir dependencias.
"""

import base64
import hashlib
import hmac
import secrets
import struct
import time
from urllib.parse import quote, urlencode

DIGITS = 6
PERIOD = 30
ISSUER = "Alvea"
# Pasos de tolerancia a cada lado (relojes de móvil algo adelantados o atrasados)
WINDOW = 1


def generate_secret() -> str:
    """Secreto aleatorio de 160 bits en base32 sin relleno (32 caracteres)."""
    return base64.b32encode(secrets.token_bytes(20)).decode().rstrip("=")


def _key(secret: str) -> bytes:
    padded = secret.upper() + "=" * (-len(secret) % 8)
    return base64.b32decode(padded)


def code_at(secret: str, step: int) -> str:
    digest = hmac.new(_key(secret), struct.pack(">Q", step), hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    value = struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF
    return str(value % 10**DIGITS).zfill(DIGITS)


def current_step(now: float | None = None) -> int:
    return int((time.time() if now is None else now) // PERIOD)


def matching_step(secret: str, code: str, now: float | None = None) -> int | None:
    """Paso de tiempo al que corresponde el código, o None si no es válido ahora."""
    code = "".join(c for c in code if c.isdigit())
    if len(code) != DIGITS:
        return None
    step = current_step(now)
    for candidate in range(step - WINDOW, step + WINDOW + 1):
        if hmac.compare_digest(code_at(secret, candidate), code):
            return candidate
    return None


def otpauth_uri(secret: str, account: str) -> str:
    """Enlace que las apps de autenticación leen desde un código QR."""
    label = quote(f"{ISSUER}:{account}")
    query = urlencode({"secret": secret, "issuer": ISSUER, "digits": DIGITS, "period": PERIOD})
    return f"otpauth://totp/{label}?{query}"


def generate_recovery_codes(count: int = 8) -> list[str]:
    """Códigos de un solo uso por si se pierde el móvil (formato xxxxx-xxxxx)."""
    alphabet = "abcdefghjkmnpqrstuvwxyz23456789"  # sin 0/o, 1/l/i
    return [
        "-".join("".join(secrets.choice(alphabet) for _ in range(5)) for _ in range(2))
        for _ in range(count)
    ]


def normalize_recovery(code: str) -> str:
    return "".join(c for c in code.lower() if c.isalnum())


def hash_recovery(code: str) -> str:
    # Son aleatorios y de alta entropía: basta un hash rápido (no hace falta argon2)
    return hashlib.sha256(normalize_recovery(code).encode()).hexdigest()
