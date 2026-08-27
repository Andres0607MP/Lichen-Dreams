"""create_categorias_articulos

Revision ID: a1b2c3d4e5f6
Revises: f3dbcad4ad36
Create Date: 2026-08-27 20:00:00.000000
"""

from datetime import datetime
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = 'f3dbcad4ad36'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'categorias_articulos',
        sa.Column('id_categoria', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('nombre_categoria', sa.String(100), nullable=False, unique=True),
        sa.Column('descripcion', sa.Text, nullable=True),
        sa.Column('color', sa.String(7), nullable=True),
        sa.Column('icono', sa.String(50), nullable=True),
        sa.Column('orden', sa.Integer, server_default='0'),
        sa.Column('activo', sa.Boolean, server_default='1'),
        sa.Column('fecha_creacion', sa.TIMESTAMP, server_default=sa.func.now()),
        sa.Index('idx_nombre_categoria', 'nombre_categoria'),
        sa.Index('idx_orden', 'orden'),
    )

    op.add_column('liquenpedia', sa.Column('id_categoria', sa.Integer, nullable=True))
    op.create_foreign_key('fk_liquenpedia_categoria', 'liquenpedia', 'categorias_articulos', ['id_categoria'], ['id_categoria'])
    op.create_index('idx_id_categoria', 'liquenpedia', ['id_categoria'])

    # Insert default categories based on existing article categories
    op.execute("""
        INSERT INTO categorias_articulos (nombre_categoria, descripcion, orden, activo)
        SELECT DISTINCT 
            LOWER(categoria),
            CASE 
                WHEN LOWER(categoria) = 'ecologia' THEN 'Artículos sobre ecología y medio ambiente'
                WHEN LOWER(categoria) = 'general' THEN 'Artículos generales sobre líquenes'
                WHEN LOWER(categoria) = 'educacion' THEN 'Artículos educativos y formativos'
                ELSE CONCAT('Artículos sobre ', LOWER(categoria))
            END,
            CASE 
                WHEN LOWER(categoria) = 'ecologia' THEN 1
                WHEN LOWER(categoria) = 'general' THEN 2
                WHEN LOWER(categoria) = 'educacion' THEN 3
                ELSE 10
            END,
            1
        FROM liquenpedia
        WHERE categoria IS NOT NULL AND categoria != ''
        ON DUPLICATE KEY UPDATE nombre_categoria = nombre_categoria
    """)

    # Update existing articles to reference the new categories
    op.execute("""
        UPDATE liquenpedia l
        INNER JOIN categorias_articulos c ON LOWER(l.categoria) = c.nombre_categoria
        SET l.id_categoria = c.id_categoria
    """)


def downgrade() -> None:
    op.drop_index('idx_id_categoria', table_name='liquenpedia')
    op.drop_constraint('fk_liquenpedia_categoria', 'liquenpedia', type_='foreignkey')
    op.drop_column('liquenpedia', 'id_categoria')
    op.drop_table('categorias_articulos')
