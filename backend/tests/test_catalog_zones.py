import os
import sys
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

sys.path.append(
    os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            ".."
        )
    )
)

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from config.db import get_db
from models.base import Base
from models.core import (
    Analisis,
    EspecieLiquen,
    HistorialActividad,
    Imagen,
    ModeloIA,
    Ubicacion,
    Usuario,
    ZonaAmbiental,
)
from main import app

ENGINE = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
SessionLocal = sessionmaker(bind=ENGINE)


def override_get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture()
def client():
    Base.metadata.drop_all(bind=ENGINE)
    Base.metadata.create_all(bind=ENGINE)
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _register_user(client):
    email = f"cat+{uuid.uuid4().hex[:8]}@example.com"
    reg = client.post(
        "/auth/register",
        json={"email": email, "password": "Password123!", "name": "User"},
    )
    assert reg.status_code == 201
    login = client.post(
        "/auth/login",
        data={"email": email, "password": "Password123!"},
    )
    assert login.status_code == 200
    return email, {"Authorization": f"Bearer {login.json()['access_token']}"}


def _seed_species_and_zone(db, lat=4.711, lng=-74.07):
    species = EspecieLiquen(
        nombre_cientifico="Xanthoria parietina",
        nombre_comun="Líquen amarillo",
        habitat="Corteza de árboles",
        tipo_crecimiento="crustoso",
    )
    db.add(species)
    db.flush()

    zona = ZonaAmbiental(
        nombre_zona="Parque Central",
        latitud=lat,
        longitud=lng,
        radio_metros=500.0,
        descripcion="Zona de prueba",
    )
    db.add(zona)
    db.commit()
    return species.id_especie, zona.id_zona


def _seed_analysis_for_user(db, email, lat, lng, resultado="liquen saludable"):
    user = db.query(Usuario).filter(Usuario.correo == email).first()
    modelo = ModeloIA(nombre_modelo="test", version="1.0")
    db.add(modelo)
    db.flush()
    ubicacion = Ubicacion(latitud=lat, longitud=lng)
    db.add(ubicacion)
    db.flush()
    analisis = Analisis(
        id_usuario=user.id_usuario,
        id_modelo=modelo.id_modelo,
        id_ubicacion=ubicacion.id_ubicacion,
        resultado_ia=resultado,
        estado_validacion="completado",
    )
    db.add(analisis)
    db.flush()
    db.add(Imagen(id_analisis=analisis.id_analisis, tipo_captura="campo"))
    db.add(HistorialActividad(id_usuario=user.id_usuario, accion_realizada="análisis"))
    db.commit()
    return analisis.id_analisis


def test_catalog_species_legible_por_usuario(client):
    db = SessionLocal()
    try:
        _seed_species_and_zone(db)
    finally:
        db.close()

    _, headers = _register_user(client)
    resp = client.get("/catalog/species", headers=headers)
    assert resp.status_code == 200
    species = resp.json()
    assert isinstance(species, list)
    assert any(s["nombre_cientifico"] == "Xanthoria parietina" for s in species)
    assert "nombre_comun" in species[0]


def test_guardar_y_quitar_especie_del_analisis(client):
    db = SessionLocal()
    try:
        species_id, _ = _seed_species_and_zone(db)
    finally:
        db.close()

    email, headers = _register_user(client)
    db = SessionLocal()
    try:
        analysis_id = _seed_analysis_for_user(db, email, 4.711, -74.07)
    finally:
        db.close()

    # Guardar especie
    resp = client.put(
        f"/analysis/{analysis_id}/species",
        headers=headers,
        json={"id_especie": species_id},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["id_especie"] == species_id
    assert resp.json()["nombre_cientifico"] == "Xanthoria parietina"

    db = SessionLocal()
    try:
        assert db.get(Analisis, analysis_id).id_especie == species_id
    finally:
        db.close()

    # Omitir (null)
    resp = client.put(
        f"/analysis/{analysis_id}/species",
        headers=headers,
        json={"id_especie": None},
    )
    assert resp.status_code == 200
    assert resp.json()["id_especie"] is None

    db = SessionLocal()
    try:
        assert db.get(Analisis, analysis_id).id_especie is None
    finally:
        db.close()


def test_zona_sin_datos_muestra_sin_datos(client):
    db = SessionLocal()
    try:
        _seed_species_and_zone(db)
    finally:
        db.close()

    _, headers = _register_user(client)
    resp = client.get("/catalog/zones", headers=headers)
    assert resp.status_code == 200
    zone = resp.json()[0]
    assert zone["calidad_promedio_aire"] == "sin_datos"
    assert zone["nivel_riesgo"] == "sin_datos"
    assert zone["total_analisis"] == 0


def test_zona_con_analisis_calcula_indicadores(client):
    db = SessionLocal()
    try:
        _seed_species_and_zone(db)  # centro 4.711, -74.07, radio 500 m
    finally:
        db.close()

    email, headers = _register_user(client)
    db = SessionLocal()
    try:
        _seed_analysis_for_user(db, email, 4.7111, -74.0710)  # ~ dentro del radio
        # Sincronizar membresía M2M (el análisis queda asociado a la zona por proximidad)
        from services.zone_membership import sync_zone_to_analyses
        zona = db.query(ZonaAmbiental).first()
        sync_zone_to_analyses(db, zona.id_zona)
        db.commit()
    finally:
        db.close()

    resp = client.get("/catalog/zones", headers=headers)
    assert resp.status_code == 200
    zone = resp.json()[0]
    assert zone["total_analisis"] == 1
    assert zone["calidad_promedio_aire"] == "buena"
    assert zone["nivel_riesgo"] == "bajo"
    assert zone["saludables"] == 1


def test_zona_ignora_analisis_fuera_de_radio(client):
    db = SessionLocal()
    try:
        _seed_species_and_zone(db)  # centro 4.711, -74.07
    finally:
        db.close()

    email, headers = _register_user(client)
    db = SessionLocal()
    try:
        _seed_analysis_for_user(db, email, 4.9000, -74.0700)  # ~20 km de distancia
        # Sincronizar membresía M2M: el análisis queda fuera del radio → no se asocia
        from services.zone_membership import sync_zone_to_analyses
        zona = db.query(ZonaAmbiental).first()
        sync_zone_to_analyses(db, zona.id_zona)
        db.commit()
    finally:
        db.close()

    resp = client.get("/catalog/zones", headers=headers)
    zone = resp.json()[0]
    assert zone["total_analisis"] == 0
    assert zone["calidad_promedio_aire"] == "sin_datos"