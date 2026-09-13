"""change_notificaciones_fecha_timestamp_to_datetime

Revision ID: cfec7c30b23b
Revises: 91f2ea0edfff
Create Date: 2026-09-13 09:44:46.134052
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = 'cfec7c30b23b'
down_revision: Union[str, None] = '91f2ea0edfff'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Cambiar notificaciones.fecha de TIMESTAMP a DATETIME
    # Eliminar server_default basado en CURRENT_TIMESTAMP/func.now()
    # El timestamp se generará exclusivamente por Python (UTC)
    op.alter_column(
        'notificaciones',
        'fecha',
        existing_type=mysql.TIMESTAMP(),
        type_=sa.DateTime(),
        nullable=False,
        existing_server_default=sa.text('(now())'),
        server_default=None,
    )


def downgrade() -> None:
    # Revertir: DATETIME -> TIMESTAMP con server_default
    op.alter_column(
        'notificaciones',
        'fecha',
        existing_type=sa.DateTime(),
        type_=mysql.TIMESTAMP(),
        nullable=True,
        existing_server_default=None,
        server_default=sa.text('(now())'),
    )