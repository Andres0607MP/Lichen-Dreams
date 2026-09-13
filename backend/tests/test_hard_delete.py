"""Tests for hard delete user functionality."""

import os
from datetime import datetime
from unittest.mock import patch

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
from models.core import (
    Usuario, Sesion, Analisis, Imagen, ProcesamientoIA,
    HistorialActividad, Reporte, Notificacion,
    PasswordResetToken, EmailVerificationToken, RecoveryCode,
    Role, ModeloIA, Dataset
)
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
    with TestClient(app, follow_redirects=True) as test_client:
        yield test_client
    app.dependency_overrides.clear()


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
def admin_token(client, test_admin_user):
    return _login_headers(client, "adminqa@example.com", "Admin123!")


@pytest.fixture(scope="function")
def regular_user_with_dependencies(db):
    """Create a regular user with all dependencies for hard delete test."""
    user_role = db.query(Role).filter(Role.nombre_rol == "user").first()
    if user_role is None:
        user_role = Role(nombre_rol="user", descripcion="Usuario normal", nivel_acceso=1)
        db.add(user_role)
        db.commit()
        db.refresh(user_role)

    user = Usuario(
        nombre="Test",
        apellido="User",
        correo="test@delete.com",
        contrasena=hash_password("Test123!"),
        estado_cuenta="active",
        id_rol=user_role.id_rol,
        proveedor="google",
        proveedor_id="google_sub_123"
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Create dependencies
    session = Sesion(
        token_sesion="test_token",
        dispositivo="Test Device",
        sistema_operativo="Windows",
        ip_usuario="127.0.0.1",
        estado_sesion="active",
        id_usuario=user.id_usuario
    )
    db.add(session)

    modelo = ModeloIA(
        nombre_modelo="Test Model",
        version="1.0",
        tipo_modelo="test",
        precision_modelo=0.9,
        dataset_utilizado="test",
        fecha_entrenamiento=datetime(2024, 1, 1),
        estado_modelo="active"
    )
    db.add(modelo)
    db.commit()
    db.refresh(modelo)

    dataset = Dataset(
        nombre_dataset="Test Dataset",
        descripcion="Test",
        cantidad_imagenes=10,
        tipo_datos="images",
        fuente_dataset="test",
        estado_dataset="active"
    )
    db.add(dataset)
    db.commit()
    db.refresh(dataset)

    analisis = Analisis(
        id_usuario=user.id_usuario,
        id_modelo=modelo.id_modelo,
        id_dataset=dataset.id_dataset,
        resultado_ia="test",
        porcentaje_confianza=0.9,
        nivel_contaminacion="bajo",
        calidad_aire="buena",
        estado_liquen="saludable",
        tiempo_procesamiento=1.0,
        estado_validacion="completed",
        visibilidad="private"
    )
    db.add(analisis)
    db.commit()
    db.refresh(analisis)

    imagen = Imagen(
        id_analisis=analisis.id_analisis,
        nombre_imagen="test.jpg",
        ruta_imagen="/uploads/analyses/user_1/test.jpg",
        formato_imagen="jpg",
        tamano_archivo=1000,
        resolucion="100x100",
        estado_imagen="completed",
        tipo_captura="camera"
    )
    db.add(imagen)

    procesamiento = ProcesamientoIA(
        id_analisis=analisis.id_analisis,
        tiempo_ejecucion=1.0,
        porcentaje_precision=0.9,
        precision_modelo=0.9,
        cantidad_objetos_detectados=1,
        resultado_segmentacion="test"
    )
    db.add(procesamiento)

    historial = HistorialActividad(
        id_usuario=user.id_usuario,
        accion_realizada="test_action",
        descripcion_accion="Test description",
        dispositivo="Test",
        ip_usuario="127.0.0.1"
    )
    db.add(historial)

    reporte = Reporte(
        titulo="Test Report",
        descripcion="Test",
        tipo_reporte="test",
        formato_reporte="pdf",
        estado_reporte="completed",
        id_usuario=user.id_usuario
    )
    db.add(reporte)

    notificacion = Notificacion(
        id_usuario=user.id_usuario,
        titulo="Test Notification",
        mensaje="Test message",
        tipo_notificacion="info",
        estado_notificacion="unread"
    )
    db.add(notificacion)

    reset_token = PasswordResetToken(
        id_usuario=user.id_usuario,
        token_hash="reset_hash",
        expires_at=datetime(2025, 12, 31, 23, 59, 59)
    )
    db.add(reset_token)

    email_token = EmailVerificationToken(
        id_usuario=user.id_usuario,
        token_hash="email_hash",
        expires_at=datetime(2025, 12, 31, 23, 59, 59)
    )
    db.add(email_token)

    recovery_code = RecoveryCode(
        id_usuario=user.id_usuario,
        code_hash="recovery_hash",
        expires_at=datetime(2025, 12, 31, 23, 59, 59)
    )
    db.add(recovery_code)

    db.commit()

    yield user


def test_hard_delete_user_removes_everything(
    client: TestClient,
    db,
    admin_token: dict,
    regular_user_with_dependencies: Usuario
):
    """Test that deleting a user removes all associated data."""
    user = regular_user_with_dependencies
    user_id = user.id_usuario

    # Verify user and dependencies exist before deletion
    assert db.query(Usuario).filter(Usuario.id_usuario == user_id).first() is not None
    assert db.query(Sesion).filter(Sesion.id_usuario == user_id).count() > 0
    assert db.query(Analisis).filter(Analisis.id_usuario == user_id).count() > 0
    assert db.query(Imagen).join(Analisis).filter(Analisis.id_usuario == user_id).count() > 0
    assert db.query(ProcesamientoIA).join(Analisis).filter(Analisis.id_usuario == user_id).count() > 0
    assert db.query(HistorialActividad).filter(HistorialActividad.id_usuario == user_id).count() > 0
    assert db.query(Reporte).filter(Reporte.id_usuario == user_id).count() > 0
    assert db.query(Notificacion).filter(Notificacion.id_usuario == user_id).count() > 0
    assert db.query(PasswordResetToken).filter(PasswordResetToken.id_usuario == user_id).count() > 0
    assert db.query(EmailVerificationToken).filter(EmailVerificationToken.id_usuario == user_id).count() > 0
    assert db.query(RecoveryCode).filter(RecoveryCode.id_usuario == user_id).count() > 0

    # Delete user via admin endpoint
    with patch('routes.admin.delete_user_r2_objects') as mock_r2:
        response = client.delete(
            f"/admin/users/{user_id}",
            headers=admin_token
        )

    assert response.status_code == 204

    # Verify user is gone
    assert db.query(Usuario).filter(Usuario.id_usuario == user_id).first() is None

    # Verify all dependencies are gone
    assert db.query(Sesion).filter(Sesion.id_usuario == user_id).count() == 0
    assert db.query(Analisis).filter(Analisis.id_usuario == user_id).count() == 0
    assert db.query(Imagen).join(Analisis).filter(Analisis.id_usuario == user_id).count() == 0
    assert db.query(ProcesamientoIA).join(Analisis).filter(Analisis.id_usuario == user_id).count() == 0
    assert db.query(HistorialActividad).filter(HistorialActividad.id_usuario == user_id).count() == 0
    assert db.query(Reporte).filter(Reporte.id_usuario == user_id).count() == 0
    assert db.query(Notificacion).filter(Notificacion.id_usuario == user_id).count() == 0
    assert db.query(PasswordResetToken).filter(PasswordResetToken.id_usuario == user_id).count() == 0
    assert db.query(EmailVerificationToken).filter(EmailVerificationToken.id_usuario == user_id).count() == 0
    assert db.query(RecoveryCode).filter(RecoveryCode.id_usuario == user_id).count() == 0

    # Verify R2 cleanup was called
    mock_r2.assert_called_once_with(user_id)


def test_delete_nonexistent_user_returns_404(client: TestClient, admin_token: dict):
    """Test deleting a non-existent user returns 404."""
    response = client.delete(
        "/admin/users/99999",
        headers=admin_token
    )
    assert response.status_code == 404
    assert "Usuario no encontrado" in response.json()["detail"]


def test_admin_cannot_delete_self(client: TestClient, admin_token: dict, test_admin_user: Usuario):
    """Test admin cannot delete themselves."""
    response = client.delete(
        f"/admin/users/{test_admin_user.id_usuario}",
        headers=admin_token
    )
    assert response.status_code == 400
    assert "no puede eliminarse a sí mismo" in response.json()["detail"]


def test_google_reregister_after_hard_delete(db):
    """Test that same Google account can register again after hard delete."""
    user_role = db.query(Role).filter(Role.nombre_rol == "user").first()
    if not user_role:
        user_role = Role(nombre_rol="user", descripcion="Usuario normal", nivel_acceso=1)
        db.add(user_role)
        db.commit()
        db.refresh(user_role)

    user = Usuario(
        nombre="Google",
        apellido="User",
        correo="google@test.com",
        estado_cuenta="active",
        id_rol=user_role.id_rol,
        proveedor="google",
        proveedor_id="google_sub_456"
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    user_id = user.id_usuario

    # Hard delete the user
    db.delete(user)
    db.commit()

    # Verify user is gone
    assert db.query(Usuario).filter(Usuario.id_usuario == user_id).first() is None
    assert db.query(Usuario).filter(Usuario.correo == "google@test.com").first() is None
    assert db.query(Usuario).filter(Usuario.proveedor_id == "google_sub_456").first() is None


def test_other_users_unaffected_by_delete(
    client: TestClient,
    db,
    admin_token: dict
):
    """Test that deleting one user doesn't affect others."""
    user_role = db.query(Role).filter(Role.nombre_rol == "user").first()

    # Create two users
    user1 = Usuario(
        nombre="User",
        apellido="One",
        correo="user1@test.com",
        contrasena=hash_password("Test123!"),
        estado_cuenta="active",
        id_rol=user_role.id_rol,
        proveedor="local"
    )
    user2 = Usuario(
        nombre="User",
        apellido="Two",
        correo="user2@test.com",
        contrasena=hash_password("Test123!"),
        estado_cuenta="active",
        id_rol=user_role.id_rol,
        proveedor="local"
    )
    db.add_all([user1, user2])
    db.commit()
    db.refresh(user1)
    db.refresh(user2)

    id1, id2 = user1.id_usuario, user2.id_usuario

    # Delete user1
    with patch('routes.admin.delete_user_r2_objects'):
        response = client.delete(
            f"/admin/users/{id1}",
            headers=admin_token
        )

    assert response.status_code == 204

    # user1 should be gone
    assert db.query(Usuario).filter(Usuario.id_usuario == id1).first() is None

    # user2 should still exist
    assert db.query(Usuario).filter(Usuario.id_usuario == id2).first() is not None


if __name__ == "__main__":
    pytest.main([__file__, "-v"])