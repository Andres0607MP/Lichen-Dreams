"""add_visibilidad_to_analisis

Revision ID: add_visibilidad_001
Revises: f3dbcad4ad36
Create Date: 2026-08-17 14:58:32.892272
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'add_visibilidad_001'
down_revision: Union[str, None] = 'f3dbcad4ad36'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('analisis', sa.Column('visibilidad', sa.String(length=50), nullable=False, server_default='private'))
    op.create_index(op.f('idx_visibilidad'), 'analisis', ['visibilidad'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('idx_visibilidad'), table_name='analisis')
    op.drop_column('analisis', 'visibilidad')
