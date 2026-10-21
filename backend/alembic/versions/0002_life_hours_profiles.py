"""life hours profiles

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-21 12:00:00.000000
"""

import sqlalchemy as sa

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "life_hours_profiles",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("monthly_net_income", sa.Numeric(precision=18, scale=2), nullable=False),
        sa.Column("weekly_hours", sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("(CURRENT_TIMESTAMP)"),
            nullable=False,
        ),
        sa.CheckConstraint("monthly_net_income > 0", name="ck_life_hours_income_positive"),
        sa.CheckConstraint(
            "weekly_hours > 0 AND weekly_hours <= 168", name="ck_life_hours_weekly_hours_range"
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )


def downgrade() -> None:
    op.drop_table("life_hours_profiles")
