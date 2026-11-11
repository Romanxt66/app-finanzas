"""budgets: day/week/month periods, general (no category) and recurring

Revision ID: 0010
Revises: 0009
Create Date: 2026-11-11 00:00:00.000000
"""

import sqlalchemy as sa

from alembic import op

revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None

# La restricción única original no tenía nombre: Postgres la llamó así (y SQLite la tiene igual
# tras las migraciones anteriores, que recrearon la tabla)
_OLD_UNIQUE = "budgets_user_id_category_id_month_key"


def _new_budgets(name: str) -> None:
    op.create_table(
        name,
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("category_id", sa.Uuid(), sa.ForeignKey("categories.id"), nullable=True),
        sa.Column("period", sa.String(length=10), server_default="month", nullable=False),
        sa.Column("month", sa.Date(), nullable=False),
        sa.Column("amount", sa.Numeric(precision=18, scale=2), nullable=False),
        sa.Column("recurring", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("(CURRENT_TIMESTAMP)"),
            nullable=False,
        ),
        sa.CheckConstraint("amount > 0", name="ck_budgets_amount_positive"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "category_id", "period", "month", name="uq_budgets_scope"),
    )


def upgrade() -> None:
    if op.get_bind().dialect.name == "postgresql":
        op.drop_constraint(_OLD_UNIQUE, "budgets", type_="unique")
        op.add_column(
            "budgets",
            sa.Column("period", sa.String(length=10), server_default="month", nullable=False),
        )
        op.add_column(
            "budgets",
            sa.Column("recurring", sa.Boolean(), server_default=sa.false(), nullable=False),
        )
        op.alter_column("budgets", "category_id", existing_type=sa.Uuid(), nullable=True)
        op.create_unique_constraint(
            "uq_budgets_scope", "budgets", ["user_id", "category_id", "period", "month"]
        )
        return
    # SQLite no sabe quitar una restricción sin nombre: se rehace la tabla copiando los datos
    _new_budgets("budgets_new")
    op.execute(
        "INSERT INTO budgets_new (user_id, category_id, period, month, amount, recurring, id,"
        " created_at) SELECT user_id, category_id, 'month', month, amount, 0, id, created_at"
        " FROM budgets"
    )
    op.drop_index("ix_budgets_user_id", table_name="budgets")
    op.drop_table("budgets")
    op.rename_table("budgets_new", "budgets")
    op.create_index("ix_budgets_user_id", "budgets", ["user_id"], unique=False)


def downgrade() -> None:
    # Los generales y los de día o semana no caben en el esquema anterior: se descartan
    op.execute("DELETE FROM budgets WHERE category_id IS NULL OR period <> 'month'")
    with op.batch_alter_table("budgets") as batch:
        batch.drop_constraint("uq_budgets_scope", type_="unique")
        batch.alter_column("category_id", existing_type=sa.Uuid(), nullable=False)
        batch.drop_column("recurring")
        batch.drop_column("period")
        batch.create_unique_constraint(_OLD_UNIQUE, ["user_id", "category_id", "month"])
