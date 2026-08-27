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
    # Use CREATE TABLE IF NOT EXISTS to avoid error if table already created by Base.metadata.create_all
    op.execute("""
        CREATE TABLE IF NOT EXISTS password_reset_tokens (
            id INTEGER NOT NULL AUTO_INCREMENT,
            id_usuario INTEGER NOT NULL,
            token_hash VARCHAR(255) NOT NULL,
            expires_at TIMESTAMP NOT NULL,
            used_at TIMESTAMP NULL,
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            FOREIGN KEY(id_usuario) REFERENCES usuarios (id_usuario),
            UNIQUE (token_hash)
        )
    """)
    # Create indexes if they don't exist
    op.execute("CREATE INDEX IF NOT EXISTS idx_token_hash ON password_reset_tokens (token_hash)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_id_usuario ON password_reset_tokens (id_usuario)")


def downgrade() -> None:
    op.drop_table('password_reset_tokens')
