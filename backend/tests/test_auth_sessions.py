import os
import sys
import uuid
import hashlib
from datetime import datetime, timedelta

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

from auth.jwt_handler import decode_token
from config.db import get_db
from models.base import Base
from models.core import Sesion, Usuario
import routes.auth as auth_routes
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
    with TestClient(app, follow_redirects=True) as c:
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


def _register(client, email):
    response = client.post(
        "/auth/register",
        json={"email": email, "password": "Password123!", "name": "User"},
    )
    assert response.status_code == 201
    return response.json()


def _login(client, email, device_id=None, device_name=None):
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0)"}
    if device_id is not None:
        headers["X-Device-ID"] = device_id
    if device_name is not None:
        headers["X-Device-Name"] = device_name

    return client.post(
        "/auth/login",
        data={"email": email, "password": "Password123!"},
        headers=headers,
    )


def _sessions_for_email(email):
    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.correo == email).first()
        assert user is not None
        return list(
            db.query(Sesion)
            .filter(Sesion.id_usuario == user.id_usuario)
            .order_by(Sesion.fecha_inicio.asc())
            .all()
        )
    finally:
        db.close()


def test_mismo_dispositivo_revoca_sesion_anterior_y_tokens(client):
    email = f"same-device+{uuid.uuid4().hex[:8]}@example.com"
    _register(client, email)

    first = _login(client, email, device_id="device-a", device_name="Phone A")
    second = _login(client, email, device_id="device-a", device_name="Phone A updated")

    assert first.status_code == 200
    assert second.status_code == 200
    sessions = _sessions_for_email(email)
    active = [session for session in sessions if session.estado_sesion == "active"]

    assert len(sessions) == 2
    assert len(active) == 1
    assert sessions[0].estado_sesion == "revoked"
    assert sessions[0].device_id == "device-a"
    assert sessions[0].nombre_dispositivo == "Phone A"
    assert sessions[1].estado_sesion == "active"
    assert sessions[1].device_id == "device-a"
    assert sessions[1].nombre_dispositivo == "Phone A updated"

    first_sid = decode_token(first.json()["refresh_token"])["sid"]
    second_sid = decode_token(second.json()["refresh_token"])["sid"]
    assert first_sid != second_sid
    assert client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {first.json()['access_token']}"},
    ).status_code == 401
    assert client.post(
        "/auth/refresh",
        json={"refresh_token": first.json()["refresh_token"]},
    ).status_code == 401
    assert client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {second.json()['access_token']}"},
    ).status_code == 200


def test_tres_dispositivos_activos_por_usuario(client):
    email = f"three-devices+{uuid.uuid4().hex[:8]}@example.com"
    _register(client, email)

    responses = [
        _login(client, email, device_id=f"device-{index}")
        for index in range(3)
    ]

    assert all(response.status_code == 200 for response in responses)
    active = [
        session for session in _sessions_for_email(email)
        if session.estado_sesion == "active"
    ]
    assert len(active) == 3
    assert {session.device_id for session in active} == {
        "device-0",
        "device-1",
        "device-2",
    }


def test_cuarto_dispositivo_recibe_409_sin_cambiar_sesiones(client):
    email = f"session-limit+{uuid.uuid4().hex[:8]}@example.com"
    _register(client, email)

    for index in range(3):
        assert _login(client, email, device_id=f"device-{index}").status_code == 200

    fourth = _login(client, email, device_id="device-3")

    assert fourth.status_code == 409
    assert fourth.json()["detail"] == "SESSION_LIMIT_REACHED"
    active = [
        session for session in _sessions_for_email(email)
        if session.estado_sesion == "active"
    ]
    assert len(active) == 3
    assert all(session.device_id != "device-3" for session in active)


def test_logout_y_nuevo_login_en_mismo_dispositivo(client):
    email = f"logout-device+{uuid.uuid4().hex[:8]}@example.com"
    _register(client, email)
    first = _login(client, email, device_id="device-a")

    logout = client.post(
        "/auth/logout",
        headers={"Authorization": f"Bearer {first.json()['access_token']}"},
    )
    second = _login(client, email, device_id="device-a")

    assert logout.status_code == 200
    assert second.status_code == 200
    sessions = _sessions_for_email(email)
    active = [session for session in sessions if session.estado_sesion == "active"]
    assert len(sessions) == 2
    assert sessions[0].estado_sesion == "revoked"
    assert len(active) == 1
    assert active[0].device_id == "device-a"


def test_mismo_dispositivo_en_usuarios_distintos(client):
    first_email = f"shared-device-a+{uuid.uuid4().hex[:8]}@example.com"
    second_email = f"shared-device-b+{uuid.uuid4().hex[:8]}@example.com"
    _register(client, first_email)
    _register(client, second_email)

    first = _login(client, first_email, device_id="shared-device")
    second = _login(client, second_email, device_id="shared-device")

    assert first.status_code == 200
    assert second.status_code == 200
    first_sessions = _sessions_for_email(first_email)
    second_sessions = _sessions_for_email(second_email)
    assert len(first_sessions) == 1
    assert len(second_sessions) == 1
    assert first_sessions[0].device_id == second_sessions[0].device_id
    assert first_sessions[0].id_usuario != second_sessions[0].id_usuario


def test_google_login_aplica_deduplicacion_por_dispositivo(client, monkeypatch):
    claims = {
        "sub": f"google-{uuid.uuid4().hex}",
        "email": f"google-device+{uuid.uuid4().hex[:8]}@gmail.com",
        "email_verified": True,
        "name": "Google Device User",
        "given_name": "Google",
        "family_name": "User",
        "picture": None,
    }
    monkeypatch.setattr(auth_routes, "verify_google_id_token", lambda token: claims)

    first = client.post(
        "/auth/google",
        json={"id_token": "google-token", "modo": "registro"},
        headers={
            "X-Device-ID": "google-device",
            "X-Device-Name": "Google Phone",
        },
    )
    second = client.post(
        "/auth/google",
        json={"id_token": "google-token", "modo": "login"},
        headers={
            "X-Device-ID": "google-device",
            "X-Device-Name": "Google Phone updated",
        },
    )

    assert first.status_code == 200
    assert second.status_code == 200
    sessions = _sessions_for_email(claims["email"])
    active = [session for session in sessions if session.estado_sesion == "active"]
    assert len(sessions) == 2
    assert len(active) == 1
    assert sessions[0].estado_sesion == "revoked"
    assert sessions[1].device_id == "google-device"
    assert sessions[1].nombre_dispositivo == "Google Phone updated"


def test_login_revoca_sesion_expirada_antes_del_limite(client):
    email = f"expired-device+{uuid.uuid4().hex[:8]}@example.com"
    _register(client, email)
    first = _login(client, email, device_id="expired-device")

    db = SessionLocal()
    try:
        session = db.query(Sesion).filter(
            Sesion.token_sesion_hash == hashlib.sha256(
                decode_token(first.json()["refresh_token"])["sid"].encode()
            ).hexdigest()
        ).first()
        session.fecha_expiracion = datetime.utcnow() - timedelta(seconds=1)
        db.commit()
    finally:
        db.close()

    second = _login(client, email, device_id="expired-device")

    assert second.status_code == 200
    sessions = _sessions_for_email(email)
    active = [session for session in sessions if session.estado_sesion == "active"]
    assert len(sessions) == 2
    assert sessions[0].estado_sesion == "revoked"
    assert len(active) == 1
    assert active[0].fecha_expiracion > datetime.utcnow()


def test_sesion_revocada_manualmente_libera_plaza(client):
    email = f"manual-revoke+{uuid.uuid4().hex[:8]}@example.com"
    _register(client, email)

    for index in range(3):
        assert _login(client, email, device_id=f"device-{index}").status_code == 200

    db = SessionLocal()
    try:
        session = db.query(Sesion).filter(Sesion.device_id == "device-0").one()
        session.estado_sesion = "revoked"
        db.commit()
    finally:
        db.close()

    fourth = _login(client, email, device_id="device-3")
    assert fourth.status_code == 200
    active = [
        session for session in _sessions_for_email(email)
        if session.estado_sesion == "active"
    ]
    assert len(active) == 3
    assert {session.device_id for session in active} == {
        "device-1",
        "device-2",
        "device-3",
    }


def test_migracion_revoca_legacy_sin_inventar_device_id(monkeypatch):
    import importlib.util
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    from sqlalchemy import Column, ForeignKey, Integer, MetaData, String, Table, inspect, insert, text

    migration_path = os.path.join(
        os.path.dirname(__file__),
        "..",
        "alembic",
        "versions",
        "b3c4d5e6f7a8_add_device_tracking_to_sesiones.py",
    )
    spec = importlib.util.spec_from_file_location(
        "session_device_migration",
        migration_path,
    )
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    metadata = MetaData()
    Table("usuarios", metadata, Column("id_usuario", Integer, primary_key=True))
    Table(
        "sesiones",
        metadata,
        Column("id_sesion", Integer, primary_key=True),
        Column("token_sesion_hash", String(64), nullable=False),
        Column("estado_sesion", String(50)),
        Column("id_usuario", Integer, ForeignKey("usuarios.id_usuario")),
    )
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    metadata.create_all(engine)
    legacy_hash = hashlib.sha256(b"legacy-sid").hexdigest()

    with engine.begin() as connection:
        connection.execute(
            insert(metadata.tables["sesiones"]).values(
                id_sesion=1,
                token_sesion_hash=legacy_hash,
                estado_sesion="active",
                id_usuario=1,
            )
        )
        monkeypatch.setattr(
            migration,
            "op",
            Operations(MigrationContext.configure(connection)),
        )
        migration.upgrade()

    with engine.connect() as connection:
        legacy = connection.execute(
            text(
                "SELECT estado_sesion, device_id, nombre_dispositivo "
                "FROM sesiones WHERE id_sesion = :id_sesion"
            ),
            {"id_sesion": 1},
        ).mappings().one()
        assert legacy["estado_sesion"] == "revoked"
        assert legacy["device_id"] is None
        assert legacy["nombre_dispositivo"] is None

    with engine.begin() as connection:
        monkeypatch.setattr(
            migration,
            "op",
            Operations(MigrationContext.configure(connection)),
        )
        migration.downgrade()

    inspected = inspect(engine)
    assert "device_id" not in {column["name"] for column in inspected.get_columns("sesiones")}
    assert "nombre_dispositivo" not in {
        column["name"] for column in inspected.get_columns("sesiones")
    }
    assert "idx_sesion_user_device" not in {
        index["name"] for index in inspected.get_indexes("sesiones")
    }


def test_get_sessions_incluye_metadatos_de_dispositivo(client):
    email = f"sessions-metadata+{uuid.uuid4().hex[:8]}@example.com"
    _register(client, email)
    tokens = _login(
        client,
        email,
        device_id="metadata-device",
        device_name="Metal Phone",
    )

    response = client.get(
        "/auth/sessions",
        headers={"Authorization": f"Bearer {tokens.json()['access_token']}"},
    )

    assert response.status_code == 200
    session = response.json()[0]
    assert session["device_id"] == "metadata-device"
    assert session["nombre_dispositivo"] == "Metal Phone"

    db = SessionLocal()
    try:
        legacy = db.query(Sesion).filter(
            Sesion.device_id == "metadata-device"
        ).one()
        legacy.device_id = None
        legacy.nombre_dispositivo = None
        db.commit()
    finally:
        db.close()

    response = client.get(
        "/auth/sessions",
        headers={"Authorization": f"Bearer {tokens.json()['access_token']}"},
    )
    assert response.status_code == 200
    session = response.json()[0]
    assert session["device_id"] is None
    assert session["nombre_dispositivo"] is None


def test_fcm_token_se_registra_en_la_sesion_autenticada(client):
    tokens = _auth_user(client)
    email = tokens["user"]["correo"]
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    response = client.post(
        "/auth/fcm-token",
        json={"fcm_token": "fcm-token-1"},
        headers=headers,
    )

    assert response.status_code == 200
    session = _sessions_for_email(email)[0]
    assert session.fcm_token == "fcm-token-1"


def test_fcm_token_requiere_autenticacion(client):
    response = client.post(
        "/auth/fcm-token",
        json={"fcm_token": "fcm-token-1"},
    )

    assert response.status_code == 401


def test_fcm_token_reemplaza_el_token_de_la_misma_sesion(client):
    tokens = _auth_user(client)
    email = tokens["user"]["correo"]
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    first = client.post(
        "/auth/fcm-token",
        json={"fcm_token": "fcm-token-1"},
        headers=headers,
    )
    second = client.post(
        "/auth/fcm-token",
        json={"fcm_token": "fcm-token-2"},
        headers=headers,
    )

    assert first.status_code == 200
    assert second.status_code == 200
    sessions = _sessions_for_email(email)
    assert len(sessions) == 1
    assert sessions[0].fcm_token == "fcm-token-2"


@pytest.mark.parametrize(
    "fcm_token",
    [
        "",
        "   ",
        "token with spaces",
        "x" * 4097,
        "fake_token",
    ],
)
def test_fcm_token_rechaza_valores_invalidos(client, fcm_token):
    tokens = _auth_user(client)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    response = client.post(
        "/auth/fcm-token",
        json={"fcm_token": fcm_token},
        headers=headers,
    )

    assert response.status_code == 422


def test_fcm_token_no_permite_asociarlo_a_otra_sesion(client):
    first_tokens = _auth_user(client)
    second_tokens = _auth_user(client)
    first_email = first_tokens["user"]["correo"]
    second_email = second_tokens["user"]["correo"]
    first_session = _sessions_for_email(first_email)[0]
    second_session = _sessions_for_email(second_email)[0]
    headers = {"Authorization": f"Bearer {first_tokens['access_token']}"}

    response = client.post(
        "/auth/fcm-token",
        json={
            "fcm_token": "fcm-token-owner",
            "id_usuario": second_session.id_usuario,
            "id_sesion": second_session.id_sesion,
        },
        headers=headers,
    )

    assert response.status_code == 200
    assert _sessions_for_email(first_email)[0].fcm_token == "fcm-token-owner"
    assert _sessions_for_email(second_email)[0].fcm_token is None
    assert len(_sessions_for_email(first_email)) == 1
    assert len(_sessions_for_email(second_email)) == 1
