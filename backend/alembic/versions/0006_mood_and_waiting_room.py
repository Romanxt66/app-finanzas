"""spending mood and waiting room

Revision ID: 0006
Revises: 0005
Create Date: 2026-10-27 12:00:00.000000
"""

import sqlalchemy as sa

from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("transactions", sa.Column("mood", sa.String(length=12), nullable=True))
    op.create_table(
        "waiting_items",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("amount", sa.Numeric(precision=18, scale=2), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("wait_hours", sa.Integer(), nullable=False),
        sa.Column("ready_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(length=10), nullable=False),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("(CURRENT_TIMESTAMP)"),
            nullable=False,
        ),
        sa.CheckConstraint("amount > 0", name="ck_waiting_items_amount_positive"),
        sa.CheckConstraint("wait_hours > 0", name="ck_waiting_items_wait_positive"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_waiting_items_user_id", "waiting_items", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_waiting_items_user_id", table_name="waiting_items")
    op.drop_table("waiting_items")
    op.drop_column("transactions", "mood")
