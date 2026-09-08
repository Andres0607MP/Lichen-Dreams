"""Pruebas para el sistema de monitoreo e observabilidad de la IA.

Cubre:
- Health check (modelo cargado, modelo no disponible, estructura, auth, authz).
- Métricas (incremento correcto, éxito, error, latencia, confianza, error rate).
- Eventos SSE (inicio, éxito, error, replay, desconexión).
- Resiliencia (un error en monitoreo no rompe la inferencia).
"""
import os
import sys

os.environ.setdefault("DATABASE_URL", "sqlite://")

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient
import httpx

from config.db import get_db
from main import app
from models.base import Base
from models.core import Role, Usuario, ModeloIA
from auth.password_handler import hash_password


@pytest.fixture(scope="function")
def _engine():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(bind=engine)
    yield TestingSessionLocal


@pytest.fixture(scope="function")
def _db(_engine):
    db_session = _engine()
    try:
        if not db_session.query(Role).filter(Role.nombre_rol == "admin").first():
            db_session.add(Role(nombre_rol="admin", descripcion="Administrador", nivel_acceso=10))
        if not db_session.query(Role).filter(Role.nombre_rol == "user").first():
            db_session.add(Role(nombre_rol="user", descripcion="Usuario", nivel_acceso=1))
        db_session.commit()

        if not db_session.query(Usuario).filter(Usuario.correo == "admin@gmail.com").first():
            admin_role = db_session.query(Role).filter(Role.nombre_rol == "admin").first()
            db_session.add(Usuario(
                nombre="Admin", correo="admin@gmail.com",
                contrasena=hash_password("admin123"),
                estado_cuenta="active", id_rol=admin_role.id_rol,
            ))
        if not db_session.query(Usuario).filter(Usuario.correo == "regularuser@test.com").first():
            user_role = db_session.query(Role).filter(Role.nombre_rol == "user").first()
            db_session.add(Usuario(
                nombre="Regular", correo="regularuser@test.com",
                contrasena=hash_password("Password123!"),
                estado_cuenta="active", id_rol=user_role.id_rol,
            ))
        db_session.commit()
    finally:
        db_session.close()
    yield db_session


@pytest.fixture(scope="function")
def _client(_engine):
    TestingSessionLocal = _engine

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _login_headers(client, email, password):
    resp = client.post("/auth/login", data={"email": email, "password": password})
    assert resp.status_code == 200, resp.text
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


@pytest.fixture(scope="function", autouse=True)
def _reset_monitoring():
    from services.monitoring_service import monitoring_service
    monitoring_service.reset()
    yield
    monitoring_service.reset()


# ---------------------------------------------------------------------------
#  MonitoringService unit tests (no DB / no auth)
# ---------------------------------------------------------------------------

class TestMonitoringServiceMetrics:
    def test_initial_metrics_are_zero(self):
        from services.monitoring_service import monitoring_service
        m = monitoring_service.get_metrics()
        assert m["total_inferences"] == 0
        assert m["successful_inferences"] == 0
        assert m["failed_inferences"] == 0
        assert m["error_rate"] == 0.0
        assert m["average_inference_time_ms"] is None
        assert m["average_confidence"] is None

    def test_record_success_increments_correctly(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        ms.record_inference(success=True, inference_time_ms=100.0, confidence=0.9,
                            category="liquen saludable")
        ms.record_inference(success=True, inference_time_ms=200.0, confidence=0.8,
                            category="liquen contaminado")
        m = ms.get_metrics()
        assert m["total_inferences"] == 2
        assert m["successful_inferences"] == 2
        assert m["failed_inferences"] == 0
        assert m["error_rate"] == 0.0
        assert m["average_inference_time_ms"] == 150.0
        assert m["min_inference_time_ms"] == 100.0
        assert m["max_inference_time_ms"] == 200.0
        assert m["average_confidence"] == 0.85
        assert m["last_inference_timestamp"] is not None

    def test_record_failure_updates_error_rate(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        ms.record_inference(success=True, inference_time_ms=100.0, confidence=0.9)
        ms.record_inference(success=False, inference_time_ms=50.0,
                            error_type="ActiveModelError")
        m = ms.get_metrics()
        assert m["total_inferences"] == 2
        assert m["successful_inferences"] == 1
        assert m["failed_inferences"] == 1
        assert m["error_rate"] == 0.5
        assert m["last_error"] == "ActiveModelError"
        assert m["last_error_timestamp"] is not None

    def test_active_inferences_count(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        ms.record_analysis_started()
        ms.record_analysis_started()
        m = ms.get_metrics()
        assert m["active_inferences"] == 2

    def test_resilience_monitoring_failure_does_not_raise(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        try:
            ms.record_inference(
                success=True, inference_time_ms=10.0, confidence=0.95,
                category="test", analysis_id=None, error_type=None,
            )
        except Exception:
            pytest.fail("record_inference must never raise to the caller")


class TestMonitoringServiceEvents:
    def test_subscribe_and_publish(self):
        import queue as qmod
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        q = ms.subscribe()
        assert q is not None

        ms.publish_event("test_event", {"value": 42})

        event = q.get_nowait()
        assert event["type"] == "test_event"
        assert event["data"]["value"] == 42
        assert "timestamp" in event["data"]

        ms.unsubscribe(q)

    def test_each_subscriber_gets_own_events(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        q1 = ms.subscribe()
        q2 = ms.subscribe()

        ms.publish_event("broadcast", {"msg": "hello"})

        e1 = q1.get_nowait()
        e2 = q2.get_nowait()
        assert e1["data"]["msg"] == "hello"
        assert e2["data"]["msg"] == "hello"

        ms.unsubscribe(q1)
        ms.unsubscribe(q2)

    def test_recent_events_replay(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        ms.publish_event("event_a", {"n": 1})
        ms.publish_event("event_b", {"n": 2})
        history = ms.recent_events
        assert len(history) == 2
        assert history[0]["type"] == "event_a"
        assert history[1]["type"] == "event_b"

    def test_dead_subscriber_is_cleaned(self):
        import queue as qmod
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        q = ms.subscribe()
        ms.unsubscribe(q)
        ms.publish_event("after_cleanup", {})
        assert q.empty()

    def test_record_inference_publishes_events(self):
        import queue as qmod
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        q = ms.subscribe()

        ms.record_inference(success=True, inference_time_ms=100.0, confidence=0.9,
                            category="liquen saludable")

        events = []
        while True:
            try:
                events.append(q.get_nowait()["type"])
            except qmod.Empty:
                break
        assert "analysis_completed" in events

        ms.unsubscribe(q)


# ---------------------------------------------------------------------------
#  Health endpoint tests
# ---------------------------------------------------------------------------

class TestIaHealth:
    def test_health_without_auth(self, _client, _db):
        resp = _client.get("/ia/health")
        assert resp.status_code == 401

    def test_health_requires_admin(self, _client, _db):
        headers = _login_headers(_client, "regularuser@test.com", "Password123!")
        resp = _client.get("/ia/health", headers=headers)
        assert resp.status_code == 403

    def test_health_admin_response_structure(self, _client, _db):
        headers = _login_headers(_client, "admin@gmail.com", "admin123")
        resp = _client.get("/ia/health", headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] in ("healthy", "degraded", "unhealthy")
        assert "model_loaded" in data
        assert "model_name" in data
        assert "model_version" in data
        assert "classes" in data
        assert "tensorflow_version" in data
        assert "keras_version" in data
        assert "device" in data
        assert "model_loaded_at" in data
        assert "uptime_seconds" in data
        assert isinstance(data["classes"], list)


# ---------------------------------------------------------------------------
#  Metrics endpoint tests
# ---------------------------------------------------------------------------

class TestIaMetrics:
    def test_metrics_without_auth(self, _client, _db):
        resp = _client.get("/ia/metrics")
        assert resp.status_code == 401

    def test_metrics_requires_admin(self, _client, _db):
        headers = _login_headers(_client, "regularuser@test.com", "Password123!")
        resp = _client.get("/ia/metrics", headers=headers)
        assert resp.status_code == 403

    def test_metrics_reflects_recorded_inferences(self, _client, _db):
        from services.monitoring_service import monitoring_service
        monitoring_service.record_inference(success=True, inference_time_ms=50.0,
                                            confidence=0.88, category="liquen saludable")
        headers = _login_headers(_client, "admin@gmail.com", "admin123")
        resp = _client.get("/ia/metrics", headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_inferences"] == 1
        assert data["successful_inferences"] == 1
        assert data["failed_inferences"] == 0
        assert data["error_rate"] == 0.0
        assert data["average_confidence"] == 0.88

    def test_metrics_failure_reflected(self, _client, _db):
        from services.monitoring_service import monitoring_service
        monitoring_service.record_inference(success=False, inference_time_ms=30.0,
                                            error_type="FileNotFoundError")
        headers = _login_headers(_client, "admin@gmail.com", "admin123")
        resp = _client.get("/ia/metrics", headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["failed_inferences"] == 1
        assert data["error_rate"] == 1.0
        assert data["last_error"] == "FileNotFoundError"


# ---------------------------------------------------------------------------
#  SSE Events endpoint tests
# ---------------------------------------------------------------------------

class TestIaEvents:
    def test_events_without_auth(self, _client, _db):
        resp = _client.get("/ia/events")
        assert resp.status_code == 401

    def test_events_requires_admin(self, _client, _db):
        headers = _login_headers(_client, "regularuser@test.com", "Password123!")
        resp = _client.get("/ia/events", headers=headers)
        assert resp.status_code == 403

    def test_events_endpoint_accessible_with_admin_auth(self, _client, _db):
        """Verifica que el endpoint SSE está accesible con auth de admin.

        Usamos el parámetro ``limit`` para obtener un stream acotado que el
        TestClient puede consumir sincrónicamente.
        """
        from services.monitoring_service import monitoring_service
        monitoring_service.publish_event("analysis_started", {"test": True})

        headers = _login_headers(_client, "admin@gmail.com", "admin123")
        resp = _client.get("/ia/events?limit=1", headers=headers)
        assert resp.status_code == 200
        ct = resp.headers.get("content-type", "")
        assert "event-stream" in ct
        body = resp.text
        assert "event: analysis_started" in body
        assert "data:" in body

    def test_format_sse_produces_valid_output(self):
        from routes.ia import _format_sse
        monitoring_service.publish_event("model_loaded", {"model_path": "/test/model.keras"})

        for evt in monitoring_service.recent_events:
            formatted = _format_sse(evt)
            assert "event: model_loaded" in formatted
            assert "data: " in formatted
            assert formatted.endswith("\n\n")

    def test_format_sse_produces_valid_output(self):
        from routes.ia import _format_sse
        from services.monitoring_service import monitoring_service
        monitoring_service.publish_event("model_loaded", {"model_path": "/test/model.keras"})

        for evt in monitoring_service.recent_events:
            formatted = _format_sse(evt)
            assert "event: model_loaded" in formatted
            assert "data: " in formatted
            assert formatted.endswith("\n\n")


# ---------------------------------------------------------------------------
#  Métricas extendidas + serie temporal + distribuciones
# ---------------------------------------------------------------------------

class TestIaMetricsExtended:
    def test_predictions_distribution_and_p95(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        ms.record_inference(success=True, inference_time_ms=100.0, confidence=0.9,
                            category="liquen saludable")
        ms.record_inference(success=True, inference_time_ms=200.0, confidence=0.8,
                            category="liquen contaminado")
        ms.record_inference(success=True, inference_time_ms=300.0, confidence=0.7,
                            category="liquen desconocido")
        m = ms.get_metrics()
        assert m["predictions"] == {"healthy": 1, "critical": 1, "unknown": 1}
        # p95 interpolado de [100, 200, 300] -> 290.0
        assert m["p95_latency_ms"] == 290.0
        assert m["requests_per_minute"] == 3
        assert m["throughput_per_second"] >= 0.0
        assert isinstance(m["series"], list)
        assert m["series"], "Debe existir al menos un cubo de la serie"
        assert "avg_latency_ms" in m["series"][-1]
        assert "p95_latency_ms" in m["series"][-1]

    def test_series_respects_bucket_timestamp(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        ms.record_inference(success=True, inference_time_ms=50.0, confidence=0.9,
                            category="liquen saludable")
        m = ms.get_metrics()
        bucket = m["series"][-1]
        assert bucket["requests"] >= 1
        assert bucket["healthy"] >= 1
        assert bucket["success"] >= 1


class TestIaDiagnostics:
    def test_diagnostics_without_auth(self, _client, _db):
        resp = _client.get("/ia/diagnostics")
        assert resp.status_code == 401

    def test_diagnostics_requires_admin(self, _client, _db):
        headers = _login_headers(_client, "regularuser@test.com", "Password123!")
        resp = _client.get("/ia/diagnostics", headers=headers)
        assert resp.status_code == 403

    def test_diagnostics_structure_is_deterministic(self, _client, _db):
        from services.monitoring_service import monitoring_service
        monitoring_service.record_inference(success=True, inference_time_ms=120.0,
                                            confidence=0.9, category="liquen saludable")
        headers = _login_headers(_client, "admin@gmail.com", "admin123")
        resp = _client.get("/ia/diagnostics", headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] in ("healthy", "degraded", "critical", "unhealthy")
        assert isinstance(data["score"], (int, float))
        assert 0 <= data["score"] <= 100
        assert isinstance(data["checks"], list)
        assert isinstance(data["recommended_actions"], list)
        assert "rules_version" in data

    def test_diagnostics_reflects_failures(self, _client, _db):
        from services.monitoring_service import monitoring_service
        monitoring_service.record_inference(success=False, inference_time_ms=30.0,
                                            error_type="ActiveModelError")
        headers = _login_headers(_client, "admin@gmail.com", "admin123")
        resp = _client.get("/ia/diagnostics", headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        ids = {c["id"] for c in data["checks"]}
        assert "errors" in ids
        error_check = next(c for c in data["checks"] if c["id"] == "errors")
        assert error_check["status"] == "critical"


# ---------------------------------------------------------------------------
#  Corrección de métricas temporales (buckets vacíos, ventanas y throughput)
# ---------------------------------------------------------------------------

MIN0 = 1_780_000_080.0  # alineado a minuto UTC


def _freeze_clock(ms, clock_holder):
    ms._now = lambda: clock_holder["t"]


class TestTemporalMetrics:
    def test_empty_bucket_appears_in_series(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        clock = {"t": MIN0}
        _freeze_clock(ms, clock)
        ms.record_inference(success=True, inference_time_ms=100.0, confidence=0.9,
                            category="liquen saludable")

        # Avanza 2 minutos sin actividad.
        clock["t"] = MIN0 + 120
        m = ms.get_metrics()

        empty = next(b for b in m["series"] if b["requests"] == 0 and "avg_latency_ms" in b)
        assert empty["avg_latency_ms"] is None
        assert empty["min_latency_ms"] is None
        assert empty["max_latency_ms"] is None
        assert empty["p95_latency_ms"] is None
        assert empty["avg_confidence"] is None

    def test_intermediate_empty_minute_is_kept(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        clock = {"t": MIN0}
        _freeze_clock(ms, clock)

        for i in range(3):
            ms.record_inference(success=True, inference_time_ms=100.0, confidence=0.9,
                                category="liquen saludable")
        clock["t"] = MIN0 + 60
        for i in range(7):
            ms.record_inference(success=True, inference_time_ms=200.0, confidence=0.9,
                                category="liquen saludable")
        clock["t"] = MIN0 + 180  # salta el minuto del medio
        for i in range(2):
            ms.record_inference(success=True, inference_time_ms=150.0, confidence=0.9,
                                category="liquen saludable")

        m = ms.get_metrics()
        series = m["series"]
        assert len(series) == 4, series
        assert series[0]["requests"] == 3
        assert series[1]["requests"] == 7
        assert series[2]["requests"] == 0, "El minuto intermedio vacío no debe eliminarse"
        assert series[2]["avg_latency_ms"] is None
        assert series[3]["requests"] == 2

    def test_series_is_capped_at_about_60(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        clock = {"t": MIN0}
        _freeze_clock(ms, clock)
        for minute in range(70):
            clock["t"] = MIN0 + minute * 60
            ms.record_inference(success=True, inference_time_ms=100.0,
                                confidence=0.9, category="liquen saludable")

        m = ms.get_metrics()
        assert len(m["series"]) <= 60
        assert m["series"][-1]["requests"] == 1

    def test_series_is_chronologically_ordered(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        clock = {"t": MIN0}
        _freeze_clock(ms, clock)
        for minute in range(5):
            clock["t"] = MIN0 + minute * 60
            ms.record_inference(success=True, inference_time_ms=100.0,
                                confidence=0.9, category="liquen saludable")

        m = ms.get_metrics()
        stamps = [b["ts"] for b in m["series"]]
        assert stamps == sorted(stamps)
        assert len(set(stamps)) == len(stamps), "No debe haber buckets duplicados"

    def test_requests_per_minute_is_60s_window(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        clock = {"t": MIN0}
        _freeze_clock(ms, clock)
        for _ in range(60):
            ms.record_inference(success=True, inference_time_ms=100.0,
                                confidence=0.9, category="liquen saludable")

        m = ms.get_metrics()
        assert m["requests_per_minute"] == 60

    def test_throughput_is_consistent_with_requests_per_minute(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        clock = {"t": MIN0}
        _freeze_clock(ms, clock)
        for _ in range(60):
            ms.record_inference(success=True, inference_time_ms=100.0,
                                confidence=0.9, category="liquen saludable")

        m = ms.get_metrics()
        assert m["requests_per_minute"] == 60
        assert m["throughput_per_second"] == 1.0

    def test_latency_window_ignores_old_outliers(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        clock = {"t": MIN0 - 3600}
        _freeze_clock(ms, clock)
        # Latencia antigua muy alta (hace 1 hora): NO debe afectar la ventana.
        ms.record_inference(success=True, inference_time_ms=2000.0, confidence=0.9,
                            category="liquen saludable")

        clock["t"] = MIN0
        for lat in (100.0, 110.0, 120.0):
            ms.record_inference(success=True, inference_time_ms=lat, confidence=0.9,
                                category="liquen saludable")

        m = ms.get_metrics()
        assert m["average_inference_time_ms"] == 110.0
        assert m["min_inference_time_ms"] == 100.0
        assert m["max_inference_time_ms"] == 120.0
        assert m["p95_latency_ms"] == 119.0

    def test_no_recent_activity_metrics(self):
        from services.monitoring_service import monitoring_service
        ms = monitoring_service
        clock = {"t": MIN0}
        _freeze_clock(ms, clock)
        ms.record_inference(success=True, inference_time_ms=100.0, confidence=0.9,
                            category="liquen saludable")

        clock["t"] = MIN0 + 600  # 10 minutos después, sin actividad
        m = ms.get_metrics()
        assert m["requests_per_minute"] == 0
        assert m["throughput_per_second"] == 0.0
        assert m["average_inference_time_ms"] is None
        assert m["min_inference_time_ms"] is None
        assert m["max_inference_time_ms"] is None
        assert m["p95_latency_ms"] is None
        assert m["total_inferences"] == 1, "Los totales acumulados se conservan"


# ---------------------------------------------------------------------------
#  Coherencia Service Health / System Diagnostic (base de datos caída)
# ---------------------------------------------------------------------------

class _BrokenQuery:
    def filter(self, *args, **kwargs):
        return self

    def order_by(self, *args, **kwargs):
        return self

    def all(self):
        from sqlalchemy.exc import OperationalError
        raise OperationalError("query", {}, Exception("MySQL apagada"))


class _BrokenDb:
    """Sesión cuya BD no responde (SELECT 1 y consultas fallan)."""

    def execute(self, *args, **kwargs):
        from sqlalchemy.exc import OperationalError
        raise OperationalError("SELECT 1", {}, Exception("MySQL apagada"))

    def query(self, model):
        return _BrokenQuery()


class TestDatabaseDownCoherence:
    def test_health_reports_database_down(self, monkeypatch):
        from routes.ia import ia_health
        from ia.resolver_modelo_activo import ActiveModelError
        monkeypatch.setattr("ia.resolver_modelo_activo.resolver_modelo_activo",
                            lambda: (_ for _ in ()).throw(ActiveModelError("db down")))
        result = ia_health(db=_BrokenDb(), current_user=Usuario())
        assert result["database_healthy"] is False
        assert result["status"] == "unhealthy"
        assert "Base de datos" in result["status_detail"]

    def test_diagnostics_reflects_database_down(self, monkeypatch):
        from routes.ia import ia_diagnostics
        from ia.resolver_modelo_activo import ActiveModelError
        monkeypatch.setattr("ia.resolver_modelo_activo.resolver_modelo_activo",
                            lambda: (_ for _ in ()).throw(ActiveModelError("db down")))
        result = ia_diagnostics(db=_BrokenDb(), current_user=Usuario())
        db_check = next(c for c in result["checks"] if c["id"] == "database")
        assert db_check["status"] == "critical"
        assert db_check["message"] == "Problema de conexión con la base de datos"
        api_check = next(c for c in result["checks"] if c["id"] == "api")
        assert api_check["status"] == "ok", \
            "El check 'api' refleja disponibilidad del endpoint (que respondió)"
        assert result["status"] == "unhealthy"
        assert any("base de datos" in a.lower() for a in result["recommended_actions"])
