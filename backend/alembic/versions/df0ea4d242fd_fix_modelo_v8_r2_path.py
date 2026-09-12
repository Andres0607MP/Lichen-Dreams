"""fix_modelo_v8_r2_path

Corrige la ruta del modelo v8.0 en modelos_ia.observaciones para usar claves R2
relativas en lugar de la ruta absoluta de Windows.

- archivo: models/lichen_model_v8.keras
- class_mapping: models/class_mapping_v8.json

Revision ID: df0ea4d242fd
Revises: e8f9a0b1c2d3
Create Date: 2026-09-12 09:39:59.733279
"""
from typing import Sequence, Union
import json

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'df0ea4d242fd'
down_revision: Union[str, None] = 'e8f9a0b1c2d3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


MODELOS_TABLE = sa.table(
    "modelos_ia",
    sa.column("id_modelo", sa.Integer),
    sa.column("version", sa.String(50)),
    sa.column("estado_modelo", sa.String(50)),
    sa.column("observaciones", sa.Text),
)


# Valores originales de la migración d8e9f0a1b2c3 (register_modelo_v8)
# para poder restaurarlos en downgrade
ORIGINAL_ARCHIVO = "C:\\Users\\mance\\Documents\\Steffi\\Lichen-Dreams\\backend\\ia\\modelos\\lichen_model_v8.keras"
ORIGINAL_CLASS_MAPPING = "C:\\Users\\mance\\Documents\\Steffi\\Lichen-Dreams\\backend\\ia\\modelos\\class_mapping_v8.json"


def upgrade() -> None:
    bind = op.get_bind()

    # Obtener el registro actual de v8.0
    row = bind.execute(
        sa.select(MODELOS_TABLE.c.id_modelo, MODELOS_TABLE.c.observaciones).where(
            MODELOS_TABLE.c.version == "v8.0"
        )
    ).first()

    if row is None:
        print("[fix_modelo_v8_r2_path] No existe modelo version=v8.0; nada que hacer.")
        return

    id_modelo, observaciones_json = row
    if not observaciones_json:
        print(f"[fix_modelo_v8_r2_path] Modelo id={id_modelo} version=v8.0 sin observaciones; nada que hacer.")
        return

    # Parsear observaciones existentes
    try:
        obs = json.loads(observaciones_json)
    except Exception:
        print(f"[fix_modelo_v8_r2_path] Modelo id={id_modelo} observaciones no es JSON válido; saltando.")
        return

    # Actualizar solo las rutas necesarias
    obs["archivo"] = "models/lichen_model_v8.keras"
    obs["class_mapping"] = "models/class_mapping_v8.json"

    nuevo_json = json.dumps(obs, ensure_ascii=False)

    bind.execute(
        MODELOS_TABLE.update()
        .where(MODELOS_TABLE.c.id_modelo == id_modelo)
        .values(observaciones=nuevo_json)
    )
    print(f"[fix_modelo_v8_r2_path] Actualizado modelo id={id_modelo} version=v8.0: archivo -> models/lichen_model_v8.keras")


def downgrade() -> None:
    bind = op.get_bind()

    row = bind.execute(
        sa.select(MODELOS_TABLE.c.id_modelo, MODELOS_TABLE.c.observaciones).where(
            MODELOS_TABLE.c.version == "v8.0"
        )
    ).first()

    if row is None:
        print("[fix_modelo_v8_r2_path] downgrade: No existe modelo version=v8.0.")
        return

    id_modelo, observaciones_json = row
    if not observaciones_json:
        print(f"[fix_modelo_v8_r2_path] downgrade: Modelo id={id_modelo} sin observaciones.")
        return

    try:
        obs = json.loads(observaciones_json)
    except Exception:
        print(f"[fix_modelo_v8_r2_path] downgrade: observaciones no es JSON válido.")
        return

    # Restaurar valores originales de la migración d8e9f0a1b2c3
    obs["archivo"] = ORIGINAL_ARCHIVO
    obs["class_mapping"] = ORIGINAL_CLASS_MAPPING

    nuevo_json = json.dumps(obs, ensure_ascii=False)

    bind.execute(
        MODELOS_TABLE.update()
        .where(MODELOS_TABLE.c.id_modelo == id_modelo)
        .values(observaciones=nuevo_json)
    )
    print(f"[fix_modelo_v8_r2_path] downgrade: Restaurado modelo id={id_modelo} version=v8.0 a rutas absolutas originales.")

