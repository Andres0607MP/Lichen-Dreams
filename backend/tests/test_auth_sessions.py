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
from models.core import Sesion, Usuario
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


def _auth_user(client):
    email = f"ses+{uuid.uuid4().hex[:8]}@example.com"
    client.post(
        "/auth/register",
        json={"email": email, "password": "Password123!", "name": "User"},
    )
    login = client.post(
        "/auth/login",
        data={"email": email, "password": "Password123!"},
        headers={"User-Agent": "Mozilla/5.0 (Linux; Android 14)"},
    )
    assert login.status_code == 200
    return login.json()


def test_login_crea_sesion_con_metadatos(client):
    tokens = _auth_user(client)

    db = SessionLocal()
    try:
        sesion = db.query(Sesion).order_by(Sesion.id_sesion.desc()).first()
        assert sesion is not None
        assert sesion.estado_sesion == "active"
        assert sesion.dispositivo == "Móvil"
        assert sesion.sistema_operativo == "Android"
        assert sesion.fecha_expiracion is not None
    finally:
        db.close()


def test_logout_refresh_revoca_y_refresh_falla(client):
    tokens = _auth_user(client)
    refresh = tokens["refresh_token"]

    resp = client.post("/auth/logout_refresh", json={"refresh_token": refresh})
    assert resp.status_code == 200

    # El refresh token revocado ya no puede renovar access token
    again = client.post("/auth/refresh", json={"refresh_token": refresh})
    assert again.status_code == 401

    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(
            Usuario.correo == tokens["user"]["correo"]
        ).first()
        active = db.query(Sesion).filter(
            Sesion.id_usuario == user.id_usuario,
            Sesion.estado_sesion == "active",
        ).count()
        assert active == 0
    finally:
        db.close()


def test_logout_revoca_todas_las_sesiones(client):
    tokens = _auth_user(client)
    resp = client.post(
        "/auth/logout",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    assert resp.status_code == 200

    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(
            Usuario.correo == tokens["user"]["correo"]
        ).first()
        active = db.query(Sesion).filter(
            Sesion.id_usuario == user.id_usuario,
            Sesion.estado_sesion == "active",
        ).count()
        assert active == 0
    finally:
        db.close()