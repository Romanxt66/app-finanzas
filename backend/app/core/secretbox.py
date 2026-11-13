"""Cifrado en reposo de secretos pequeños (el secreto TOTP de la verificación en dos pasos).

Si se filtrara la base de datos o una copia de seguridad, el segundo factor de cada cuenta no
quedaría expuesto. AES-256-GCM con una clave derivada de SECRET_KEY (HKDF, contexto propio):
cambiar SECRET_KEY invalida las sesiones y también estos secretos, así que quien tenga la
verificación activa tendrá que entrar con un código de recuperación y volver a activarla.
"""

import base64
import os
from functools import lru_cache

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

from app.core.config import get_settings

_PREFIX = "v1:"


@lru_cache
def _cipher(secret_key: str) -> AESGCM:
    key = HKDF(
        algorithm=hashes.SHA256(), length=32, salt=None, info=b"alvea/totp-secret/v1"
    ).derive(secret_key.encode())
    return AESGCM(key)


def seal(plain: str) -> str:
    nonce = os.urandom(12)
    data = _cipher(get_settings().secret_key).encrypt(nonce, plain.encode(), None)
    return _PREFIX + base64.urlsafe_b64encode(nonce + data).decode().rstrip("=")


def is_sealed(stored: str) -> bool:
    return stored.startswith(_PREFIX)


def unseal(stored: str) -> str:
    """El valor en claro; los guardados antes del cifrado (sin prefijo) se devuelven tal cual."""
    if not is_sealed(stored):
        return stored
    raw = stored[len(_PREFIX) :]
    blob = base64.urlsafe_b64decode(raw + "=" * (-len(raw) % 4))
    return _cipher(get_settings().secret_key).decrypt(blob[:12], blob[12:], None).decode()
