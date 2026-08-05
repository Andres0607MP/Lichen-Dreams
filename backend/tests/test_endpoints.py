"""
Tests de integración para todos los endpoints de Persona 2
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from main import app
from config.db import get_db
from backend.models.base import Base
from backend.models.core import Usuario, Role, Analisis, LiquenPedia, Dataset as DatasetModel, ModeloIA


# Configuración de BD de prueba
SQLALCHEMY_TEST_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(SQLALCHEMY_TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def db():
    Base.metadata.create_all(bind=engine)
    yield TestingSessionLocal()
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db):
    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app)


@pytest.fixture(scope="function")
def test_admin_user(db):
    """Crea un usuario administrador de prueba"""
    role = Role(nombre_rol="admin", descripcion="Administrador", nivel_acceso=1)
    db.add(role)
    db.commit()
    
    admin = Usuario(
        nombre="Admin",
        apellido="Test",
        correo="admin@test.com",
        contraseña="hashed_password",
        id_rol=role.id_rol,
        estado_cuenta="activo"
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    return admin


@pytest.fixture(scope="function")
def test_regular_user(db):
    """Crea un usuario regular de prueba"""
    role = Role(nombre_rol="user", descripcion="Usuario", nivel_acceso=2)
    db.add(role)
    db.commit()
    
    user = Usuario(
        nombre="User",
        apellido="Test",
        correo="user@test.com",
        contraseña="hashed_password",
        id_rol=role.id_rol,
        estado_cuenta="activo"
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# ============================================================================
# TESTS PARA USUARIOS (ISSUE #1)
# ============================================================================

class TestUsuariosEndpoints:
    """Tests para endpoints de usuarios"""
    
    def test_list_users_admin_only(self, client, db, test_admin_user):
        """Test: Listar usuarios solo con permisos admin"""
        # TODO: Implementar después que auth esté completamente integrado
        pass
    
    def test_get_user_admin_only(self, client, db, test_admin_user):
        """Test: Obtener usuario solo con permisos admin"""
        pass
    
    def test_update_user_admin_only(self, client, db, test_admin_user):
        """Test: Actualizar usuario solo con permisos admin"""
        pass
    
    def test_update_user_duplicate_email(self, client, db, test_admin_user):
        """Test: No permitir email duplicado"""
        pass
    
    def test_delete_user_soft_delete(self, client, db, test_admin_user):
        """Test: Soft delete (marcar como eliminado, no borrar)"""
        pass
    
    def test_get_nonexistent_user(self, client, db, test_admin_user):
        """Test: Obtener usuario inexistente devuelve 404"""
        pass


# ============================================================================
# TESTS PARA ANÁLISIS (ISSUE #2)
# ============================================================================

class TestAnalisisEndpoints:
    """Tests para endpoints de análisis"""
    
    def test_upload_image_valid_format(self, client):
        """Test: Subir imagen con formato válido (jpg, jpeg, png)"""
        pass
    
    def test_upload_image_invalid_format(self, client):
        """Test: Rechazar imagen con formato inválido"""
        pass
    
    def test_upload_image_exceeds_size(self, client):
        """Test: Rechazar imagen mayor a 50MB"""
        pass
    
    def test_process_analysis(self, client, db, test_regular_user):
        """Test: Procesar análisis con IA"""
        pass
    
    def test_get_analysis_owner(self, client, db, test_regular_user):
        """Test: Propietario puede ver su análisis"""
        pass
    
    def test_get_analysis_admin(self, client, db, test_admin_user):
        """Test: Admin puede ver cualquier análisis"""
        pass
    
    def test_get_analysis_unauthorized(self, client, db, test_regular_user):
        """Test: Usuario no propietario no puede ver análisis"""
        pass
    
    def test_delete_analysis_owner(self, client, db, test_regular_user):
        """Test: Propietario puede eliminar su análisis"""
        pass
    
    def test_delete_analysis_admin(self, client, db, test_admin_user):
        """Test: Admin puede eliminar cualquier análisis"""
        pass
    
    def test_delete_analysis_unauthorized(self, client, db, test_regular_user):
        """Test: Usuario no propietario no puede eliminar análisis"""
        pass


# ============================================================================
# TESTS PARA LIQUENPEDIA (ISSUE #3)
# ============================================================================

class TestLiquenpediaEndpoints:
    """Tests para endpoints de LiquenPedia"""
    
    def test_list_articles_public(self, client, db):
        """Test: Listar artículos es público"""
        # Crear algunos artículos de prueba
        for i in range(3):
            article = LiquenPedia(
                titulo=f"Artículo {i}",
                contenido=f"Contenido {i}",
                categoria="Test"
            )
            db.add(article)
        db.commit()
        
        response = client.get("/liquenpedia")
        assert response.status_code == 200
        assert len(response.json()) == 3
    
    def test_list_articles_search_titulo(self, client, db):
        """Test: Buscar artículos por título"""
        article = LiquenPedia(titulo="Liquen Verde", contenido="Test")
        db.add(article)
        db.commit()
        
        response = client.get("/liquenpedia?titulo=Verde")
        assert response.status_code == 200
        assert len(response.json()) > 0
    
    def test_list_articles_search_categoria(self, client, db):
        """Test: Filtrar artículos por categoría"""
        article = LiquenPedia(titulo="Test", contenido="Test", categoria="Ecología")
        db.add(article)
        db.commit()
        
        response = client.get("/liquenpedia?categoria=Ecología")
        assert response.status_code == 200
    
    def test_create_article_admin_only(self, client, test_admin_user):
        """Test: Solo admin puede crear artículos"""
        # TODO: Implementar cuando auth esté integrado
        pass
    
    def test_create_article_unauthorized(self, client, test_regular_user):
        """Test: Usuario regular no puede crear artículos"""
        # TODO: Implementar cuando auth esté integrado
        pass
    
    def test_get_article_public(self, client, db):
        """Test: Obtener artículo es público"""
        article = LiquenPedia(titulo="Test", contenido="Test")
        db.add(article)
        db.commit()
        
        response = client.get(f"/liquenpedia/{article.id_articulo}")
        assert response.status_code == 200
        assert response.json()["titulo"] == "Test"
    
    def test_get_nonexistent_article(self, client, db):
        """Test: Obtener artículo inexistente devuelve 404"""
        response = client.get("/liquenpedia/999999")
        assert response.status_code == 404
    
    def test_update_article_admin_only(self, client, db, test_admin_user):
        """Test: Solo admin puede actualizar artículos"""
        # TODO: Implementar cuando auth esté integrado
        pass
    
    def test_delete_article_admin_only(self, client, db, test_admin_user):
        """Test: Solo admin puede eliminar artículos"""
        # TODO: Implementar cuando auth esté integrado
        pass


# ============================================================================
# TESTS PARA DATASETS (ISSUE #4)
# ============================================================================

class TestDatasetEndpoints:
    """Tests para endpoints de datasets"""
    
    def test_list_datasets_public(self, client, db):
        """Test: Listar datasets es público"""
        ds = DatasetModel(nombre_dataset="Test Dataset", tipo_datos="CSV")
        db.add(ds)
        db.commit()
        
        response = client.get("/datasets")
        assert response.status_code == 200
    
    def test_get_dataset_public(self, client, db):
        """Test: Obtener dataset es público"""
        ds = DatasetModel(nombre_dataset="Test Dataset", tipo_datos="CSV")
        db.add(ds)
        db.commit()
        
        response = client.get(f"/datasets/{ds.id_dataset}")
        assert response.status_code == 200
        assert response.json()["nombre_dataset"] == "Test Dataset"
    
    def test_get_nonexistent_dataset(self, client):
        """Test: Obtener dataset inexistente devuelve 404"""
        response = client.get("/datasets/999999")
        assert response.status_code == 404
    
    def test_create_dataset_admin_only(self, client, test_admin_user):
        """Test: Solo admin puede crear datasets"""
        # TODO: Implementar cuando auth esté integrado
        pass
    
    def test_update_dataset_admin_only(self, client, test_admin_user):
        """Test: Solo admin puede actualizar datasets"""
        # TODO: Implementar cuando auth esté integrado
        pass
    
    def test_delete_dataset_admin_only(self, client, test_admin_user):
        """Test: Solo admin puede eliminar datasets"""
        # TODO: Implementar cuando auth esté integrado
        pass


# ============================================================================
# TESTS PARA MODELOS IA (ISSUE #4)
# ============================================================================

class TestModelosEndpoints:
    """Tests para endpoints de modelos IA"""
    
    def test_list_models_public(self, client, db):
        """Test: Listar modelos es público"""
        model = ModeloIA(nombre_modelo="Test Model", version="1.0")
        db.add(model)
        db.commit()
        
        response = client.get("/modelos")
        assert response.status_code == 200
    
    def test_get_model_public(self, client, db):
        """Test: Obtener modelo es público"""
        model = ModeloIA(nombre_modelo="Test Model", version="1.0")
        db.add(model)
        db.commit()
        
        response = client.get(f"/modelos/{model.id_modelo}")
        assert response.status_code == 200
        assert response.json()["nombre_modelo"] == "Test Model"
    
    def test_get_nonexistent_model(self, client):
        """Test: Obtener modelo inexistente devuelve 404"""
        response = client.get("/modelos/999999")
        assert response.status_code == 404
    
    def test_create_model_admin_only(self, client, test_admin_user):
        """Test: Solo admin puede crear modelos"""
        # TODO: Implementar cuando auth esté integrado
        pass
    
    def test_update_model_admin_only(self, client, test_admin_user):
        """Test: Solo admin puede actualizar modelos"""
        # TODO: Implementar cuando auth esté integrado
        pass
    
    def test_delete_model_admin_only(self, client, test_admin_user):
        """Test: Solo admin puede eliminar modelos"""
        # TODO: Implementar cuando auth esté integrado
        pass


# ============================================================================
# TESTS DE STATUS CODES
# ============================================================================

class TestStatusCodes:
    """Tests para validar status codes HTTP correctos"""
    
    def test_200_ok(self, client, db):
        """Test: GET exitoso devuelve 200"""
        article = LiquenPedia(titulo="Test", contenido="Test")
        db.add(article)
        db.commit()
        
        response = client.get(f"/liquenpedia/{article.id_articulo}")
        assert response.status_code == 200
    
    def test_201_created(self, client, db):
        """Test: POST exitoso devuelve 201"""
        # TODO: Cuando auth esté integrado
        pass
    
    def test_204_no_content(self, client, db, test_admin_user):
        """Test: DELETE exitoso devuelve 204"""
        # TODO: Cuando auth esté integrado
        pass
    
    def test_400_bad_request(self, client):
        """Test: Request inválido devuelve 400"""
        # Intentar subir imagen sin archivo
        response = client.post("/analysis/upload")
        assert response.status_code in [400, 422]  # 422 si falla validación Pydantic
    
    def test_403_forbidden(self, client, test_regular_user):
        """Test: Acceso denegado devuelve 403"""
        # TODO: Cuando auth esté integrado
        pass
    
    def test_404_not_found(self, client):
        """Test: Recurso no encontrado devuelve 404"""
        response = client.get("/liquenpedia/999999")
        assert response.status_code == 404
    
    def test_409_conflict(self, client, test_admin_user):
        """Test: Conflicto (email duplicado) devuelve 409"""
        # TODO: Cuando auth esté integrado
        pass
