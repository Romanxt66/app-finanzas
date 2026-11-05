"""google sign-in: optional password and linked google account

Revision ID: 0008
Revises: 0007
Create Date: 2026-11-05 22:30:00.000000
"""

import sqlalchemy as sa

from alembic import op

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.alter_column("hashed_password", existing_type=sa.String(length=255), nullable=True)
        batch.add_column(sa.Column("google_sub", sa.String(length=255), nullable=True))
        batch.create_unique_constraint("uq_users_google_sub", ["google_sub"])


def downgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.drop_constraint("uq_users_google_sub", type_="unique")
        batch.drop_column("google_sub")
        batch.alter_column("hashed_password", existing_type=sa.String(length=255), nullable=False)
