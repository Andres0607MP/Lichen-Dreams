"""Pruebas de integración para los endpoints críticos del flujo del 75%."""

import os
from io import BytesIO

# Use a local sqlite DB for tests — must be set BEFORE importing app modules
os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from config.db import get_db
from main import app
from models.base import Base
from models.core import Analisis, Dataset, HistorialActividad, LiquenPedia, ModeloIA, Role, Ubicacion, Usuario
from auth.password_handler import hash_password

from config.db import get_db
from main import app
from models.base import Base
from models.core import Analisis, Dataset, HistorialActividad, LiquenPedia, ModeloIA, Role, Ubicacion, Usuario
from auth.password_handler import hash_password

SQLALCHEMY_TEST_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./test.db")
engine = create_engine(SQLALCHEMY_TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def db():
    # Aislamiento limpio: el esquema lo crea el bootstrap del conftest y este
    # fixture solo asegura filas mínimas (modelo/dataset) de forma idempotente.
    # NO se hace drop_all sobre el motor compartido (destruiría tablas que otros
    # módulos de tests necesitan).
    Base.metadata.create_all(bind=engine)

    db_session = TestingSessionLocal()
    try:
        if not db_session.query(ModeloIA).filter(ModeloIA.id_modelo == 1).first():
            db_session.add(ModeloIA(id_modelo=1, nombre_modelo="modelo_test", version="1.0"))
        if not db_session.query(Dataset).filter(Dataset.id_dataset == 1).first():
            db_session.add(Dataset(id_dataset=1, nombre_dataset="dataset_test", tipo_datos="imagenes"))
        db_session.commit()
    finally:
        db_session.close()

    yield TestingSessionLocal()


@pytest.fixture(scope="function")
def client(db):
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
def test_admin_user(db):
    role = db.query(Role).filter(Role.nombre_rol == "admin").first()
    if role is None:
        role = Role(nombre_rol="admin", descripcion="Administrador", nivel_acceso=10)
        db.add(role)
        db.commit()
        db.refresh(role)

    user = db.query(Usuario).filter(Usuario.correo == "adminqa@example.com").first()
    if user is None:
        user = Usuario(
            nombre="Admin",
            apellido="Test",
            correo="adminqa@example.com",
            contrasena=hash_password("Admin123!"),
            id_rol=role.id_rol,
            estado_cuenta="active",
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


@pytest.fixture(scope="function")
def test_regular_user(db):
    role = db.query(Role).filter(Role.nombre_rol == "user").first()
    if role is None:
        role = Role(nombre_rol="user", descripcion="Usuario", nivel_acceso=1)
        db.add(role)
        db.commit()
        db.refresh(role)

    user = db.query(Usuario).filter(Usuario.correo == "userqa@example.com").first()
    if user is None:
        user = Usuario(
            nombre="User",
            apellido="Test",
            correo="userqa@example.com",
            contrasena=hash_password("User123!"),
            id_rol=role.id_rol,
            estado_cuenta="active",
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


def _login_headers(client, email, password):
    response = client.post(
        "/auth/login",
        data={"email": email, "password": password},
    )
    if response.status_code != 200:
        response = client.post(
            "/auth/register",
            json={
                "email": email,
                "password": password,
                "name": email.split('@')[0],
            },
        )
        assert response.status_code == 201
        response = client.post(
            "/auth/login",
            data={"email": email, "password": password},
        )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _valid_jpeg_bytes():
    return b"\xff\xd8\xff" + b"test-image-content"


def test_registro_usuario_valido(client):
    response = client.post(
        "/auth/register",
        json={
            "email": "nuevo@example.com",
            "password": "Password123!",
            "name": "Nuevo",
            "apellido": "Usuario",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "nuevo@example.com"
    assert data["recovery_code"] is not None


def test_registro_con_email_duplicado(client):
    client.post(
        "/auth/register",
        json={
            "email": "duplicado@example.com",
            "password": "Password123!",
            "name": "Duplicado",
        },
    )
    response = client.post(
        "/auth/register",
        json={
            "email": "duplicado@example.com",
            "password": "Password123!",
            "name": "Duplicado 2",
        },
    )
    assert response.status_code == 400


def test_login_con_credenciales_validas(client):
    client.post(
        "/auth/register",
        json={
            "email": "login@example.com",
            "password": "Password123!",
            "name": "Login",
        },
    )
    response = client.post(
        "/auth/login",
        data={"email": "login@example.com", "password": "Password123!"},
    )
    assert response.status_code == 200
    assert response.json()["access_token"]


def test_login_con_credenciales_invalidas(client):
    response = client.post(
        "/auth/login",
        data={"email": "none@example.com", "password": "wrong"},
    )
    assert response.status_code == 401


def test_subir_imagen_para_analisis(client, test_regular_user):
    headers = _login_headers(client, "userqa@example.com", "User123!")
    response = client.post(
        "/analysis/upload",
        headers=headers,
        files={"file": ("test.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    assert response.status_code == 200
    assert response.json()["url"].startswith("/uploads/")


def test_procesar_analisis_con_ia(client, test_regular_user):
    headers = _login_headers(client, "userqa@example.com", "User123!")
    response = client.post(
        "/analysis/process",
        headers=headers,
        files={"file": ("analysis.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["resultado"]
    assert payload["estado"]
    assert payload["calidad_del_aire"]


def test_obtener_resultado_de_analisis(client, test_regular_user):
    headers = _login_headers(client, "userqa@example.com", "User123!")
    created = client.post(
        "/analysis/process",
        headers=headers,
        files={"file": ("analysis.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    analysis_id = created.json()["id"]
    response = client.get(f"/analysis/results/{analysis_id}", headers=headers)
    assert response.status_code == 200
    assert response.json()["id"] == analysis_id


def test_obtener_estado_de_analisis(client, test_regular_user):
    headers = _login_headers(client, "userqa@example.com", "User123!")
    created = client.post(
        "/analysis/process",
        headers=headers,
        files={"file": ("analysis.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    analysis_id = created.json()["id"]
    response = client.get(f"/analysis/{analysis_id}/status", headers=headers)
    assert response.status_code == 200
    assert response.json()["id"] == analysis_id


def test_eliminar_analisis_propio(client, test_regular_user):
    headers = _login_headers(client, "userqa@example.com", "User123!")
    created = client.post(
        "/analysis/process",
        headers=headers,
        files={"file": ("analysis.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    analysis_id = created.json()["id"]
    response = client.delete(f"/analysis/{analysis_id}", headers=headers)
    assert response.status_code == 204


def test_eliminar_analisis_de_otro_usuario_es_forbidden(client, db, test_regular_user):
    # Usuario NO propietario con rol real 'user' (evaluar 403, no 204 admin).
    user_role = db.query(Role).filter(Role.nombre_rol == "user").first()
    other_user = Usuario(
        nombre="Otro",
        apellido="User",
        correo="other@example.com",
        contrasena=hash_password("Other123!"),
        id_rol=user_role.id_rol if user_role else 2,
        estado_cuenta="active",
    )
    db.add(other_user)
    db.commit()
    db.refresh(other_user)

    owner_headers = _login_headers(client, "userqa@example.com", "User123!")
    created = client.post(
        "/analysis/process",
        headers=owner_headers,
        files={"file": ("analysis.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    analysis_id = created.json()["id"]

    other_headers = _login_headers(client, "other@example.com", "Other123!")
    response = client.delete(f"/analysis/{analysis_id}", headers=other_headers)
    assert response.status_code == 403


def test_dashboard_stats(client, test_regular_user):
    headers = _login_headers(client, "userqa@example.com", "User123!")
    response = client.get("/dashboard/stats", headers=headers)
    assert response.status_code == 200
    payload = response.json()
    assert "analysis_count" in payload
    assert "zone_count" in payload
    assert "ubicaciones_count" in payload
    assert "zonas_ambientales_count" in payload


def test_crear_articulo_liquenpedia_admin(client, db, test_admin_user):
    headers = _login_headers(client, "adminqa@example.com", "Admin123!")
    response = client.post(
        "/liquenpedia",
        headers=headers,
        json={
            "titulo": "Artículo de prueba",
            "contenido": "Contenido de prueba para el artículo",
            "categoria": "Ecología",
            "autor": "Admin",
            "estado_publicacion": "published",
        },
    )
    assert response.status_code == 201
    assert response.json()["titulo"] == "Artículo de prueba"


def test_crear_articulo_con_foto_perfil_autor_publica(client, db, test_admin_user):
    """Verifica que la foto histórica del autor se copie a /uploads/articles/
    y que la imagen sea accesible públicamente sin autenticación."""
    headers = _login_headers(client, "adminqa@example.com", "Admin123!")

    # 1. Subir foto de perfil (privada)
    upload_resp = client.post(
        "/imagenes/upload",
        headers=headers,
        data={"imagen_tipo": "profile"},
        files={"file": ("profile.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    assert upload_resp.status_code == 200, upload_resp.text
    profile_image_url = upload_resp.json()["url"]
    assert "/uploads/profiles/user_" in profile_image_url

    # 2. Asignar foto_perfil al usuario admin
    profile_resp = client.put(
        "/profile",
        headers=headers,
        json={"foto_perfil": profile_image_url},
    )
    assert profile_resp.status_code == 200
    assert profile_resp.json()["foto_perfil"] == profile_image_url

    # 3. Crear artículo (debe copiar foto_perfil_articulo)
    article_resp = client.post(
        "/liquenpedia",
        headers=headers,
        json={
            "titulo": "Artículo con foto",
            "contenido": "Contenido del artículo con foto de autor",
            "categoria": "Ecología",
            "autor": "Admin Test",
            "estado_publicacion": "published",
        },
    )
    assert article_resp.status_code == 201, article_resp.text
    foto_articulo = article_resp.json().get("foto_perfil_articulo")
    assert foto_articulo is not None, "foto_perfil_articulo no fue copiada"
    assert foto_articulo.startswith("/uploads/articles/author_"), \
        f"Expected /uploads/articles/author_* path, got: {foto_articulo}"

    # 4. Verificar que GET /liquenpedia devuelve photo_perfil_articulo
    list_resp = client.get("/liquenpedia", headers=headers)
    assert list_resp.status_code == 200
    articles = list_resp.json()
    found = [a for a in articles if a["foto_perfil_articulo"] == foto_articulo]
    assert len(found) == 1, "foto_perfil_articulo no encontrado en GET /liquenpedia"

    # 5. Acceder a la imagen públicamente (SIN autenticación)
    public_resp = client.get(foto_articulo)
    assert public_resp.status_code == 200, \
        f"Imagen pública no accesible sin auth: {public_resp.status_code}"
    assert public_resp.content == _valid_jpeg_bytes(), \
        "El contenido de la imagen pública no coincide con la original"


def test_listar_articulos_publicos(client, db):
    db.add(LiquenPedia(titulo="Artículo 1", contenido="Contenido 1", categoria="Ecología", estado_publicacion="published"))
    db.add(LiquenPedia(titulo="Artículo 2", contenido="Contenido 2", categoria="General", estado_publicacion="published"))
    db.commit()

    response = client.get("/liquenpedia")
    assert response.status_code == 200
    assert len(response.json()) >= 2


def test_guardar_ubicacion(client):
    response = client.post(
        "/location/save",
        json={
            "latitude": 4.7110,
            "longitude": -74.0721,
            "direccion": "Bogotá",
            "municipio": "Bogotá",
            "departamento": "Cundinamarca",
            "pais": "Colombia",
        },
    )
    assert response.status_code == 200
    assert response.json()["latitud"] == 4.7110


def test_obtener_puntos_del_mapa(client, db, test_regular_user):
    ubicacion = Ubicacion(latitud=4.71, longitud=-74.07, direccion="Bogotá", municipio="Bogotá")
    db.add(ubicacion)
    db.commit()
    db.refresh(ubicacion)

    analysis = Analisis(
        id_usuario=test_regular_user.id_usuario,
        id_modelo=1,
        id_dataset=1,
        id_ubicacion=ubicacion.id_ubicacion,
        resultado_ia="liquen saludable",
        estado_validacion="completed",
        calidad_aire="moderada",
    )
    db.add(analysis)
    db.commit()
    db.refresh(analysis)

    headers = _login_headers(client, "userqa@example.com", "User123!")
    response = client.get("/api/maps/points", headers=headers)
    assert response.status_code == 200
    assert any(point["id"] == analysis.id_analisis for point in response.json())


def test_guardar_historial(client, test_regular_user):
    headers = _login_headers(client, "userqa@example.com", "User123!")
    response = client.post(
        "/history/save",
        headers=headers,
        json={"analysis_id": 1, "location": "Bogotá"},
    )
    assert response.status_code == 201
    assert response.json()["id_usuario"] == test_regular_user.id_usuario


def test_obtener_historial_del_usuario(client, test_regular_user):
    headers = _login_headers(client, "userqa@example.com", "User123!")
    client.post(
        "/history/save",
        headers=headers,
        json={"analysis_id": 1, "location": "Bogotá"},
    )
    response = client.get("/history", headers=headers)
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_actualizar_perfil(client, test_regular_user):
    headers = _login_headers(client, "userqa@example.com", "User123!")
    response = client.put(
        "/profile",
        headers=headers,
        json={"nombre": "Usuario", "apellido": "Actualizado"},
    )
    assert response.status_code == 200
    assert response.json()["nombre"] == "Usuario"


def test_subir_imagen_de_perfil(client, test_regular_user):
    headers = _login_headers(client, "userqa@example.com", "User123!")
    response = client.post(
        "/imagenes/upload",
        headers=headers,
        data={"imagen_tipo": "profile"},
        files={"file": ("profile.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    assert response.status_code == 200
    assert response.json()["url"].startswith("/uploads/profiles/")


def test_propietario_puede_acceder_a_imagen_privada(client, test_regular_user):
    headers = _login_headers(client, "userqa@example.com", "User123!")
    upload = client.post(
        "/imagenes/upload",
        headers=headers,
        data={"imagen_tipo": "analysis"},
        files={"file": ("private.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    assert upload.status_code == 200
    image_path = upload.json()["url"].replace("/uploads/", "")
    response = client.get(f"/imagenes/file/{image_path}", headers=headers)
    assert response.status_code == 200


def test_otro_usuario_no_puede_acceder_a_imagen_privada(client, db, test_regular_user):
    owner_headers = _login_headers(client, "userqa@example.com", "User123!")
    upload = client.post(
        "/imagenes/upload",
        headers=owner_headers,
        data={"imagen_tipo": "analysis"},
        files={"file": ("private.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    assert upload.status_code == 200

    other_user = Usuario(
        nombre="Otra",
        apellido="Persona",
        correo="other2@example.com",
        contrasena=hash_password("Other123!"),
        id_rol=1,
        estado_cuenta="active",
    )
    db.add(other_user)
    db.commit()
    db.refresh(other_user)

    other_headers = _login_headers(client, "other2@example.com", "Other123!")
    image_path = upload.json()["url"].replace("/uploads/", "")
    response = client.get(f"/imagenes/file/{image_path}", headers=other_headers)
    assert response.status_code == 403


def test_imagen_publica_sin_autenticacion(client):
    upload = client.post(
        "/imagenes/upload",
        data={"imagen_tipo": "article"},
        files={"file": ("article.jpg", _valid_jpeg_bytes(), "image/jpeg")},
    )
    assert upload.status_code == 200
    response = client.get(upload.json()["url"])
    assert response.status_code == 200
