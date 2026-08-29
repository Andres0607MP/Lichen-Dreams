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
    # Tabla gestionada por el modelo HistorialActividad.
    # No estaba incluida en ninguna migración previa: la creaba
    # Base.metadata.create_all() en cada arranque. Al migrar el esquema
    # exclusivamente con Alembic, debe quedar cubierta aquí.
    op.execute("""
        CREATE TABLE IF NOT EXISTS historial_actividad (
            id_historial INTEGER NOT NULL AUTO_INCREMENT,
            id_usuario INTEGER NULL,
            accion_realizada VARCHAR(255) NULL,
            descripcion_accion TEXT NULL,
            dispositivo VARCHAR(100) NULL,
            ip_usuario VARCHAR(50) NULL,
            fecha TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id_historial),
            FOREIGN KEY(id_usuario) REFERENCES usuarios (id_usuario)
        )
    """)


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS historial_actividad")