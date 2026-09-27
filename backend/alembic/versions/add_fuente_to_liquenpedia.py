"""add_fuente_to_liquenpedia

Revision ID: add_fuente_001
Revises: c5d6e7f8a9b0
Create Date: 2026-09-27 00:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'add_fuente_001'
down_revision: Union[str, None] = 'c5d6e7f8a9b0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('liquenpedia', sa.Column('fuente', sa.Text, nullable=True))


def downgrade() -> None:
    op.drop_column('liquenpedia', 'fuente')