"""Configuración global de pytest del backend.

Aísla cada ejecución de tests de forma limpia:
- Define DATABASE_URL ANTES de que cualquier módulo de test importe
  config.database (los módulos usan os.environ.setdefault, por lo que heredan
  este valor).
- Usa un archivo SQLite TEMPORAL único por proceso, eliminado antes de cada
  sesión, de modo que ninguna corrida hereda estado persistente de otra.
- Bootstrap del esquema + roles + usuario admin en esa BD temporal, para que
  cada módulo de tests sea autosuficiente (no depende de `backend/test.db`
  ni de semillas de corridas anteriores).

No se modifica producción, ni MySQL, ni modelos, ni migraciones.
"""
import os
import tempfile

_db_path = os.path.join(tempfile.gettempdir(), "lichen_pytest.db")

if os.path.exists(_db_path):
    try:
        os.remove(_db_path)
    except OSError:
        pass

os.environ["DATABASE_URL"] = "sqlite:///" + _db_path.replace("\\", "/")

# Bootstrap del esquema y semillas mínimas (roles + admin) sobre la BD temporal.
try:
    from config.db import SessionLocal, engine
    from models.base import Base
    from models.core import Role, Usuario, ModeloIA
    from auth.password_handler import hash_password
    import json as _json
    from pathlib import Path as _Path

    _MODEL_V3 = _Path(__file__).resolve().parent / "ia" / "modelos" / "lichen_model_v3.keras"

    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        admin_role = db.query(Role).filter(Role.nombre_rol == "admin").first()
        if not admin_role:
            admin_role = Role(nombre_rol="admin", descripcion="Administrador", nivel_acceso=10)
            user_role = Role(nombre_rol="user", descripcion="Usuario normal", nivel_acceso=1)
            db.add(admin_role)
            db.add(user_role)
            db.flush()
            if not db.query(Usuario).filter(Usuario.correo == "admin@gmail.com").first():
                db.add(
                    Usuario(
                        nombre="Admin",
                        apellido="",
                        correo="admin@gmail.com",
                        contrasena=hash_password("admin123"),
                        estado_cuenta="active",
                        id_rol=admin_role.id_rol,
                        proveedor="local",
                    )
                )
            db.commit()

        # Modelo activo de referencia: V3 (coherente con produccion). Usa un
        # id_modelo alto para no colisionar con los id_modelo=1 de otros tests.
        # refleja el estado real esperado: 0=saludable, 1=contaminado, 2=desconocido.
        if _MODEL_V3.exists() and not db.query(ModeloIA).filter(
                ModeloIA.estado_modelo == "activo",
                ModeloIA.version == "v3.0").first():
            db.add(ModeloIA(
                id_modelo=900,
                nombre_modelo="clasificador ambiental 3 clases",
                version="v3.0",
                tipo_modelo="cnn",
                descripcion="CNN 3 clases (tests): saludable=0, contaminado=1, desconocido=2.",
                precision_modelo=0.4517,
                estado_modelo="activo",
                observaciones=_json.dumps({
                    "f1_macro": 0.2406,
                    "accuracy": 0.4517,
                    "clases": {"0": "liquen saludable", "1": "liquen contaminado", "2": "desconocido"},
                    "archivo": str(_MODEL_V3),
                }, ensure_ascii=False),
            ))
            db.commit()
except Exception as e:  # pragma: no cover
    import sys

    print(f"[pytest] bootstrap ignorado: {e}", file=sys.stderr)