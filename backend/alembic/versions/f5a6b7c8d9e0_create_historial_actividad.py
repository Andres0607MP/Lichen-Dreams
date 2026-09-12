"""create historial_actividad

Revision ID: f5a6b7c8d9e0
Revises: f4a5b6c7d8e9
Create Date: 2026-08-29 16:40:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f5a6b7c8d9e0'
down_revision: Union[str, None] = 'f4a5b6c7d8e9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'historial_actividad',
        sa.Column('id_historial', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('id_usuario', sa.Integer, sa.ForeignKey('usuarios.id_usuario'), nullable=True),
        sa.Column('accion_realizada', sa.String(255), nullable=True),
        sa.Column('descripcion_accion', sa.Text, nullable=True),
        sa.Column('dispositivo', sa.String(100), nullable=True),
        sa.Column('ip_usuario', sa.String(50), nullable=True),
        sa.Column('fecha', sa.TIMESTAMP, nullable=True, server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table('historial_actividad')