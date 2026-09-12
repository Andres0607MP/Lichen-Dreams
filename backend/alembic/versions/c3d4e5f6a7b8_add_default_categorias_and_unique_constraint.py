"""add_default_categorias_and_unique_constraint

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-08-27 19:45:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = 'c3d4e5f6a7b8'
down_revision: Union[str, None] = 'b2c3d4e5f6a7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Default categories for Liquenpedia (idempotent insert)
    # Uses portable INSERT ... ON CONFLICT / ON DUPLICATE KEY / OR IGNORE
    default_categories = [
        ('Ecología', 'Articulos sobre ecologia, medio ambiente y conservacion de liquenes', '#2E7D32', 'eco', 1),
        ('Educación', 'Articulos educativos, formativos y de divulgacion cientifica', '#1565C0', 'school', 2),
        ('General', 'Articulos generales sobre liquenes y su estudio', '#424242', 'article', 3),
        ('Investigación', 'Articulos de investigacion cientifica y estudios de campo', '#6A1B9A', 'science', 4),
        ('Conservación', 'Articulos sobre conservacion, amenazas y proteccion de especies', '#C62828', 'park', 5),
    ]

    bind = op.get_bind()
    dialect_name = bind.dialect.name
    
    # Build insert statement based on dialect
    if dialect_name == 'mysql':
        for nombre, descripcion, color, icono, orden in default_categories:
            op.execute(f"""
                INSERT INTO categorias_articulos (nombre_categoria, descripcion, color, icono, orden, activo)
                VALUES ('{nombre}', '{descripcion}', '{color}', '{icono}', {orden}, 1)
                ON DUPLICATE KEY UPDATE nombre_categoria = nombre_categoria
            """)
    elif dialect_name == 'sqlite':
        for nombre, descripcion, color, icono, orden in default_categories:
            op.execute(f"""
                INSERT OR IGNORE INTO categorias_articulos (nombre_categoria, descripcion, color, icono, orden, activo)
                VALUES ('{nombre}', '{descripcion}', '{color}', '{icono}', {orden}, 1)
            """)
    else:
        # PostgreSQL and others - use ON CONFLICT DO NOTHING
        for nombre, descripcion, color, icono, orden in default_categories:
            op.execute(f"""
                INSERT INTO categorias_articulos (nombre_categoria, descripcion, color, icono, orden, activo)
                VALUES ('{nombre}', '{descripcion}', '{color}', '{icono}', {orden}, 1)
                ON CONFLICT (nombre_categoria) DO NOTHING
            """)


def downgrade() -> None:
    # Note: We don't delete the default categories as they may be in use
    pass
