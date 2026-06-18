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
    # Todas las columnas ya existen en la base de datos creada desde schema.sql
    # Esta migración documenta que usuarios y sesiones están sincronizadas
    pass


def downgrade() -> None:
    # No hay cambios que revertir
    pass
