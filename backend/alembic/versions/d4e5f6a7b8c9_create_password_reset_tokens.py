"""create_password_reset_tokens

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
Create Date: 2026-08-27 20:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd4e5f6a7b8c9'
down_revision: Union[str, None] = 'c3d4e5f6a7b8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'password_reset_tokens',
        sa.Column('id', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('id_usuario', sa.Integer, sa.ForeignKey('usuarios.id_usuario'), nullable=False),
        sa.Column('token_hash', sa.String(255), nullable=False, unique=True),
        sa.Column('expires_at', sa.TIMESTAMP, nullable=False),
        sa.Column('used_at', sa.TIMESTAMP, nullable=True),
        sa.Column('created_at', sa.TIMESTAMP, nullable=True, server_default=sa.func.now()),
    )
    op.create_index('idx_token_hash', 'password_reset_tokens', ['token_hash'])
    op.create_index('idx_id_usuario_token', 'password_reset_tokens', ['id_usuario'])


def downgrade() -> None:
    op.drop_table('password_reset_tokens')
