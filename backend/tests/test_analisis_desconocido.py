"""Tests de rechazo de análisis 'desconocido' y persistencia de ramas válidas.

Verifica que:
- 'liquen desconocido' / 'desconocido' NO se persistan en BD.
- 'liquen saludable' y 'liquen contaminado' se persistan normalmente.
"""
import os
import shutil
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


def _ubicacion_id(client, headers):
    r = client.post("/location/find-or-create", headers=headers, json={
        "latitude": 4.7110, "longitude": -74.0720, "radius_meters": 15.0,
        "pais": "Colombia"})
    return r.json()["id_ubicacion"]


def _submit_image(client, headers, filename, image_source="camera", id_ubicacion=None):
    """Envía una imagen al endpoint /analysis/process."""
    os.makedirs(BACKEND / "uploads", exist_ok=True)
    src = BACKEND / "ia" / "datasets" / filename
    dest = BACKEND / "uploads" / f"test_{uuid.uuid4().hex[:8]}.jpg"
    shutil.copy(src, dest)
    try:
        with open(dest, "rb") as f:
            data = {"image_source": image_source}
            if id_ubicacion is not None:
                data["id_ubicacion"] = str(id_ubicacion)
            return client.post(
                "/analysis/process",
                headers=headers,
                files={"file": ("t.jpg", f, "image/jpeg")},
                data=data,
            )
    finally:
        if dest.exists():
            dest.unlink()


def test_desconocido_no_crea_analisis(client_desc):
    """Caso 1: desconocido -> rechazo, no se crea Analisis en BD."""
    c, headers, uid = client_desc
    ubicacion = _ubicacion_id(c, headers)
    r = _submit_image(c, headers, "liquenes_contaminados/lc_0113.jpg", id_ubicacion=ubicacion)
    assert r.status_code == 200
    payload = r.json()
    assert payload["rechazado"] is True
    assert payload["mensaje_rechazo"] is not None
    assert "no corresponde a un liquen" in payload["mensaje_rechazo"].lower()
    assert payload["id"] == 0

    from config.db import SessionLocal
    from models.core import Analisis
    with SessionLocal() as db:
        analisis = db.query(Analisis).filter(Analisis.id_usuario == uid).first()
        assert analisis is None, "no debe crearse Analisis para desconocido"


def test_desconocido_no_crea_historial(client_desc):
    """Caso 1: desconocido -> no se crea HistorialActividad."""
    c, headers, uid = client_desc
    ubicacion = _ubicacion_id(c, headers)
    _submit_image(c, headers, "liquenes_contaminados/lc_0113.jpg", id_ubicacion=ubicacion)

    from config.db import SessionLocal
    from models.core import HistorialActividad
    with SessionLocal() as db:
        h = db.query(HistorialActividad).filter(HistorialActividad.id_usuario == uid).first()
        assert h is None, "no debe crearse HistorialActividad para desconocido"


def test_desconocido_no_aparece_en_history(client_desc):
    """Caso 1: desconocido -> no aparece en el endpoint /history."""
    c, headers, uid = client_desc
    ubicacion = _ubicacion_id(c, headers)
    r = _submit_image(c, headers, "liquenes_contaminados/lc_0113.jpg", id_ubicacion=ubicacion)
    assert r.json()["rechazado"] is True

    hs = c.get("/history", headers=headers)
    assert hs.status_code == 200
    ids = [it["id_analisis"] for it in hs.json()]
    assert 0 not in ids
    assert len(ids) == 0, "historial debe estar vacio tras rechazo"


def test_desconocido_no_aparece_en_maps(client_desc):
    """Caso 1: desconocido -> no aparece en /api/maps/points."""
    c, headers, uid = client_desc
    ubicacion = _ubicacion_id(c, headers)
    r = _submit_image(c, headers, "liquenes_contaminados/lc_0113.jpg", id_ubicacion=ubicacion)
    assert r.json()["rechazado"] is True

    mp = c.get("/api/maps/points", headers=headers)
    assert mp.status_code == 200
    assert len(mp.json()) == 0, "mapa debe estar vacio tras rechazo"


def test_saludable_se_persiste(client_desc, monkeypatch):
    """Caso 2: saludable -> se crea Analisis, id > 0, no rechazado."""
    from ia.modelos.lichen_classifier import predict

    def mock_predict(image_path):
        return {
            "categoria": "liquen saludable",
            "confianza": 0.95,
            "nombre_especie": None,
            "nivel_contaminacion": "baja",
            "calidad_aire": "buena",
        }

    monkeypatch.setattr("ia.modelos.lichen_classifier.predict", mock_predict)

    c, headers, uid = client_desc
    ubicacion = _ubicacion_id(c, headers)
    r = _submit_image(c, headers, "liquenes_saludables/ls_0001.jpg", id_ubicacion=ubicacion)
    assert r.status_code == 200
    payload = r.json()
    assert payload["rechazado"] is False
    assert payload["id"] > 0
    assert payload["resultado"] == "liquen saludable"

    from config.db import SessionLocal
    from models.core import Analisis
    with SessionLocal() as db:
        a = db.query(Analisis).filter(Analisis.id_analisis == payload["id"]).first()
        assert a is not None
        assert a.resultado_ia == "liquen saludable"


def test_contaminado_se_persiste(client_desc):
    """Caso 3: contaminado -> se crea Analisis, id > 0, no rechazado."""
    c, headers, uid = client_desc
    ubicacion = _ubicacion_id(c, headers)
    r = _submit_image(c, headers, "liquenes_contaminados/lcp_aug_0019.jpg", id_ubicacion=ubicacion)
    assert r.status_code == 200
    payload = r.json()
    assert payload["rechazado"] is False
    assert payload["id"] > 0
    assert payload["resultado"] == "liquen contaminado"

    from config.db import SessionLocal
    from models.core import Analisis
    with SessionLocal() as db:
        a = db.query(Analisis).filter(Analisis.id_analisis == payload["id"]).first()
        assert a is not None
        assert a.resultado_ia == "liquen contaminado"


def test_rollback_no_deja_analisis_parcial(monkeypatch):
    """Si el commit falla en un flujo persistible, rollback no deja Analisis huérfano."""
    from ia.modelos.lichen_classifier import predict
    from sqlalchemy.orm import Session as SaSession
    from services.analysis_service import AnalysisService
    from config.db import SessionLocal
    from models.core import Analisis

    def mock_predict(image_path):
        return {
            "categoria": "liquen saludable",
            "confianza": 0.95,
            "nombre_especie": None,
            "nivel_contaminacion": "baja",
            "calidad_aire": "buena",
        }

    monkeypatch.setattr("ia.modelos.lichen_classifier.predict", mock_predict)

    dest = BACKEND / "uploads" / "test_rollback.jpg"
    shutil.copy(BACKEND / "ia" / "datasets" / "liquenes_saludables" / "ls_0001.jpg", dest)

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
