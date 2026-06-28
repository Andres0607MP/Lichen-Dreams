import pytest
from datetime import datetime
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker
from pydantic import ValidationError

from models.base import Base
from models.core import (
    Role,
    Usuario,
    Sesion,
    ModeloIA,
    Dataset,
    Analisis,
    Imagen,
    Ubicacion,
)
from models.validations import (
    UsuarioCreate,
    UbicacionCreate,
    ModeloIACreate,
    AnalisisCreate,
)


ENGINE = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=ENGINE)
Base.metadata.create_all(bind=ENGINE)


@pytest.fixture(scope="function")
def db_session():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        session.close()


def test_usuario_model_create_and_unique_email(db_session):
    role = Role(nombre_rol="tester", descripcion="Test role", nivel_acceso=1)
    db_session.add(role)
    db_session.commit()

    usuario = Usuario(
        nombre="Test",
        apellido="Usuario",
        correo="test@example.com",
        contrasena="Secret123",
        telefono="+1234567890",
        id_rol=role.id_rol,
    )
    db_session.add(usuario)
    db_session.commit()
    db_session.refresh(usuario)

    assert usuario.id_usuario is not None
    assert usuario.estado_activo is True
    assert usuario.fecha_registro is not None

    usuario2 = Usuario(
        nombre="Test2",
        apellido="Usuario2",
        correo="test@example.com",
        contrasena="Secret123",
        telefono="+1234567891",
        id_rol=role.id_rol,
    )
    db_session.add(usuario2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_usuario_model_timestamps_on_update(db_session):
    role = Role(nombre_rol="tester2", descripcion="Test role 2", nivel_acceso=1)
    db_session.add(role)
    db_session.commit()

    usuario = Usuario(
        nombre="Update",
        apellido="Tester",
        correo="update@example.com",
        contrasena="Secret123",
        telefono="+1234567892",
        id_rol=role.id_rol,
    )
    db_session.add(usuario)
    db_session.commit()
    assert usuario.fecha_registro is not None

    usuario.nombre = "Updated"
    db_session.commit()
    assert usuario.fecha_actualizacion is not None


def test_ubicacion_model_validates_range(db_session):
    ubicacion = Ubicacion(
        latitud=4.7110,
        longitud=-74.0721,
        direccion="Calle Falsa 123",
        municipio="Bogotá",
        departamento="Cundinamarca",
        pais="Colombia",
    )
    db_session.add(ubicacion)
    db_session.commit()
    assert ubicacion.id_ubicacion is not None

    ubicacion_bad = Ubicacion(
        latitud=100.0,
        longitud=0.0,
        direccion="Dirección inválida",
        municipio="Bogotá",
        departamento="Cundinamarca",
        pais="Colombia",
    )
    db_session.add(ubicacion_bad)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_relaciones_modelos_fk_and_backrefs(db_session):
    role = Role(nombre_rol="tester3", descripcion="Test role 3", nivel_acceso=1)
    db_session.add(role)
    db_session.commit()

    usuario = Usuario(
        nombre="Rel",
        apellido="Tester",
        correo="reluser@example.com",
        contrasena="Secret123",
        telefono="+1234567893",
        id_rol=role.id_rol,
    )
    db_session.add(usuario)
    db_session.commit()

    modelo = ModeloIA(nombre_modelo="IA-Test", version="1.0.0", descripcion="Modelo de prueba")
    dataset = Dataset(nombre_dataset="Data Test", ruta_archivo="/tmp/ds", tipo_datos="imagen")
    db_session.add_all([modelo, dataset])
    db_session.commit()

    analisis = Analisis(
        id_usuario=usuario.id_usuario,
        id_modelo=modelo.id_modelo,
        id_dataset=dataset.id_dataset,
        resultado="{}",
        estado="pending",
        metadata_resultado={"score": 0.9},
    )
    db_session.add(analisis)
    db_session.commit()
    db_session.refresh(analisis)

    imagen = Imagen(
        id_analisis=analisis.id_analisis,
        url="http://example.com/image.jpg",
        ruta_original="/tmp/original.jpg",
        ruta_procesada="/tmp/processed.jpg",
        descripcion="Imagen de prueba",
    )
    db_session.add(imagen)
    db_session.commit()
    db_session.refresh(imagen)

    assert analisis.usuario.id_usuario == usuario.id_usuario
    assert analisis.modelo.id_modelo == modelo.id_modelo
    assert analisis.dataset.id_dataset == dataset.id_dataset
    assert imagen.analisis.id_analisis == analisis.id_analisis
    assert len(usuario.analisis) == 1
    assert usuario.analisis[0].imagenes[0].id_imagen == imagen.id_imagen


def test_usuario_create_validation_password_requirements():
    with pytest.raises(ValidationError):
        UsuarioCreate(
            nombre="Val",
            apellido="Test",
            correo="valtest@example.com",
            contrasena="nouppercase1",
            telefono="+1234567894",
        )

    with pytest.raises(ValidationError):
        UsuarioCreate(
            nombre="Val",
            apellido="Test",
            correo="valtest2@example.com",
            contrasena="NoDigits",
            telefono="+1234567895",
        )


def test_ubicacion_create_validation_limits():
    with pytest.raises(ValidationError):
        UbicacionCreate(
            latitud=95.0,
            longitud=-74.0,
            direccion="Dirección",
            municipio="Bogotá",
            departamento="Cundinamarca",
            pais="Colombia",
        )
    with pytest.raises(ValidationError):
        UbicacionCreate(
            latitud=4.7,
            longitud=-185.0,
            direccion="Dirección",
            municipio="Bogotá",
            departamento="Cundinamarca",
            pais="Colombia",
        )


def test_modelo_ia_version_semver_validation():
    with pytest.raises(ValidationError):
        ModeloIACreate(
            nombre_modelo="Modelo Nombre",
            version="1.0",
            descripcion="Prueba",
        )

    modelo = ModeloIACreate(
        nombre_modelo="Modelo Nombre",
        version="1.0.0",
        descripcion="Prueba",
    )
    assert modelo.version == "1.0.0"


def test_analisis_create_optional_metadata():
    analisis = AnalisisCreate(id_modelo=1, id_dataset=None)
    assert analisis.id_modelo == 1
    assert analisis.id_dataset is None
    assert analisis.metadata_adicional is None
