"""add unique index on usuarios (proveedor, proveedor_id)

Revision ID: f6a7b8c9d0e1
Revises: f5a6b7c8d9e0
Create Date: 2026-08-29 17:00:00.000000
"""

from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'f6a7b8c9d0e1'
down_revision: Union[str, None] = 'f5a6b7c8d9e0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Evita duplicar el mismo usuario de Google (proveedor='google').
    # Los usuarios locales tienen proveedor_id NULL: en MySQL los NULL
    # no colisionan en un índice UNIQUE, por lo que no afecta a las
    # cuentas locales existentes.
    op.create_index(
        'uq_usuarios_proveedor',
        'usuarios',
        ['proveedor', 'proveedor_id'],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index('uq_usuarios_proveedor', table_name='usuarios')