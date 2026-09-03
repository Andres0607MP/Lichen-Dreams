"""activate_modelo_v8

Activacion explicita y controlada de V8 como modelo activo en `modelos_ia`.

- v8.0 (MobileNetV2, registrado por d8e9f0a1b2c3 como 'inactivo') pasa a
  'activo'.
- Cualquier otro modelo activo (p. ej. v3.0) pasa a 'inactivo'.
- Garantiza como maximo UN modelo activo.
- NO usa fallback a archivos .keras: la resolucion sigue siendo
  BD -> ModeloIA(estado='activo') -> resolver_modelo_activo() -> ruta -> carga.

Reversible: downgrade() deja v8.0 como 'inactivo' y restaura 'activo' en v3.0
si existe (estado previo establecido del entorno).

Revision ID: e8f9a0b1c2d3
Revises: d8e9f0a1b2c3
Create Date: 2026-09-03 22:40:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e8f9a0b1c2d3'
down_revision: Union[str, None] = 'd8e9f0a1b2c3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

VERSION_V8 = "v8.0"
VERSION_V3 = "v3.0"


def _modelos_table():
    return sa.table(
        "modelos_ia",
        sa.column("id_modelo", sa.Integer),
        sa.column("version", sa.String(50)),
        sa.column("estado_modelo", sa.String(50)),
    )


def upgrade() -> None:
    bind = op.get_bind()
    modelos = _modelos_table()

    v8 = bind.execute(
        sa.select(modelos.c.id_modelo).where(modelos.c.version == VERSION_V8)
    ).first()
    if v8 is None:
        raise RuntimeError(
            f"No existe el registro version={VERSION_V8}; la migracion de registro "
            "d8e9f0a1b2c3 debe estar aplicada antes de activar."
        )

    bind.execute(
        modelos.update().where(modelos.c.estado_modelo == "activo").values(estado_modelo="inactivo")
    )
    bind.execute(
        modelos.update().where(modelos.c.version == VERSION_V8).values(estado_modelo="activo")
    )
    print(f"[activacion v8] {VERSION_V8} -> 'activo'; resto de modelos -> 'inactivo'.")


def downgrade() -> None:
    bind = op.get_bind()
    modelos = _modelos_table()

    bind.execute(
        modelos.update().where(modelos.c.version == VERSION_V8).values(estado_modelo="inactivo")
    )
    v3 = bind.execute(
        sa.select(modelos.c.id_modelo).where(modelos.c.version == VERSION_V3)
    ).first()
    if v3 is not None:
        bind.execute(
            modelos.update().where(modelos.c.version == VERSION_V3).values(estado_modelo="activo")
        )
        print(f"[activacion v8] downgrade: {VERSION_V8} -> 'inactivo'; {VERSION_V3} restaurado 'activo'.")
    else:
        print(f"[activacion v8] downgrade: {VERSION_V8} -> 'inactivo' (sin {VERSION_V3} que restaurar).")