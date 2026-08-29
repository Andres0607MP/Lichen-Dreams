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

import hashlib
import re
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from config.db import get_db
from models.base import Base
from models.core import RecoveryCode, Sesion, Usuario
from main import app

# Motor aislado (en memoria) para que este módulo no dependa del motor global
# de config.database (que puede apuntar a MySQL cuando otro test lo importó primero).
ENGINE = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
SessionLocal = sessionmaker(bind=ENGINE)

RECOVERY_CODE_RE = re.compile(r"^LCHN-[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$")


def override_get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _normalize(code: str) -> str:
    cleaned = code.strip().upper().replace(' ', '').replace('-', '')
    return f"{cleaned[0:4]}-{cleaned[4:8]}-{cleaned[8:12]}-{cleaned[12:16]}"


def _hash(code: str) -> str:
    return hashlib.sha256(_normalize(code).encode()).hexdigest()


@pytest.fixture()
def client():
    Base.metadata.drop_all(bind=ENGINE)
    Base.metadata.create_all(bind=ENGINE)
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _register(client, password="Password123!"):
    email = f"recovery+{uuid.uuid4().hex[:8]}@example.com"
    reg = client.post(
        "/auth/register",
        json={"email": email, "password": password, "name": "Recovery Tester"},
    )
    assert reg.status_code == 201
    return reg.json()


def _login(client, email, password):
    return client.post(
        "/auth/login",
        data={"email": email, "password": password},
    )


def test_registro_crea_cuenta_activa_y_genera_codigo(client):
    data = _register(client)

    assert data["requires_email_verification"] is False
    code = data["recovery_code"]
    assert code is not None
    assert RECOVERY_CODE_RE.match(code), f"Formato inesperado: {code}"

    email = data["email"]
    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.correo == email).first()
        assert user is not None
        assert user.estado_cuenta == "active"
        assert user.proveedor == "local"
    finally:
        db.close()


def test_login_funciona_despues_del_registro(client):
    data = _register(client)
    login = _login(client, data["email"], "Password123!")
    assert login.status_code == 200
    assert "access_token" in login.json()
    assert "refresh_token" in login.json()


def test_codigo_incorrecto_rechazado(client):
    data = _register(client)
    resp = client.post(
        "/auth/recover-with-code",
        json={"code": "LCHN-AAAA-BBBB-CCCC", "new_password": "NuevaPass1!"},
    )
    assert resp.status_code == 400
    assert "inválido" in resp.json()["detail"] or "utilizado" in resp.json()["detail"]


def test_codigo_funciona_una_sola_vez(client):
    data = _register(client)
    code = data["recovery_code"]

    first = client.post(
        "/auth/recover-with-code",
        json={"code": code, "new_password": "NuevaPass1!"},
    )
    assert first.status_code == 200

    # Segunda vez: el código ya está utilizado y debe ser rechazado
    second = client.post(
        "/auth/recover-with-code",
        json={"code": code, "new_password": "OtraPass1!"},
    )
    assert second.status_code == 400


def test_recuperacion_cambia_contrasena(client):
    data = _register(client)
    code = data["recovery_code"]

    resp = client.post(
        "/auth/recover-with-code",
        json={"code": code, "new_password": "NuevaPass1!"},
    )
    assert resp.status_code == 200
    assert "access_token" not in resp.json()  # no auto login

    # Login con la contraseña antigua falla
    old_login = _login(client, data["email"], "Password123!")
    assert old_login.status_code == 401

    # Login con la nueva contraseña funciona
    new_login = _login(client, data["email"], "NuevaPass1!")
    assert new_login.status_code == 200


def test_recuperacion_revoca_sesiones_existentes(client):
    data = _register(client)
    code = data["recovery_code"]

    login = _login(client, data["email"], "Password123!")
    old_token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {old_token}"}

    # Sesión activa antes de la recuperación
    me = client.get("/auth/me", headers=headers)
    assert me.status_code == 200

    resp = client.post(
        "/auth/recover-with-code",
        json={"code": code, "new_password": "NuevaPass1!"},
    )
    assert resp.status_code == 200

    # La sesión previa quedó revocada
    me_after = client.get("/auth/me", headers=headers)
    assert me_after.status_code in (401, 403)

    # No quedan sesiones activas en BD
    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.correo == data["email"]).first()
        active = db.query(Sesion).filter(
            Sesion.id_usuario == user.id_usuario, Sesion.estado_sesion == "active"
        ).count()
        assert active == 0
    finally:
        db.close()


def test_regenerar_codigo_invalida_anterior(client):
    data = _register(client)
    old_code = data["recovery_code"]

    login = _login(client, data["email"], "Password123!")
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    resp = client.post("/auth/recovery-code/regenerate", headers=headers)
    assert resp.status_code == 200
    new_code = resp.json()["recovery_code"]
    assert RECOVERY_CODE_RE.match(new_code)
    assert new_code != old_code

    # El código anterior ya no sirve
    old_use = client.post(
        "/auth/recover-with-code",
        json={"code": old_code, "new_password": "NuevaPass1!"},
    )
    assert old_use.status_code == 400

    # El nuevo código sí funciona
    new_use = client.post(
        "/auth/recover-with-code",
        json={"code": new_code, "new_password": "NuevaPass1!"},
    )
    assert new_use.status_code == 200


def test_regenerar_codigo_requiere_autenticacion(client):
    resp = client.post("/auth/recovery-code/regenerate")
    assert resp.status_code in (401, 403)


def test_codigo_nunca_se_almacena_en_texto_plano(client):
    data = _register(client)
    raw_code = data["recovery_code"]

    login = _login(client, data["email"], "Password123!")
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    regen = client.post("/auth/recovery-code/regenerate", headers=headers)
    new_code = regen.json()["recovery_code"]

    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.correo == data["email"]).first()
        records = db.query(RecoveryCode).filter(
            RecoveryCode.id_usuario == user.id_usuario
        ).all()
        assert len(records) == 2  # el del registro + el regenerado

        stored_values = set()
        for r in records:
            stored_values.add(r.code_hash)
            # El hash debe ser un SHA-256 (64 hex), nunca el código en claro
            assert len(r.code_hash) == 64
            assert raw_code not in r.code_hash
            assert new_code not in r.code_hash

        assert _hash(raw_code) in stored_values
        assert _hash(new_code) in stored_values
    finally:
        db.close()


def test_flujo_recuperacion_por_email_sigue_funcionando(client):
    email = f"emailflow+{uuid.uuid4().hex[:8]}@example.com"
    reg = client.post(
        "/auth/register",
        json={"email": email, "password": "Password123!", "name": "Email Flow"},
    )
    assert reg.status_code == 201

    forgot = client.post("/auth/forgot-password", json={"email": email})
    assert forgot.status_code == 200
    assert "Si el correo está registrado" in forgot.json()["message"]

    # Email sin registrar: mismo mensaje genérico (anti-enumeración)
    forgot_unknown = client.post(
        "/auth/forgot-password",
        json={"email": f"nobody+{uuid.uuid4().hex[:8]}@example.com"},
    )
    assert forgot_unknown.status_code == 200
    assert forgot_unknown.json()["message"] == forgot.json()["message"]

    # Código incorrecto sigue siendo rechazado por reset-password
    reset = client.post(
        "/auth/reset-password",
        json={"token": "000000", "new_password": "NuevaPass1!"},
    )
    assert reset.status_code == 400


def test_jwt_sesiones_siguen_funcionando(client):
    data = _register(client)
    login = _login(client, data["email"], "Password123!")
    tokens = login.json()
    access = tokens["access_token"]
    refresh = tokens["refresh_token"]

    headers = {"Authorization": f"Bearer {access}"}
    me = client.get("/auth/me", headers=headers)
    assert me.status_code == 200

    refreshed = client.post("/auth/refresh", json={"refresh_token": refresh})
    assert refreshed.status_code == 200
    assert "access_token" in refreshed.json()

    sessions = client.get("/auth/sessions", headers=headers)
    assert sessions.status_code == 200
    assert isinstance(sessions.json(), list)

    out = client.post("/auth/logout_refresh", json={"refresh_token": refresh})
    assert out.status_code == 200

    me_after_logout = client.get("/auth/me", headers=headers)
    assert me_after_logout.status_code in (401, 403)


def test_recuperacion_con_espacios_y_guiones_normalizados(client):
    data = _register(client)
    code = data["recovery_code"]
    # El usuario escribe el código en minúsculas y con espacios
    messy = code.lower().replace("-", "   ")

    resp = client.post(
        "/auth/recover-with-code",
        json={"code": messy, "new_password": "NuevaPass1!"},
    )
    assert resp.status_code == 200

    # Ya no se puede reutilizar
    again = client.post(
        "/auth/recover-with-code",
        json={"code": code, "new_password": "OtraPass1!"},
    )
    assert again.status_code == 400


def test_registro_duplicado_rechazado(client):
    data = _register(client)
    dup = client.post(
        "/auth/register",
        json={"email": data["email"], "password": "Password123!", "name": "Dupe"},
    )
    assert dup.status_code == 400