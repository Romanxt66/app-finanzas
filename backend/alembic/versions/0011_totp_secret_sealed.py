"""users.totp_secret: sitio para el secreto cifrado (AES-GCM, ~83 caracteres)

Revision ID: 0011
Revises: 0010
Create Date: 2026-11-13 00:00:00.000000
"""

import sqlalchemy as sa

from alembic import op

revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None


def _resize(length: int) -> None:
    # batch: en SQLite reconstruye la tabla; en Postgres es un ALTER COLUMN normal
    with op.batch_alter_table("users") as batch:
        batch.alter_column("totp_secret", type_=sa.String(length=length), existing_nullable=True)


def upgrade() -> None:
    _resize(255)


def downgrade() -> None:
    _resize(64)
