from fastapi.testclient import TestClient
from backend.main import app
import uuid

client = TestClient(app)


def test_refresh_and_logout_flow():
    # register a fresh user
    email = f"test+{uuid.uuid4().hex[:6]}@example.com"
    password = "TestPass123!"
    reg = client.post("/api/auth/register", json={"email": email, "password": password, "name": "Test User"})
    assert reg.status_code in (200, 201)

    # login (may use form data depending on implementation)
    login = client.post("/api/auth/login", data={"username": email, "password": password})
    assert login.status_code == 200
    tokens = login.json()
    assert "access_token" in tokens and "refresh_token" in tokens
    refresh_token = tokens["refresh_token"]

    # use refresh to get a new access token
    ref = client.post("/api/auth/refresh", json={"refresh_token": refresh_token})
    assert ref.status_code == 200
    assert "access_token" in ref.json()

    # logout the refresh token (revoke session)
    out = client.post("/api/auth/logout_refresh", json={"refresh_token": refresh_token})
    assert out.status_code == 200

    # subsequent refresh with the revoked token should fail
    ref2 = client.post("/api/auth/refresh", json={"refresh_token": refresh_token})
    assert ref2.status_code in (400, 401, 403)
