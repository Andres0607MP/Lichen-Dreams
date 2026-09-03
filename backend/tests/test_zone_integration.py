"""Tests comprehensivos para la integración de zonas ambientales.

Cubre:
  1. Crear zona (con sync de membresías existentes)
  2. Editar zona (cambio de centro / radio actualiza asociaciones)
  3. Eliminar zona (cascade elimina relaciones, conserva análisis)
  4. Indicadores calculados correctamente vía M2M
  5. /catalog/zones devuelve zonas con indicadores
"""

import os
import sys

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from config.db import get_db
from models.base import Base
from models.core import (
    Analisis,
    AnalisisZonaAmbiental,
    Imagen,
    ModeloIA,
    Role,
    Ubicacion,
    Usuario,
    ZonaAmbiental,
)
from auth.password_handler import hash_password
from services.zone_membership import sync_zone_to_analyses
from services.zones_service import calculate_zone_indicators
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


def _seed_roles(db):
    user_role = db.query(Role).filter(Role.nombre_rol == "user").first()
    if user_role is None:
        user_role = Role(nombre_rol="user", descripcion="Usuario", nivel_acceso=1)
        db.add(user_role)
    admin_role = db.query(Role).filter(Role.nombre_rol == "admin").first()
    if admin_role is None:
        admin_role = Role(nombre_rol="admin", descripcion="Administrador", nivel_acceso=10)
        db.add(admin_role)
    db.commit()
    return user_role, admin_role


def _seed_user_and_model(db, email="user@example.com"):
    user = db.query(Usuario).filter(Usuario.correo == email).first()
    if user is None:
        user_role, _ = _seed_roles(db)
        user = Usuario(
            nombre="User",
            apellido="Test",
            correo=email,
            contrasena=hash_password("Password123!"),
            id_rol=user_role.id_rol,
            estado_cuenta="active",
    )
        db.add(user)
        db.commit()
    modelo = db.query(ModeloIA).filter(ModeloIA.nombre_modelo == "test").first()
    if modelo is None:
        modelo = ModeloIA(nombre_modelo="test", version="1.0")
        db.add(modelo)
        db.commit()
    db.refresh(user)
    db.refresh(modelo)
    return user, modelo


def _create_ubicacion(db, lat, lng):
    ub = Ubicacion(latitud=lat, longitud=lng)
    db.add(ub)
    db.commit()
    return ub


def _create_analisis(db, user, modelo, ubicacion, resultado="liquen saludable", estado="completado"):
    analisis = Analisis(
        id_usuario=user.id_usuario,
        id_modelo=modelo.id_modelo,
        id_ubicacion=ubicacion.id_ubicacion,
        resultado_ia=resultado,
        estado_validacion=estado,
    )
    db.add(analisis)
    db.flush()
    db.add(Imagen(id_analisis=analisis.id_analisis, tipo_captura="campo"))
    db.commit()
    return analisis


def _seed_admin(db):
    _seed_roles(db)
    admin = db.query(Usuario).filter(Usuario.correo == "adminqa@example.com").first()
    if admin is None:
        admin_role = db.query(Role).filter(Role.nombre_rol == "admin").first()
        admin = Usuario(
            nombre="Admin",
            apellido="Test",
            correo="adminqa@example.com",
            contrasena=hash_password("Admin123!"),
            id_rol=admin_role.id_rol,
            estado_cuenta="active",
        )
        db.add(admin)
        db.commit()
    return admin


def _admin_headers(client, db):
    _seed_admin(db)
    return _login_headers(client, "adminqa@example.com", "Admin123!")


def _login_headers(client, email, password):
    login = client.post("/auth/login", data={"email": email, "password": password})
    if login.status_code != 200:
        login = client.post(
            "/auth/register",
            json={"email": email, "password": password, "name": "Test"},
        )
        login = client.post("/auth/login", data={"email": email, "password": password})
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


# ==================== TESTS ====================

def test_crear_zona_asocia_analisis_existentes(client):
    """Crear una zona asocia análisis que ya caen dentro del radio."""
    db = SessionLocal()
    try:
        user, modelo = _seed_user_and_model(db)
        ub = _create_ubicacion(db, 4.7110, -74.0721)
        analysis = _create_analisis(db, user, modelo, ub)
        analysis_id = analysis.id_analisis
    finally:
        db.close()

    admin_headers = _admin_headers(client, SessionLocal())
    resp = client.post(
        "/admin/zones",
        headers=admin_headers,
        json={
            "nombre_zona": "Zona Test",
            "latitud": 4.7110,
            "longitud": -74.0721,
            "radio_metros": 500,
            "descripcion": "Test",
        },
    )
    assert resp.status_code == 201, resp.text
    zona_id = resp.json()["id_zona"]

    db = SessionLocal()
    try:
        mappings = (
            db.query(AnalisisZonaAmbiental)
            .filter(AnalisisZonaAmbiental.id_zona == zona_id)
            .all()
        )
        assert len(mappings) == 1
        assert mappings[0].id_analisis == analysis_id
    finally:
        db.close()


def test_editar_zona_reenlaza_asociaciones_al_cambiar_radio(client):
    """Cambiar el radio de una zona actualiza las asociaciones."""
    db = SessionLocal()
    try:
        user, modelo = _seed_user_and_model(db)
        ub1 = _create_ubicacion(db, 4.7110, -74.0721)
        _create_analisis(db, user, modelo, ub1)
        ub2 = _create_ubicacion(db, 4.729, -74.09)
        _create_analisis(db, user, modelo, ub2)
    finally:
        db.close()

    admin_headers = _admin_headers(client, SessionLocal())
    resp = client.post(
        "/admin/zones",
        headers=admin_headers,
        json={
            "nombre_zona": "Zona Test",
            "latitud": 4.7110,
            "longitud": -74.0721,
            "radio_metros": 500,
            "descripcion": "Test",
        },
    )
    assert resp.status_code == 201, resp.text
    zona_id = resp.json()["id_zona"]

    db = SessionLocal()
    try:
        count_before = (
            db.query(AnalisisZonaAmbiental)
            .filter(AnalisisZonaAmbiental.id_zona == zona_id)
            .count()
        )
        assert count_before == 1
    finally:
        db.close()

    resp = client.put(
        f"/admin/zones/{zona_id}",
        headers=admin_headers,
        json={
            "nombre_zona": "Zona Test",
            "latitud": 4.7110,
            "longitud": -74.0721,
            "radio_metros": 5000,
            "descripcion": "Test ampliado",
        },
    )
    assert resp.status_code == 200, resp.text

    db = SessionLocal()
    try:
        count_after = (
            db.query(AnalisisZonaAmbiental)
            .filter(AnalisisZonaAmbiental.id_zona == zona_id)
            .count()
        )
        assert count_after == 2
    finally:
        db.close()


def test_eliminar_zona_conserva_analisis(client):
    """Al eliminar una zona, las relaciones M2M se borran pero los análisis permanecen."""
    db = SessionLocal()
    try:
        user, modelo = _seed_user_and_model(db)
        ub = _create_ubicacion(db, 4.7110, -74.0721)
        analysis = _create_analisis(db, user, modelo, ub)
        analysis_id = analysis.id_analisis
        zona = ZonaAmbiental(
            nombre_zona="Test",
            latitud=4.7110,
            longitud=-74.0721,
            radio_metros=500,
            id_usuario_creador=user.id_usuario,
        )
        db.add(zona)
        db.commit()
        sync_zone_to_analyses(db, zona.id_zona)
        db.commit()
        db.refresh(zona)

        assert (
            db.query(AnalisisZonaAmbiental)
            .filter(AnalisisZonaAmbiental.id_zona == zona.id_zona)
            .count()
        ) == 1
    finally:
        db.close()

    admin_headers = _admin_headers(client, SessionLocal())
    resp = client.delete(f"/admin/zones/{zona.id_zona}", headers=admin_headers)
    assert resp.status_code == 204, resp.text

    db = SessionLocal()
    try:
        assert (
            db.query(AnalisisZonaAmbiental)
            .filter(AnalisisZonaAmbiental.id_zona == zona.id_zona)
            .count()
        ) == 0
        assert (
            db.query(Analisis)
            .filter(Analisis.id_analisis == analysis_id)
            .count()
        ) == 1
    finally:
        db.close()


def test_indicadores_calculados_via_m2m(client):
    """calculate_zone_indicators usa la tabla M2M, no Haversine en cada GET."""
    db = SessionLocal()
    try:
        user, modelo = _seed_user_and_model(db)
        ub = _create_ubicacion(db, 4.7110, -74.0721)
        _create_analisis(db, user, modelo, ub, resultado="liquen saludable")
        zona = ZonaAmbiental(
            nombre_zona="Zona",
            latitud=4.7110,
            longitud=-74.0721,
            radio_metros=500,
            id_usuario_creador=user.id_usuario,
        )
        db.add(zona)
        db.commit()
        sync_zone_to_analyses(db, zona.id_zona)
        db.commit()

        db.refresh(zona)
        indicators = calculate_zone_indicators(db, zona)
        assert indicators["total_analisis"] == 1
        assert indicators["calidad_aire"] == "buena"
        assert indicators["nivel_riesgo"] == "bajo"
        assert indicators["liquidos_saludables"] == 1
    finally:
        db.close()


def test_catalog_zones_devuelve_indicadores(client):
    """GET /catalog/zones devuelve zonas con indicadores calculados."""
    db = SessionLocal()
    try:
        user, modelo = _seed_user_and_model(db)
        ub = _create_ubicacion(db, 4.7110, -74.0721)
        _create_analisis(db, user, modelo, ub, resultado="liquen saludable")
        zona = ZonaAmbiental(
            nombre_zona="Zona Catalog",
            latitud=4.7110,
            longitud=-74.0721,
            radio_metros=500,
            id_usuario_creador=user.id_usuario,
        )
        db.add(zona)
        db.commit()
        sync_zone_to_analyses(db, zona.id_zona)
        db.commit()
    finally:
        db.close()

    user_headers = _admin_headers(client, SessionLocal())
    resp = client.get("/catalog/zones", headers=user_headers)
    assert resp.status_code == 200, resp.text
    zones = resp.json()
    assert isinstance(zones, list)
    assert len(zones) == 1
    assert zones[0]["nombre_zona"] == "Zona Catalog"
    assert zones[0]["total_analisis"] == 1
    assert zones[0]["calidad_promedio_aire"] == "buena"
    assert zones[0]["nivel_riesgo"] == "bajo"
