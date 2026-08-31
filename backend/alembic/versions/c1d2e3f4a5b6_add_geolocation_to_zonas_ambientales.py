"""add geolocation to zonas_ambientales

Revision ID: c1d2e3f4a5b6
Revises: b1c2d3e4f5a6
Create Date: 2026-08-31 02:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c1d2e3f4a5b6'
down_revision: Union[str, None] = 'b1c2d3e4f5a6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Definición geográfica de la zona (centro + radio). Todos opcionales para
    # no romper zonas existentes sin coordenadas.
    op.add_column('zonas_ambientales', sa.Column('latitud', sa.DECIMAL(10, 8), nullable=True))
    op.add_column('zonas_ambientales', sa.Column('longitud', sa.DECIMAL(11, 8), nullable=True))
    op.add_column('zonas_ambientales', sa.Column('radio_metros', sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column('zonas_ambientales', 'radio_metros')
    op.drop_column('zonas_ambientales', 'longitud')
    op.drop_column('zonas_ambientales', 'latitud')