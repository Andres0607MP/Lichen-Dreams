"""Add missing columns to usuarios table

Revision ID: 001
Revises: 
Create Date: 2026-06-13

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add fecha_actualizacion column if it doesn't exist
    op.add_column('usuarios', sa.Column('fecha_actualizacion', sa.DateTime(), nullable=True))
    
    # Add estado_activo column if it doesn't exist
    op.add_column('usuarios', sa.Column('estado_activo', sa.Boolean(), server_default='1', nullable=False))


def downgrade() -> None:
    # Remove columns
    op.drop_column('usuarios', 'estado_activo')
    op.drop_column('usuarios', 'fecha_actualizacion')
