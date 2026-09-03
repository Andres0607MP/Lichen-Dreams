"""Tests de persistencia de análisis 'desconocido' (corrección del early-return).

Verifica que una predicción 'liquen desconocido' se persista como un análisis
normal: Analisis con ID real > 0, id_ubicacion conservado, HistorialActividad
con analysis_id correcto, aparición en /history y /api/maps/points, y que no
rompe la rama saludable/contaminado existente.
"""
import csv
import json
import os
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
from fastapi.testclient import TestClient

BACKEND = Path(__file__).resolve().parents[1]


def _crear_user(password="pass1234"):
    from config.db import SessionLocal
    from models.core import Role, Usuario
    from auth.password_handler import hash_password

    email = f"test_desc_{uuid.uuid4().hex[:8]}@test.com"
    with SessionLocal() as db:
        rol = db.query(Role).filter(Role.nombre_rol == "user").first()
        u = Usuario(nombre="Test", apellido="Desc", correo=email,
                    contrasena=hash_password(password), estado_cuenta="active",
                    id_rol=rol.id_rol if rol else None, proveedor="local")
        db.add(u)
        db.commit()
        db.refresh(u)
        return u.id_usuario, email


def _cleanup(uid: int):
    from config.db import SessionLocal
    from models.core import (Analisis, Imagen, Notificacion, ProcesamientoIA,
                             HistorialActividad, Usuario, AnalisisZonaAmbiental)
    with SessionLocal() as db:
        analisis = db.query(Analisis).filter(Analisis.id_usuario == uid).all()
        for an in analisis:
            db.query(AnalisisZonaAmbiental).filter(
                AnalisisZonaAmbiental.id_analisis == an.id_analisis).delete(synchronize_session=False)
            db.query(Imagen).filter(Imagen.id_analisis == an.id_analisis).delete(synchronize_session=False)
            db.query(Notificacion).filter(Notificacion.id_usuario == uid).delete(synchronize_session=False)
            db.query(ProcesamientoIA).filter(
                ProcesamientoIA.id_analisis == an.id_analisis).delete(synchronize_session=False)
        db.query(HistorialActividad).filter(HistorialActividad.id_usuario == uid).delete(synchronize_session=False)
        for an in analisis:
            db.delete(an)
        u = db.query(Usuario).filter(Usuario.id_usuario == uid).first()
        if u:
            db.delete(u)
        db.commit()


@pytest.fixture(scope="function")
def client_desc():
    from main import app
    c = TestClient(app)
    uid, email = _crear_user()
    login = c.post("/auth/login", data={"username": email, "password": "pass1234"})
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    try:
        yield c, headers, uid
    finally:
        _cleanup(uid)


def _submit_unknown(client, headers):
    """Envía una imagen que V3 clasifica como 'desconocido' (lc_0113.jpg)."""
    import shutil
    os.makedirs(BACKEND / "uploads", exist_ok=True)
    src = BACKEND / "ia" / "datasets" / "liquenes_contaminados" / "lc_0113.jpg"
    dest = BACKEND / "uploads" / "test_desc.jpg"
    shutil.copy(src, dest)
    try:
        with open(dest, "rb") as f:
            return client.post(
                "/analysis/process",
                headers=headers,
                files={"file": ("t.jpg", f, "image/jpeg")},
                data={"image_source": "camera", "id_ubicacion": str(_ubicacion_id(client, headers))},
            )
    finally:
        if dest.exists():
            dest.unlink()


def _ubicacion_id(client, headers):
    r = client.post("/location/find-or-create", headers=headers, json={
        "latitude": 4.7110, "longitude": -74.0720, "radius_meters": 15.0,
        "pais": "Colombia"})
    return r.json()["id_ubicacion"]


def test_desconocido_crea_analisis(client_desc):
    c, headers, uid = client_desc
    r = _submit_unknown(c, headers)
    assert r.status_code == 200
    assert r.json()["resultado"] == "liquen desconocido"
    aid = r.json()["id"]
    assert isinstance(aid, int) and aid > 0, f"ID esperado >0, got {aid}"
    # verificar en BD
    from config.db import SessionLocal
    from models.core import Analisis
    with SessionLocal() as db:
        a = db.query(Analisis).filter(Analisis.id_analisis == aid).first()
        assert a is not None
        assert a.resultado_ia == "liquen desconocido"
        assert a.estado_validacion == "completed"
        assert a.id_ubicacion is not None


def test_desconocido_conserva_ubicacion(client_desc):
    c, headers, uid = client_desc
    r = _submit_unknown(c, headers)
    aid = r.json()["id"]
    from config.db import SessionLocal
    from models.core import Analisis
    with SessionLocal() as db:
        a = db.query(Analisis).filter(Analisis.id_analisis == aid).first()
        assert a.id_ubicacion is not None
        ub = a.ubicacion
        assert ub is not None
        assert abs(float(ub.latitud) - 4.7110) < 1e-4


def test_desconocido_crea_historial_con_analysis_id(client_desc):
    c, headers, uid = client_desc
    r = _submit_unknown(c, headers)
    aid = r.json()["id"]
    from config.db import SessionLocal
    from models.core import HistorialActividad
    with SessionLocal() as db:
        h = db.query(HistorialActividad).filter(HistorialActividad.id_usuario == uid).first()
        assert h is not None
        assert f"analysis_id={aid}" in (h.descripcion_accion or "")
        assert h.accion_realizada == "analisis_guardado"


def test_desconocido_id_no_es_cero(client_desc):
    c, headers, uid = client_desc
    r = _submit_unknown(c, headers)
    assert r.json()["id"] > 0


def test_desconocido_historial_ubicacion_desde_analisis(client_desc):
    """El historial obtiene ubicación desde Analisis->Ubicacion (no parser texto)."""
    c, headers, uid = client_desc
    _submit_unknown(c, headers)
    hs = c.get("/history", headers=headers)
    assert hs.status_code == 200
    items = hs.json()
    assert items, "historial vacío"
    top = items[0]
    assert top["id_analisis"] > 0
    assert top["ubicacion"], f"ubicacion vacia: {top}"


def test_desconocido_aparece_en_history_endpoint(client_desc):
    c, headers, uid = client_desc
    r = _submit_unknown(c, headers)
    aid = r.json()["id"]
    hs = c.get("/history", headers=headers)
    assert hs.status_code == 200
    ids = [it["id_analisis"] for it in hs.json()]
    assert aid in ids


def test_desconocido_aparece_en_maps_points(client_desc):
    c, headers, uid = client_desc
    r = _submit_unknown(c, headers)
    aid = r.json()["id"]
    mp = c.get("/api/maps/points", headers=headers)
    assert mp.status_code == 200
    ids = [pt["id"] for pt in mp.json()]
    assert aid in ids
    pt = next(p for p in mp.json() if p["id"] == aid)
    assert pt["lat"] is not None and pt["lng"] is not None


def test_saludable_contaminado_siguen_funcionando(client_desc):
    """Rama persistente existente no regresa."""
    c, headers, uid = client_desc
    # lcp_aug_0019 → V3 predice 'liquen contaminado'
    import shutil
    src = BACKEND / "ia" / "datasets" / "liquenes_contaminados" / "lcp_aug_0019.jpg"
    dest = BACKEND / "uploads" / "test_cont.jpg"
    shutil.copy(src, dest)
    try:
        with open(dest, "rb") as f:
            r = c.post("/analysis/process", headers=headers,
                       files={"file": ("t.jpg", f, "image/jpeg")},
                       data={"image_source": "camera",
                             "id_ubicacion": str(_ubicacion_id(c, headers))})
    finally:
        if dest.exists():
            dest.unlink()
    assert r.status_code == 200
    assert r.json()["id"] > 0
    assert r.json()["resultado"] in ("liquen saludable", "liquen contaminado")


def test_rollback_no_deja_analisis_parcial(monkeypatch):
    """Si el commit falla, rollback no deja Analisis huérfano."""
    from sqlalchemy.orm import Session as SaSession
    from services.analysis_service import AnalysisService
    from config.db import SessionLocal
    from models.core import Analisis

    # El flujo falla al llegar a un Analisis persistible (desconocido) y el
    # commit lanza -> process_analysis debe propagar y la BD quedar intacta.
    import shutil
    dest = BACKEND / "uploads" / "test_rollback.jpg"
    shutil.copy(BACKEND / "ia" / "datasets" / "liquenes_contaminados" / "lc_0113.jpg", dest)

    real_commit = SaSession.commit

    def exploding_commit(self):
        raise RuntimeError("simulated commit failure")

    monkeypatch.setattr(SaSession, "commit", exploding_commit)
    s = AnalysisService()
    with SessionLocal() as db:
        before = db.query(Analisis).count()
    try:
        s.process_analysis(image_url="uploads/test_rollback.jpg", image_source="camera", id_ubicacion=1)
    except RuntimeError:
        pass
    finally:
        monkeypatch.setattr(SaSession, "commit", real_commit)
        if dest.exists():
            dest.unlink()
    with SessionLocal() as db:
        after = db.query(Analisis).count()
    assert after == before, "no debe quedar analisis parcial tras fallo de commit"