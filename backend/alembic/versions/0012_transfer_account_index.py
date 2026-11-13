"""transactions.transfer_account_id: índice

Revision ID: 0012
Revises: 0011
Create Date: 2026-11-13 00:00:00.000000
"""

from alembic import op

revision = "0012"
down_revision = "0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index("ix_transactions_transfer_account_id", "transactions", ["transfer_account_id"])


def downgrade() -> None:
    op.drop_index("ix_transactions_transfer_account_id", table_name="transactions")
