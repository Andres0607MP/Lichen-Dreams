"""register_modelo_v8

Registra V8 en `modelos_ia` como modelo disponible/versionado (inactivo).
V3 permanece activo: ninguna fila activa se modifica y V8 se inserta con
`estado_modelo='inactivo'`.

V8: clasificador 3 clases (saludable=0, contaminado=1, desconocido=2),
MobileNetV2 + transfer learning, split V7 (dataset_v7_manifest.csv).
Test V7: accuracy 0.9386, macro F1 0.9101, balanced accuracy 0.9108.

La migracion es pura data (el esquema de `modelos_ia` ya soporta versionado
con `version`, `estado_modelo` y `observaciones`). Es idempotente: si ya
existe una fila version='v8.0' no inserta otra.

Revision ID: d8e9f0a1b2c3
Revises: 62d62e70527f
Create Date: 2026-09-03 22:20:00.000000
"""

import json
import os
from datetime import datetime
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd8e9f0a1b2c3'
down_revision: Union[str, None] = '62d62e70527f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODEL_DIR = os.path.join(BACKEND_DIR, "ia", "modelos")
KERAS_V8 = os.path.join(MODEL_DIR, "lichen_model_v8.keras")
CLASS_MAPPING_V8 = os.path.join(MODEL_DIR, "class_mapping_v8.json")

VERSION_V8 = "v8.0"


def _modelos_table():
    return sa.table(
        "modelos_ia",
        sa.column("id_modelo", sa.Integer),
        sa.column("nombre_modelo", sa.String(100)),
        sa.column("version", sa.String(50)),
        sa.column("tipo_modelo", sa.String(100)),
        sa.column("descripcion", sa.Text),
        sa.column("precision_modelo", sa.Float),
        sa.column("dataset_utilizado", sa.String(255)),
        sa.column("fecha_entrenamiento", sa.DateTime),
        sa.column("estado_modelo", sa.String(50)),
        sa.column("observaciones", sa.Text),
    )


def upgrade() -> None:
    bind = op.get_bind()
    modelos = _modelos_table()

    ya_existente = bind.execute(
        sa.select(modelos.c.version).where(modelos.c.version == VERSION_V8)
    ).first()
    if ya_existente is not None:
        print(f"[migracion v8] ya existe un modelo version={VERSION_V8}; no se duplica.")
        return

    observaciones = json.dumps(
        {
            "f1_macro": 0.9101,
            "accuracy": 0.9386,
            "balanced_accuracy": 0.9108,
            "seed": 42,
            "arch": "mobilenetv2",
            "split": "dataset_v7_manifest.csv (train/val/test ya definidos)",
            "clases": {"0": "liquen saludable", "1": "liquen contaminado", "2": "desconocido"},
            "archivo": KERAS_V8,
            "class_mapping": CLASS_MAPPING_V8,
        },
        ensure_ascii=False,
    )

    bind.execute(
        modelos.insert().values(
            nombre_modelo="clasificador ambiental 3 clases (v8)",
            version=VERSION_V8,
            tipo_modelo="mobilenetv2",
            descripcion="Transfer learning MobileNetV2 (3 fases) + head propio. "
                        "V8 supera a V3 (macro F1 0.9101 vs 0.2376 en test V7). "
                        "Registrado como inactivo (disponible): V3 sigue activo.",
            precision_modelo=0.9386,
            dataset_utilizado="liquenes_3clases_v7",
            fecha_entrenamiento=datetime.now(),
            estado_modelo="inactivo",
            observaciones=observaciones,
        )
    )
    print(f"[migracion v8] registrado version={VERSION_V8} estado='inactivo' (V3 activo intacto).")


def downgrade() -> None:
    bind = op.get_bind()
    modelos = _modelos_table()
    modelo_dataset = sa.table("modelo_dataset", sa.column("id_modelo", sa.Integer))

    filas = bind.execute(
        sa.select(modelos.c.id_modelo).where(modelos.c.version == VERSION_V8)
    ).all()
    for (mid,) in filas:
        bind.execute(modelo_dataset.delete().where(modelo_dataset.c.id_modelo == mid))
        bind.execute(modelos.delete().where(modelos.c.id_modelo == mid))
        print(f"[migracion v8] downgrade: eliminado modelo id_modelo={mid} version={VERSION_V8}")
    if not filas:
        print(f"[migracion v8] downgrade: no habia modelo version={VERSION_V8}.")