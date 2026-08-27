"""add_default_categorias_and_unique_constraint

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-08-27 19:45:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c3d4e5f6a7b8'
down_revision: Union[str, None] = 'b2c3d4e5f6a7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Default categories for Liquenpedia (idempotent insert)
    # Uses INSERT IGNORE with case-insensitive check to avoid duplicates
    default_categories = [
        ('Ecología', 'Artículos sobre ecología, medio ambiente y conservación de líquenes', '#2E7D32', 'eco', 1),
        ('Educación', 'Artículos educativos, formativos y de divulgación científica', '#1565C0', 'school', 2),
        ('General', 'Artículos generales sobre líquenes y su estudio', '#424242', 'article', 3),
        ('Investigación', 'Artículos de investigación científica y estudios de campo', '#6A1B9A', 'science', 4),
        ('Conservación', 'Artículos sobre conservación, amenazas y protección de especies', '#C62828', 'park', 5),
    ]

    for nombre, descripcion, color, icono, orden in default_categories:
        op.execute(f"""
            INSERT INTO categorias_articulos (nombre_categoria, descripcion, color, icono, orden, activo)
            SELECT '{nombre}', '{descripcion}', '{color}', '{icono}', {orden}, 1
            FROM DUAL
            WHERE NOT EXISTS (
                SELECT 1 FROM categorias_articulos WHERE LOWER(nombre_categoria) = LOWER('{nombre}')
            )
        """)


def downgrade() -> None:
    # Note: We don't delete the default categories as they may be in use
    pass
