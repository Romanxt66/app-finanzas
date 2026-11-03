"""two-factor authentication

Revision ID: 0007
Revises: 0006
Create Date: 2026-10-27 18:00:00.000000
"""

import sqlalchemy as sa

from alembic import op

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("totp_secret", sa.String(length=64), nullable=True))
    op.add_column(
        "users",
        sa.Column("totp_enabled", sa.Boolean(), server_default="false", nullable=False),
    )
    op.add_column("users", sa.Column("totp_last_step", sa.Integer(), nullable=True))
    op.add_column("users", sa.Column("recovery_codes", sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "recovery_codes")
    op.drop_column("users", "totp_last_step")
    op.drop_column("users", "totp_enabled")
    op.drop_column("users", "totp_secret")
