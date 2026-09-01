"""enforce NOT NULL on especies_liquenes.nombre_cientifico

Revision ID: d1e2f3a4b5c6
Revises: c1d2e3f4a5b6
Create Date: 2026-09-01 02:35:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd1e2f3a4b5c6'
down_revision: Union[str, None] = 'c1d2e3f4a5b6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Backfill por seguridad: ninguna especie queda sin nombre (el código
    # asume nombre_cientifico obligatorio).
    op.execute(
        """
        UPDATE especies_liquenes
        SET nombre_cientifico = CONCAT('especie_', id_especie)
        WHERE nombre_cientifico IS NULL OR TRIM(nombre_cientifico) = ''
        """
    )
    op.alter_column(
        'especies_liquenes', 'nombre_cientifico',
        existing_type=sa.String(100),
        nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        'especies_liquenes', 'nombre_cientifico',
        existing_type=sa.String(100),
        nullable=True,
    )