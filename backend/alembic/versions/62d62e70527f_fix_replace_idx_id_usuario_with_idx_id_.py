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
    # No-op: d4e5f6a7b8c9 ya crea directamente
    # idx_id_usuario_token con el nombre correcto.
    pass


def downgrade() -> None:
    # No-op: esta migración no realiza cambios en el estado actual.
    pass
