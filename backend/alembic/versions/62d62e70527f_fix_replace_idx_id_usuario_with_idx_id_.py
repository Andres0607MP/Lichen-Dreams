"""fix: replace idx_id_usuario with idx_id_usuario_token on password_reset_tokens

Revision ID: 62d62e70527f
Revises: e2f3a4b5c6d7
Create Date: 2026-09-02 18:13:43.454480
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '62d62e70527f'
down_revision: Union[str, None] = 'e2f3a4b5c6d7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Crear nuevo índice primero (MySQL requiere un índice para FK)
    op.create_index('idx_id_usuario_token', 'password_reset_tokens', ['id_usuario'])
    # Eliminar FK, luego índice antiguo, luego restaurar FK
    op.drop_constraint('password_reset_tokens_ibfk_1', 'password_reset_tokens', type_='foreignkey')
    op.drop_index('idx_id_usuario', table_name='password_reset_tokens')
    op.create_foreign_key(
        'password_reset_tokens_ibfk_1',
        'password_reset_tokens',
        'usuarios',
        ['id_usuario'],
        ['id_usuario'],
    )


def downgrade() -> None:
    # Eliminar FK, crear índice antiguo, restaurar FK
    op.drop_constraint('password_reset_tokens_ibfk_1', 'password_reset_tokens', type_='foreignkey')
    op.create_index('idx_id_usuario', 'password_reset_tokens', ['id_usuario'])
    op.create_foreign_key(
        'password_reset_tokens_ibfk_1',
        'password_reset_tokens',
        'usuarios',
        ['id_usuario'],
        ['id_usuario'],
    )
    op.drop_index('idx_id_usuario_token', table_name='password_reset_tokens')
