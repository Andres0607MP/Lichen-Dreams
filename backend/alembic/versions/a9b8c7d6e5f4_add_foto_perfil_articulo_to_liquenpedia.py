"""add_foto_perfil_articulo_to_liquenpedia

Revision ID: a9b8c7d6e5f4
Revises: f6a7b8c9d0e1
Create Date: 2026-08-30 18:10:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'a9b8c7d6e5f4'
down_revision: Union[str, None] = 'f6a7b8c9d0e1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('liquenpedia', sa.Column('foto_perfil_articulo', sa.Text, nullable=True))


def downgrade() -> None:
    op.drop_column('liquenpedia', 'foto_perfil_articulo')
