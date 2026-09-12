"""create_email_verification_tokens

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Create Date: 2026-08-27 20:45:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e5f6a7b8c9d0'
down_revision: Union[str, None] = 'd4e5f6a7b8c9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'email_verification_tokens',
        sa.Column('id', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('id_usuario', sa.Integer, sa.ForeignKey('usuarios.id_usuario'), nullable=False),
        sa.Column('token_hash', sa.String(255), nullable=False, unique=True),
        sa.Column('expires_at', sa.TIMESTAMP, nullable=False),
        sa.Column('used_at', sa.TIMESTAMP, nullable=True),
        sa.Column('created_at', sa.TIMESTAMP, nullable=True, server_default=sa.func.now()),
    )
    op.create_index('idx_verification_token_hash', 'email_verification_tokens', ['token_hash'])
    op.create_index('idx_verification_id_usuario', 'email_verification_tokens', ['id_usuario'])


def downgrade() -> None:
    op.drop_table('email_verification_tokens')
