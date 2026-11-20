"""auth_failures (límite de intentos compartido entre procesos) e índices de claves foráneas

Revision ID: 0013
Revises: 0012
Create Date: 2026-11-20 00:00:00.000000
"""

import sqlalchemy as sa

from alembic import op

revision = "0013"
down_revision = "0012"
branch_labels = None
depends_on = None

# Claves foráneas sin índice: Postgres no las indexa solo, y sin índice borrar una cuenta, una
# categoría o un usuario recorre la tabla entera para comprobar que nadie la usa.
FK_INDEXES = [
    ("ix_goal_contributions_user_id", "goal_contributions", "user_id"),
    ("ix_budgets_category_id", "budgets", "category_id"),
    ("ix_recurring_rules_account_id", "recurring_rules", "account_id"),
    ("ix_recurring_rules_transfer_account_id", "recurring_rules", "transfer_account_id"),
    ("ix_recurring_rules_category_id", "recurring_rules", "category_id"),
]


def upgrade() -> None:
    op.create_table(
        "auth_failures",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("scope", sa.String(length=32), nullable=False),
        sa.Column("key", sa.String(length=400), nullable=False),
        sa.Column("at", sa.Float(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_auth_failures_scope_key_at", "auth_failures", ["scope", "key", "at"])
    op.create_index("ix_auth_failures_at", "auth_failures", ["at"])
    for name, table, column in FK_INDEXES:
        op.create_index(name, table, [column])


def downgrade() -> None:
    for name, table, _ in reversed(FK_INDEXES):
        op.drop_index(name, table_name=table)
    op.drop_index("ix_auth_failures_at", table_name="auth_failures")
    op.drop_index("ix_auth_failures_scope_key_at", table_name="auth_failures")
    op.drop_table("auth_failures")
