"""add device tracking to sessions and revoke active legacy sessions

Revision ID: b3c4d5e6f7a8
Revises: a1b2c3d4e5f7
Create Date: 2026-09-19 02:30:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b3c4d5e6f7a8'
down_revision: Union[str, None] = 'a1b2c3d4e5f7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'sesiones',
        sa.Column('device_id', sa.String(length=64), nullable=True),
    )
    op.add_column(
        'sesiones',
        sa.Column('nombre_dispositivo', sa.String(length=255), nullable=True),
    )
    op.create_index(
        'idx_sesion_user_device',
        'sesiones',
        ['id_usuario', 'device_id'],
        unique=False,
    )
    op.execute(
        "UPDATE sesiones "
        "SET estado_sesion = 'revoked' "
        "WHERE estado_sesion = 'active'"
    )


def downgrade() -> None:
    op.drop_index('idx_sesion_user_device', table_name='sesiones')
    op.drop_column('sesiones', 'nombre_dispositivo')
    op.drop_column('sesiones', 'device_id')
