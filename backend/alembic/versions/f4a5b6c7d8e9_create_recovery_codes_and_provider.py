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

    # Use CREATE TABLE IF NOT EXISTS to avoid error if table already created by Base.metadata.create_all
    op.execute("""
        CREATE TABLE IF NOT EXISTS recovery_codes (
            id INTEGER NOT NULL AUTO_INCREMENT,
            id_usuario INTEGER NOT NULL,
            code_hash VARCHAR(255) NOT NULL,
            expires_at TIMESTAMP NOT NULL,
            used_at TIMESTAMP NULL,
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            FOREIGN KEY(id_usuario) REFERENCES usuarios (id_usuario),
            UNIQUE (code_hash)
        )
    """)
    # Create indexes if they don't exist
    op.execute("CREATE INDEX IF NOT EXISTS idx_recovery_code_hash ON recovery_codes (code_hash)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_recovery_id_usuario ON recovery_codes (id_usuario)")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS recovery_codes")
    op.drop_column('usuarios', 'proveedor')
    op.drop_column('usuarios', 'proveedor_id')