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
from models.core import PasswordResetToken, Sesion, Usuario
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


def _google_claims(**overrides):
    claims = {
        "iss": "https://accounts.google.com",
        "sub": f"google-sub-{uuid.uuid4().hex[:10]}",
        "aud": "test-client-id.apps.googleusercontent.com",
        "exp": 2_000_000_000,
        "email": f"guser+{uuid.uuid4().hex[:8]}@gmail.com",
        "email_verified": True,
        "name": "Google User",
        "given_name": "Google",
        "family_name": "User",
        "picture": "https://lh3.googleusercontent.com/photo",
    }
    claims.update(overrides)
    return claims


@pytest.fixture()
def fake_google(monkeypatch):
    state = {"claims": None}

    def set_claims(claims):
        state["claims"] = dict(claims)

    def _verify(token):
        if token == "token-invalido":
            raise ValueError("firma inválida")
        if state["claims"] is None:
            raise ValueError("no claims configurados")
        return dict(state["claims"])

    monkeypatch.setattr(auth_routes, "verify_google_id_token", _verify)

    # Mock download_and_save_profile_image para devolver una ruta local simulada,
    # de modo que los tests no dependan de red descargar imágenes de Google.
    import services.upload_service as upload_service
    from services.upload_service import IMAGE_TYPE_PROFILE
    monkeypatch.setattr(
        upload_service,
        "download_and_save_profile_image",
        lambda url, uid: f"/uploads/profiles/user_{uid}/fake_google_photo.jpg",
    )
    # El módulo auth_routes importó la referencia directamente, hay que parchear allí también.
    monkeypatch.setattr(auth_routes, "download_and_save_profile_image",
                        lambda url, uid: f"/uploads/profiles/user_{uid}/fake_google_photo.jpg")
    return set_claims


@pytest.fixture()
def client():
    Base.metadata.drop_all(bind=ENGINE)
    Base.metadata.create_all(bind=ENGINE)
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _google_login(client, id_token="x", modo="registro"):
    return client.post("/auth/google", json={"id_token": id_token, "modo": modo})


def _valid_jpeg_bytes():
    return b"\xff\xd8\xff" + b"test-image-content"


def test_token_google_invalido_rechazado(client, fake_google):
    resp = _google_login(client, "token-invalido")
    assert resp.status_code == 401


def test_usuario_google_nuevo_se_crea(client, fake_google):
    claims = _google_claims()
    fake_google(claims)

    resp = _google_login(client)
    assert resp.status_code == 200
    data = resp.json()
    assert data["access_token"]
    assert data["refresh_token"]
    assert data["token_type"] == "bearer"
    assert data["user"]["correo"] == claims["email"].lower()
    assert data["user"]["rol"] == "user"
    assert data["user"]["foto_perfil"] == f"/uploads/profiles/user_{data['user']['id_usuario']}/fake_google_photo.jpg"

    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).first()
        assert user is not None
        assert user.proveedor == "google"
        assert user.proveedor_id == claims["sub"]
        assert user.correo == claims["email"].lower()
        assert user.contrasena is None
        assert user.estado_cuenta == "active"
        assert user.nombre == "Google"
        assert user.apellido == "User"
        assert user.foto_perfil == f"/uploads/profiles/user_{user.id_usuario}/fake_google_photo.jpg"
        role = user.rol
        assert role is not None and role.nombre_rol == "user"
        assert user.id_usuario is not None
    finally:
        db.close()


def test_google_existente_actualiza_foto(client, fake_google):
    claims = _google_claims()
    fake_google(claims)
    assert _google_login(client, modo="registro").status_code == 200

    # Segundo inicio de sesión con otra foto de Google: debe actualizarse en BD
    claims2 = dict(claims, picture="https://lh3.googleusercontent.com/nueva-foto")
    fake_google(claims2)
    assert _google_login(client, modo="login").status_code == 200

    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).first()
        assert user.foto_perfil == f"/uploads/profiles/user_{user.id_usuario}/fake_google_photo.jpg"
    finally:
        db.close()


def test_google_no_sobrescribe_foto_personalizada(client, fake_google):
    claims = _google_claims()
    fake_google(claims)
    assert _google_login(client, modo="registro").status_code == 200

    # Simular que el usuario subió una foto personalizada en Lichen Dreams
    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).first()
        user.foto_perfil = "/uploads/profiles/mi_foto.jpg"
        db.commit()
    finally:
        db.close()

    # Google vuelve a iniciar sesión con una foto distinta:
    # NO debe reemplazar la foto personalizada local.
    claims2 = dict(claims, picture="https://lh3.googleusercontent.com/otra")
    fake_google(claims2)
    assert _google_login(client, modo="login").status_code == 200

    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).first()
        assert user.foto_perfil == "/uploads/profiles/mi_foto.jpg"
    finally:
        db.close()


def test_google_sin_foto_no_borra_la_existente(client, fake_google):
    claims = _google_claims()
    fake_google(claims)
    assert _google_login(client, modo="registro").status_code == 200

    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).first()
        user.foto_perfil = "/uploads/profiles/mi_foto.jpg"
        db.commit()
    finally:
        db.close()

    # Google sin picture en un nuevo login: conserva la foto existente
    claims2 = dict(claims)
    claims2.pop("picture", None)
    fake_google(claims2)
    assert _google_login(client, modo="login").status_code == 200

    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).first()
        assert user.foto_perfil == "/uploads/profiles/mi_foto.jpg"
    finally:
        db.close()


def test_google_articulo_con_foto_autor(client, fake_google):
    """Verifica que un usuario Google con foto descargada localmente pueda crear
    un artículo y que foto_perfil_articulo se genere y sea públicamente accesible."""
    from models.core import Role

    # 1. Login como Google y obtener token
    claims = _google_claims()
    fake_google(claims)
    login = _google_login(client, modo="registro")
    assert login.status_code == 200
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Verificar que foto_perfil es una ruta local
    me = client.get("/auth/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["foto_perfil"].startswith("/uploads/profiles/user_"), \
        f"Expected local profile path, got: {me.json()['foto_perfil']}"

    # 3. Subir una imagen de perfil REAL (para que copy_to_article_author_photo funcione)
    upload = client.post(
        "/imagenes/upload",
        headers=headers,
        data={"imagen_tipo": "profile"},
        files={"file": ("profile.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    assert upload.status_code == 200
    local_profile_path = upload.json()["url"]
    assert "/uploads/profiles/" in local_profile_path

    # 4. Actualizar foto_perfil con la ruta local
    client.put("/profile", headers=headers, json={"foto_perfil": local_profile_path})

    # 5. Ascender a admin
    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).first()
        admin_role = db.query(Role).filter(Role.nombre_rol == "admin").first()
        if not admin_role:
            admin_role = Role(nombre_rol="admin", descripcion="Admin", nivel_acceso=10)
            db.add(admin_role)
            db.commit()
            db.refresh(admin_role)
        user.id_rol = admin_role.id_rol
        db.commit()
        db.refresh(user)
    finally:
        db.close()

    # 6. Crear artículo como admin
    article = client.post(
        "/liquenpedia",
        headers=headers,
        json={
            "titulo": "Artículo con foto de autor Google",
            "contenido": "Contenido del artículo de prueba con foto de Google",
            "categoria": "Ecología",
            "autor": "Google User",
            "estado_publicacion": "published",
        },
    )
    assert article.status_code == 201, article.text
    foto_articulo = article.json().get("foto_perfil_articulo")
    assert foto_articulo is not None, "foto_perfil_articulo no fue generada"
    assert foto_articulo.startswith("/uploads/articles/author_"), \
        f"Expected /uploads/articles/author_* path, got: {foto_articulo}"

    # 7. Acceder a la imagen públicamente (SIN autenticación)
    public = client.get(foto_articulo)
    assert public.status_code == 200, f"Image not publicly accessible: {public.status_code}"

    # 8. serve_private_image debe rechazar rutas públicas de artículos (403)
    file_subpath = foto_articulo.replace("/uploads/", "")
    private_attempt = client.get(f"/imagenes/file/{file_subpath}", headers=headers)
    assert private_attempt.status_code == 403, \
        "serve_private_image should reject public article paths"


def test_segundo_login_mismo_sub_no_duplica_usuario(client, fake_google):
    claims = _google_claims()
    fake_google(claims)

    first = _google_login(client, modo="registro")   # crear cuenta
    second = _google_login(client, modo="login")     # iniciar sesión

    assert first.status_code == 200
    assert second.status_code == 200

    db = SessionLocal()
    try:
        count = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).count()
        assert count == 1
        by_email = db.query(Usuario).filter(Usuario.correo == claims["email"].lower()).count()
        assert by_email == 1
    finally:
        db.close()


def test_email_local_existente_no_se_vincula(client, fake_google):
    email = f"occupied+{uuid.uuid4().hex[:8]}@gmail.com"
    reg = client.post(
        "/auth/register",
        json={"email": email, "password": "Password123!", "name": "Local"},
    )
    assert reg.status_code == 201

    claims = _google_claims(email=email)
    fake_google(claims)
    resp = _google_login(client)
    assert resp.status_code == 409

    db = SessionLocal()
    try:
        count = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).count()
        assert count == 0
    finally:
        db.close()


def test_se_crea_sesion_local_y_me_funciona(client, fake_google):
    claims = _google_claims()
    fake_google(claims)
    login = _google_login(client)
    assert login.status_code == 200
    token = login.json()["access_token"]

    me = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["correo"] == claims["email"].lower()

    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).first()
        sesiones = db.query(Sesion).filter(
            Sesion.id_usuario == user.id_usuario
        ).all()
        assert len(sesiones) >= 1
        assert any(s.estado_sesion == "active" for s in sesiones)
    finally:
        db.close()


def test_refresh_y_logout_con_sesion_google(client, fake_google):
    claims = _google_claims()
    fake_google(claims)
    login = _google_login(client)
    tokens = login.json()
    refresh = tokens["refresh_token"]

    ref = client.post("/auth/refresh", json={"refresh_token": refresh})
    assert ref.status_code == 200
    assert "access_token" in ref.json()

    out = client.post("/auth/logout_refresh", json={"refresh_token": refresh})
    assert out.status_code == 200

    ref2 = client.post("/auth/refresh", json={"refresh_token": refresh})
    assert ref2.status_code in (400, 401, 403)


def test_me_devuelve_proveedor_local(client):
    email = f"me_local+{uuid.uuid4().hex[:8]}@example.com"
    reg = client.post(
        "/auth/register",
        json={"email": email, "password": "Password123!", "name": "Local"},
    )
    assert reg.status_code == 201
    login = client.post(
        "/auth/login",
        data={"email": email, "password": "Password123!"},
    )
    assert login.status_code == 200
    me = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {login.json()['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json()["proveedor"] == "local"


def test_me_devuelve_proveedor_google(client, fake_google):
    claims = _google_claims()
    fake_google(claims)
    login = _google_login(client)
    assert login.status_code == 200
    me = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {login.json()['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json()["proveedor"] == "google"


def test_reset_password_rechazado_para_cuenta_google(client, fake_google):
    import hashlib
    from datetime import datetime, timedelta

    claims = _google_claims()
    fake_google(claims)
    assert _google_login(client).status_code == 200

    # Crear un token de reset válido directamente para el usuario de Google
    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).first()
        raw_token = "654321"
        db.add(PasswordResetToken(
            id_usuario=user.id_usuario,
            token_hash=hashlib.sha256(raw_token.encode()).hexdigest(),
            expires_at=datetime.utcnow() + timedelta(minutes=30),
        ))
        db.commit()
    finally:
        db.close()

    resp = client.post(
        "/auth/reset-password",
        json={"token": raw_token, "new_password": "NuevaPass1!"},
    )
    assert resp.status_code == 400
    assert "Google" in resp.json()["detail"]

    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).first()
        assert user.contrasena is None
    finally:
        db.close()


def test_flujo_email_password_sigue_funcionando(client, fake_google):
    email = f"local+{uuid.uuid4().hex[:8]}@example.com"
    reg = client.post(
        "/auth/register",
        json={"email": email, "password": "Password123!", "name": "Local"},
    )
    assert reg.status_code == 201
    code = reg.json()["recovery_code"]

    login = client.post(
        "/auth/login",
        data={"email": email, "password": "Password123!"},
    )
    assert login.status_code == 200

    rec = client.post(
        "/auth/recover-with-code",
        json={"code": code, "new_password": "NuevaPass1!"},
    )
    assert rec.status_code == 200

    login2 = client.post(
        "/auth/login",
        data={"email": email, "password": "NuevaPass1!"},
    )
    assert login2.status_code == 200

def test_login_google_inexistente_rechazado(client, fake_google):
    claims = _google_claims()
    fake_google(claims)

    resp = _google_login(client, modo="login")
    assert resp.status_code == 404
    assert "no est" in resp.json()["detail"]

    db = SessionLocal()
    try:
        assert db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).count() == 0
        assert db.query(Sesion).count() == 0
    finally:
        db.close()


def test_registro_google_inexistente_crea_cuenta(client, fake_google):
    claims = _google_claims()
    fake_google(claims)

    resp = _google_login(client, modo="registro")
    assert resp.status_code == 200
    db = SessionLocal()
    try:
        user = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).first()
        assert user is not None
        assert user.proveedor == "google"
    finally:
        db.close()


def test_registro_google_existente_rechazado(client, fake_google):
    claims = _google_claims()
    fake_google(claims)

    first = _google_login(client, modo="registro")
    assert first.status_code == 200

    second = _google_login(client, modo="registro")
    assert second.status_code == 409
    assert "ya est" in second.json()["detail"]

    db = SessionLocal()
    try:
        count = db.query(Usuario).filter(Usuario.proveedor_id == claims["sub"]).count()
        assert count == 1
    finally:
        db.close()


def test_login_google_existente_autentica(client, fake_google):
    claims = _google_claims()
    fake_google(claims)
    assert _google_login(client, modo="registro").status_code == 200

    login = _google_login(client, modo="login")
    assert login.status_code == 200
    data = login.json()
    assert data["access_token"]
    assert data["refresh_token"]
    assert data["user"]["correo"] == claims["email"].lower()
