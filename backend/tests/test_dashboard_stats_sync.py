import os
import sys

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from models.base import Base
from models.core import Role, Usuario, ModeloIA, Analisis, HistorialActividad
from routes.dashboard import get_dashboard_stats


def _crear_db():
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}
    )
    Base.metadata.create_all(bind=engine)
    return sessionmaker(bind=engine)()


def _crear_usuario(db):
    rol = Role(nombre_rol="user", descripcion="Rol", nivel_acceso=1)
    db.add(rol)
    db.commit()
    usuario = Usuario(
        nombre="Ana",
        apellido="Lopéz",
        correo="ana@test.com",
        contrasena="Secret123!",
        telefono="+573001234567",
        id_rol=rol.id_rol,
    )
    db.add(usuario)
    db.commit()
    db.refresh(usuario)
    return usuario


def _crear_analisis(db, usuario):
    modelo = ModeloIA(nombre_modelo="Modelo prueba", version="1.0.0", descripcion="x")
    db.add(modelo)
    db.commit()
    analisis = Analisis(
        id_usuario=usuario.id_usuario,
        id_modelo=modelo.id_modelo,
        resultado_ia="liquen saludable",
    )
    db.add(analisis)
    db.commit()
    db.refresh(analisis)
    return analisis


def test_analisis_vacios_dan_contador_cero():
    db = _crear_db()
    usuario = _crear_usuario(db)

    stats = get_dashboard_stats(current_user=usuario, db=db)

    assert stats["analysis_count"] == 0


def test_contador_se_alinea_con_el_historial_no_con_analisis_huerfanos():
    db = _crear_db()
    usuario = _crear_usuario(db)
    a1 = _crear_analisis(db, usuario)
    _crear_analisis(db, usuario)

    # La tabla `analisis` tiene 2 registros, pero solo uno fue guardado en
    # el historial (p. ej. un análisis fallido u omitido).
    assert (
        db.query(Analisis)
        .filter(Analisis.id_usuario == usuario.id_usuario)
        .count()
        == 2
    )
    assert (
        db.query(HistorialActividad)
        .filter(HistorialActividad.id_usuario == usuario.id_usuario)
        .count()
        == 0
    )

    db.add(
        HistorialActividad(
            id_usuario=usuario.id_usuario,
            accion_realizada="analisis_guardado",
            descripcion_accion=f"analysis_id={a1.id_analisis}; source=camera",
        )
    )
    db.commit()

    stats = get_dashboard_stats(current_user=usuario, db=db)

    assert stats["analysis_count"] == 1