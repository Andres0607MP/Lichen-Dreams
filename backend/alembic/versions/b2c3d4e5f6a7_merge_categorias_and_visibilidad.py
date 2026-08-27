"""merge_categorias_and_visibilidad

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6, add_visibilidad_001
Create Date: 2026-08-27 19:30:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b2c3d4e5f6a7'
down_revision: Union[str, tuple] = ('a1b2c3d4e5f6', 'add_visibilidad_001')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Merge migration - no changes needed as both branches are compatible."""
    pass


def downgrade() -> None:
    """Merge migration - no changes to revert."""
    pass
