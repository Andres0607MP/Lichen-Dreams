import sys
import os

sys.path.append(
    os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            ".."
        )
    )
)

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def obtener_token():

    login = client.post(
        "/auth/login",
        data={
            "username": "admin@gmail.com",
            "password": "admin123"
        }
    )

    assert login.status_code == 200

    data = login.json()

    return data["access_token"]


def crear_analisis_prueba(token):

    headers = {
        "Authorization": f"Bearer {token}"
    }

    response = client.post(
        "/analysis/process",
        headers=headers,
        json={
            "image_url": "https://test.jpg",
            "id_modelo": 1,
            "id_dataset": 1
        }
    )

    assert response.status_code == 200

    return response.json()["id"]


def test_crear_analisis():

    token = obtener_token()

    analysis_id = crear_analisis_prueba(token)

    assert analysis_id is not None


def test_obtener_resultado_analisis():

    token = obtener_token()
    headers = {"Authorization": f"Bearer {token}"}

    analysis_id = crear_analisis_prueba(token)

    response = client.get(
        f"/analysis/results/{analysis_id}",
        headers=headers
    )

    assert response.status_code == 200

    data = response.json()

    assert data["id"] == analysis_id
    assert "humidity" in data
    assert "air_quality" in data
    assert "recommendation" in data


def test_estado_analisis():

    token = obtener_token()
    headers = {"Authorization": f"Bearer {token}"}

    analysis_id = crear_analisis_prueba(token)

    response = client.get(
        f"/analysis/{analysis_id}/status",
        headers=headers
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] in ("completed", "error")


def test_admin_no_login_with_old_password():

    login = client.post(
        "/auth/login",
        data={
            "username": "admin@gmail.com",
            "password": "admin"
        }
    )

    assert login.status_code in [401, 400]
