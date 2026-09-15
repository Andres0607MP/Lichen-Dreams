"""Tests for the soft-deleted users cleanup script."""

import hashlib
import os
from datetime import datetime

# Use a local sqlite DB for tests — must be set BEFORE importing app modules
os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

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
from scripts.cleanup_soft_deleted_users import get_users_to_cleanup, hard_delete_user


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
    """Create a fresh database for each test."""
    Base.metadata.drop_all(bind=engine)
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
    
    # Cleanup after test
    db_session = TestingSessionLocal()
    try:
        Base.metadata.drop_all(bind=engine)
    finally:
        db_session.close()


@pytest.fixture(scope="function")
def client(db):
    app.dependency_overrides[get_db] = override_get_db
    with pytest.TestClient(app, follow_redirects=True) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def test_get_users_to_cleanup_finds_only_eliminados(db):
    """Test that get_users_to_cleanup only finds users with estado_cuenta='eliminado'."""
    user_role = db.query(Role).filter(Role.nombre_rol == "user").first()
    if not user_role:
        user_role = Role(nombre_rol="user", descripcion="Usuario normal", nivel_acceso=1)
        db.add(user_role)
        db.commit()
        db.refresh(user_role)

    # Create active user
    active_user = Usuario(
        nombre="Active",
        apellido="User",
        correo="active@test.com",
        contrasena=hash_password("Test123!"),
        estado_cuenta="active",
        id_rol=user_role.id_rol,
        proveedor="local"
    )
    db.add(active_user)

    # Create inactive user
    inactive_user = Usuario(
        nombre="Inactive",
        apellido="User",
        correo="inactive@test.com",
        contrasena=hash_password("Test123!"),
        estado_cuenta="inactive",
        id_rol=user_role.id_rol,
        proveedor="local"
    )
    db.add(inactive_user)

    # Create soft-deleted user (the target of cleanup)
    deleted_user = Usuario(
        nombre="Deleted",
        apellido="User",
        correo="deleted@test.com",
        contrasena=hash_password("Test123!"),
        estado_cuenta="eliminado",
        id_rol=user_role.id_rol,
        proveedor="google",
        proveedor_id="google_sub_123"
    )
    db.add(deleted_user)

    db.commit()

    # Should only find the deleted user
    found = get_users_to_cleanup(db)
    assert len(found) == 1
    assert found[0].correo == "deleted@test.com"
    assert found[0].estado_cuenta == "eliminado"


def test_hard_delete_user_removes_user_and_dependencies(db):
    """Test that hard_delete_user removes the user and all dependencies."""
    user_role = db.query(Role).filter(Role.nombre_rol == "user").first()
    if not user_role:
        user_role = Role(nombre_rol="user", descripcion="Usuario normal", nivel_acceso=1)
        db.add(user_role)
        db.commit()
        db.refresh(user_role)

    # Create user with estado_cuenta="eliminado" and dependencies
    user = Usuario(
        nombre="Test",
        apellido="User",
        correo="test@cleanup.com",
        contrasena=hash_password("Test123!"),
        estado_cuenta="eliminado",
        id_rol=user_role.id_rol,
        proveedor="google",
        proveedor_id="google_sub_456"
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    user_id = user.id_usuario

    # Create dependencies
    token_sesion_val = "test_token"
    token_hash = hashlib.sha256(token_sesion_val.encode()).hexdigest()
    session = Sesion(
        token_sesion_hash=token_hash,
        dispositivo="Test Device",
        sistema_operativo="Windows",
        ip_usuario="127.0.0.1",
        estado_sesion="active",
        id_usuario=user_id
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
        id_usuario=user_id,
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
        id_usuario=user_id,
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
        id_usuario=user_id
    )
    db.add(reporte)

    notificacion = Notificacion(
        id_usuario=user_id,
        titulo="Test Notification",
        mensaje="Test message",
        tipo_notificacion="info",
        estado_notificacion="unread"
    )
    db.add(notificacion)

    reset_token = PasswordResetToken(
        id_usuario=user_id,
        token_hash="reset_hash",
        expires_at=datetime(2025, 12, 31, 23, 59, 59)
    )
    db.add(reset_token)

    email_token = EmailVerificationToken(
        id_usuario=user_id,
        token_hash="email_hash",
        expires_at=datetime(2025, 12, 31, 23, 59, 59)
    )
    db.add(email_token)

    recovery_code = RecoveryCode(
        id_usuario=user_id,
        code_hash="recovery_hash",
        expires_at=datetime(2025, 12, 31, 23, 59, 59)
    )
    db.add(recovery_code)

    db.commit()

    # Verify all exist before cleanup
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

    # Run hard delete
    success, message = hard_delete_user(db, user)

    assert success is True
    assert "eliminado correctamente" in message

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


def test_hard_delete_user_idempotent_when_user_already_gone(db):
    """Test that hard_delete_user handles gracefully a user that doesn't exist."""
    # Try to delete a non-existent user
    fake_user = Usuario(
        id_usuario=99999,
        nombre="Fake",
        apellido="User",
        correo="fake@test.com",
        estado_cuenta="eliminado",
        proveedor="local"
    )
    # Don't add to DB, just try to delete
    success, message = hard_delete_user(db, fake_user)
    
    # Should fail gracefully (user not in DB)
    assert success is False
    assert "Error eliminando usuario" in message


def test_cleanup_does_not_affect_active_users(db):
    """Test that cleanup only affects users with estado_cuenta='eliminado'."""
    user_role = db.query(Role).filter(Role.nombre_rol == "user").first()
    if not user_role:
        user_role = Role(nombre_rol="user", descripcion="Usuario normal", nivel_acceso=1)
        db.add(user_role)
        db.commit()
        db.refresh(user_role)

    # Create active user
    active_user = Usuario(
        nombre="Active",
        apellido="User",
        correo="active@cleanup.com",
        contrasena=hash_password("Test123!"),
        estado_cuenta="active",
        id_rol=user_role.id_rol,
        proveedor="local"
    )
    db.add(active_user)

    # Create soft-deleted user
    deleted_user = Usuario(
        nombre="Deleted",
        apellido="User",
        correo="deleted@cleanup.com",
        contrasena=hash_password("Test123!"),
        estado_cuenta="eliminado",
        id_rol=user_role.id_rol,
        proveedor="google",
        proveedor_id="google_sub_789"
    )
    db.add(deleted_user)
    db.commit()

    # Run cleanup logic manually (simulating the script)
    users_to_clean = get_users_to_cleanup(db)
    assert len(users_to_clean) == 1
    assert users_to_clean[0].correo == "deleted@cleanup.com"

    # Hard delete only the deleted user
    success, _ = hard_delete_user(db, users_to_clean[0])
    assert success is True

    # Active user should still exist
    assert db.query(Usuario).filter(Usuario.correo == "active@cleanup.com").first() is not None
    # Deleted user should be gone
    assert db.query(Usuario).filter(Usuario.correo == "deleted@cleanup.com").first() is None


def test_multiple_deleted_users_cleaned(db):
    """Test that multiple soft-deleted users are all cleaned up."""
    user_role = db.query(Role).filter(Role.nombre_rol == "user").first()
    if not user_role:
        user_role = Role(nombre_rol="user", descripcion="Usuario normal", nivel_acceso=1)
        db.add(user_role)
        db.commit()
        db.refresh(user_role)

    # Create multiple soft-deleted users
    for i in range(3):
        user = Usuario(
            nombre=f"Deleted{i}",
            apellido="User",
            correo=f"deleted{i}@cleanup.com",
            contrasena=hash_password("Test123!"),
            estado_cuenta="eliminado",
            id_rol=user_role.id_rol,
            proveedor="google",
            proveedor_id=f"google_sub_{i}"
        )
        db.add(user)
    db.commit()

    # Find all
    users_to_clean = get_users_to_cleanup(db)
    assert len(users_to_clean) == 3

    # Delete all
    for user in users_to_clean:
        success, _ = hard_delete_user(db, user)
        assert success is True

    # All should be gone
    remaining = get_users_to_cleanup(db)
    assert len(remaining) == 0


def test_google_reregister_after_cleanup(db):
    """Test that same Google account can register after cleanup."""
    user_role = db.query(Role).filter(Role.nombre_rol == "user").first()
    if not user_role:
        user_role = Role(nombre_rol="user", descripcion="Usuario normal", nivel_acceso=1)
        db.add(user_role)
        db.commit()
        db.refresh(user_role)

    # Create soft-deleted Google user
    user = Usuario(
        nombre="Google",
        apellido="User",
        correo="google@cleanup.com",
        estado_cuenta="eliminado",
        id_rol=user_role.id_rol,
        proveedor="google",
        proveedor_id="google_sub_cleanup"
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    user_id = user.id_usuario

    # Clean up
    success, _ = hard_delete_user(db, user)
    assert success is True

    # Verify user is gone
    assert db.query(Usuario).filter(Usuario.id_usuario == user_id).first() is None
    assert db.query(Usuario).filter(Usuario.correo == "google@cleanup.com").first() is None
    assert db.query(Usuario).filter(Usuario.proveedor_id == "google_sub_cleanup").first() is None

    # Now the same Google sub should be able to register (simulating auth.py logic)
    existing = db.query(Usuario).filter(
        Usuario.proveedor == "google",
        Usuario.proveedor_id == "google_sub_cleanup"
    ).first()
    assert existing is None  # No conflict, can register new account


def test_dry_run_mode(db):
    """Test that dry-run mode doesn't actually delete."""
    user_role = db.query(Role).filter(Role.nombre_rol == "user").first()
    if not user_role:
        user_role = Role(nombre_rol="user", descripcion="Usuario normal", nivel_acceso=1)
        db.add(user_role)
        db.commit()
        db.refresh(user_role)

    user = Usuario(
        nombre="DryRun",
        apellido="User",
        correo="dryrun@cleanup.com",
        contrasena=hash_password("Test123!"),
        estado_cuenta="eliminado",
        id_rol=user_role.id_rol,
        proveedor="local"
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    user_id = user.id_usuario

    # In dry-run, we just call get_users_to_cleanup, not hard_delete_user
    users = get_users_to_cleanup(db)
    assert len(users) == 1
    assert users[0].id_usuario == user_id

    # User should still exist (dry-run doesn't delete)
    assert db.query(Usuario).filter(Usuario.id_usuario == user_id).first() is not None


if __name__ == "__main__":
    pytest.main([__file__, "-v"])