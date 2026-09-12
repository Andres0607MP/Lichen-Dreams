"""create_recovery_codes and provider columns for usuarios

Revision ID: f4a5b6c7d8e9
Revises: f1a2b3c4d5e6
Create Date: 2026-08-29 15:30:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f4a5b6c7d8e9'
down_revision: Union[str, None] = 'f1a2b3c4d5e6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Preparar la arquitectura para futuros proveedores de autenticación (ej: Google).
    # Aditivo y retrocompatible: los usuarios locales usan proveedor 'local'.
    op.add_column('usuarios', sa.Column('proveedor', sa.String(50), nullable=False, server_default='local'))
    op.add_column('usuarios', sa.Column('proveedor_id', sa.String(255), nullable=True))

    op.create_table(
        'recovery_codes',
        sa.Column('id', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('id_usuario', sa.Integer, sa.ForeignKey('usuarios.id_usuario'), nullable=False),
        sa.Column('code_hash', sa.String(255), nullable=False, unique=True),
        sa.Column('expires_at', sa.TIMESTAMP, nullable=False),
        sa.Column('used_at', sa.TIMESTAMP, nullable=True),
        sa.Column('created_at', sa.TIMESTAMP, nullable=True, server_default=sa.func.now()),
    )
    op.create_index('idx_recovery_code_hash', 'recovery_codes', ['code_hash'])
    op.create_index('idx_recovery_id_usuario', 'recovery_codes', ['id_usuario'])


def downgrade() -> None:
    op.drop_table('recovery_codes')
    op.drop_column('usuarios', 'proveedor')
    op.drop_column('usuarios', 'proveedor_id')