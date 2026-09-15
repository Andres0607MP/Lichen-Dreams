"""rename token_sesion column to token_sesion_hash and add unique constraint

Revision ID: a1b2c3d4e5f7
Revises: cfec7c30b23b
Create Date: 2026-09-15 04:17:04.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f7'
down_revision: Union[str, None] = 'cfec7c30b23b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Rename token_sesion to token_sesion_hash
    op.alter_column('sesiones', 'token_sesion', new_column_name='token_sesion_hash',
                    existing_type=sa.String(64), nullable=False)
    # Drop the old non-unique index
    op.drop_index('idx_token_sesion', table_name='sesiones')
    # Create unique index for the new column
    op.create_index('uq_token_sesion_hash', 'sesiones', ['token_sesion_hash'], unique=True)


def downgrade() -> None:
    # Drop the unique index
    op.drop_index('uq_token_sesion_hash', table_name='sesiones')
    # Recreate the old non-unique index
    op.create_index('idx_token_sesion', 'sesiones', ['token_sesion'], unique=False)
    # Rename column back to token_sesion
    op.alter_column('sesiones', 'token_sesion_hash', new_column_name='token_sesion',
                    existing_type=sa.String(64), nullable=False)