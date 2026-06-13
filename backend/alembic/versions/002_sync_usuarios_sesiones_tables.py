"""Sincronizar tablas usuarios y sesiones con schema.sql

Revision ID: 002
Revises: 001
Create Date: 2026-06-13

"""
from alembic import op
import sqlalchemy as sa


revision = '002'
down_revision = '001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Agregar columnas faltantes en usuarios
    op.add_column('usuarios', sa.Column('tipo_documento', sa.String(20), nullable=True))
    op.add_column('usuarios', sa.Column('numero_documento', sa.String(50), nullable=True))
    op.add_column('usuarios', sa.Column('foto_perfil', sa.Text, nullable=True))
    op.add_column('usuarios', sa.Column('fecha_nacimiento', sa.DateTime, nullable=True))
    op.add_column('usuarios', sa.Column('ultimo_acceso', sa.TIMESTAMP, nullable=True))
    op.add_column('usuarios', sa.Column('estado_cuenta', sa.String(50), nullable=True))
    
    # Agregar columnas faltantes en sesiones
    op.add_column('sesiones', sa.Column('sistema_operativo', sa.String(100), nullable=True))


def downgrade() -> None:
    op.drop_column('usuarios', 'tipo_documento')
    op.drop_column('usuarios', 'numero_documento')
    op.drop_column('usuarios', 'foto_perfil')
    op.drop_column('usuarios', 'fecha_nacimiento')
    op.drop_column('usuarios', 'ultimo_acceso')
    op.drop_column('usuarios', 'estado_cuenta')
    op.drop_column('sesiones', 'sistema_operativo')
