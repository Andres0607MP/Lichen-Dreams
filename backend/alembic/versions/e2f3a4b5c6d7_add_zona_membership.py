"""add zona membership table and usuario_creador to zonas_ambientales

Revision ID: e2f3a4b5c6d7
Revises: d1e2f3a4b5c6
Create Date: 2026-09-02 20:15:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e2f3a4b5c6d7'
down_revision: Union[str, None] = 'd1e2f3a4b5c6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add id_usuario_creador to zonas_ambientales
    op.add_column('zonas_ambientales', sa.Column('id_usuario_creador', sa.Integer(), nullable=True))
    op.create_foreign_key(
        'fk_zona_usuario_creador',
        'zonas_ambientales', 'usuarios',
        ['id_usuario_creador'], ['id_usuario'],
        ondelete='SET NULL'
    )
    op.create_index('idx_zona_usuario_creador', 'zonas_ambientales', ['id_usuario_creador'])
    
    # Create analisis_zonas_ambientales table
    op.create_table(
        'analisis_zonas_ambientales',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('id_analisis', sa.Integer(), nullable=False),
        sa.Column('id_zona', sa.Integer(), nullable=False),
        sa.Column('fecha_asociacion', sa.TIMESTAMP(), server_default=sa.text('CURRENT_TIMESTAMP'), nullable=True),
        sa.ForeignKeyConstraint(['id_analisis'], ['analisis.id_analisis'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['id_zona'], ['zonas_ambientales.id_zona'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('id_analisis', 'id_zona', name='uk_analisis_zona')
    )
    op.create_index('idx_analisis_zona_id_zona', 'analisis_zonas_ambientales', ['id_zona'])
    op.create_index('idx_analisis_zona_id_analisis', 'analisis_zonas_ambientales', ['id_analisis'])
    
    # Create index on ubicaciones for bounding box queries
    op.create_index('idx_ubicaciones_geo', 'ubicaciones', ['latitud', 'longitud'])


def downgrade() -> None:
    op.drop_index('idx_ubicaciones_geo', 'ubicaciones')
    op.drop_index('idx_analisis_zona_id_analisis', 'analisis_zonas_ambientales')
    op.drop_index('idx_analisis_zona_id_zona', 'analisis_zonas_ambientales')
    op.drop_table('analisis_zonas_ambientales')
    op.drop_index('idx_zona_usuario_creador', 'zonas_ambientales')
    op.drop_constraint('fk_zona_usuario_creador', 'zonas_ambientales', type_='foreignkey')
    op.drop_column('zonas_ambientales', 'id_usuario_creador')