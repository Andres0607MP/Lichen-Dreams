"""add unique nombre_cientifico to especies_liquenes

Revision ID: f1a2b3c4d5e6
Revises: e5f6a7b8c9d0
Create Date: 2026-08-27 23:30:00.000000
"""

from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'f1a2b3c4d5e6'
down_revision: Union[str, None] = 'e5f6a7b8c9d0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_index(
        'uq_especies_nombre_cientifico',
        'especies_liquenes',
        ['nombre_cientifico'],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index('uq_especies_nombre_cientifico', table_name='especies_liquenes')