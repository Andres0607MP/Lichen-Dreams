"""Endpoints de monitoreo e observabilidad de la IA (Monitor IA).

Todos los endpoints están bajo ``/ia/*`` y protegidos con autenticación
de administrador (reutilizando ``require_admin`` del servicio de auth).

Endpoints:
- ``GET /ia/health``   — estado real de la IA (healthy / degraded / unhealthy).
- ``GET /ia/metrics``  — métricas acumuladas de inferencias (memoria).
- ``GET /ia/events``   — SSE en tiempo real de eventos de la IA.
"""
from __future__ import annotations

import json
import logging
import queue as queue_module
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Query
from fastapi.responses import EventSourceResponse
from sqlalchemy.orm import Session

from auth.auth_service import require_admin
from config.db import get_db
from models.core import Usuario, ModeloIA
from services.monitoring_service import monitoring_service

logger = logging.getLogger("lichdreams.ia_routes")
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("[%(asctime)s] [IA-HEALTH] %(message)s"))
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)

router = APIRouter()


def _safe_json(obj: Any) -> str:
    """Serializa a JSON con manejo de fechas SQLAlchemy."""
    try:
        if isinstance(obj, datetime):
            return obj.isoformat()
        if isinstance(obj, (list, tuple)):
            return json.dumps([_safe_json(item) for item in obj])
        return json.dumps(obj)
    except (TypeError, ValueError):
        return "{}"


def _get_model_metadata(db: Session) -> Dict[str, Any]:
    """Obtiene nombre, versión y estado del modelo activo registrado en BD."""
    from ia.resolver_modelo_activo import resolver_modelo_activo, ActiveModelError

    model_name: Optional[str] = None
    model_version: Optional[str] = None
    active_path: Optional[str] = None
    file_exists = False
    model_resolved = False

    try:
        active_path = str(resolver_modelo_activo())
        model_resolved = True
        from pathlib import Path
        file_exists = Path(active_path).exists()
    except ActiveModelError:
        model_resolved = False
    except Exception as exc:
        logger.warning("Error al resolver modelo activo: %s", exc)
        model_resolved = False

    # Buscar el registro ModeloIA activo que coincida con el archivo.
    try:
        from pathlib import Path as _Path
        active_name = _Path(active_path).name if active_path else None
        rows = (
            db.query(ModeloIA)
            .filter(ModeloIA.estado_modelo == "activo")
            .order_by(ModeloIA.id_modelo.desc())
            .all()
        )
        for row in rows:
            matched = False
            if row.observaciones and active_name:
                try:
                    archivo = json.loads(row.observaciones).get("archivo")
                    if archivo and _Path(str(archivo)).name == active_name:
                        matched = True
                except Exception:
                    pass
            if matched or (row.nombre_modelo and not model_name):
                model_name = row.nombre_modelo
                model_version = row.version
                break
        if not model_name and rows:
            model_name = rows[0].nombre_modelo
            model_version = rows[0].version
    except Exception as exc:
        logger.warning("Error al consultar ModeloIA: %s", exc)

    return {
        "model_name": model_name,
        "model_version": model_version,
        "active_path": active_path,
        "file_exists": file_exists,
        "model_resolved": model_resolved,
    }


def _get_tf_info() -> Dict[str, Optional[str]]:
    """Versión de TensorFlow/Keras y dispositivo disponible."""
    tf_version: Optional[str] = None
    keras_version: Optional[str] = None
    device: Optional[str] = None
    try:
        import tensorflow as tf
        tf_version = tf.__version__
        try:
            keras_version = tf.keras.__version__
        except Exception:
            import keras
            keras_version = getattr(keras, "__version__", None)
        try:
            gpus = tf.config.list_physical_devices("GPU")
            device = "GPU" if gpus else "CPU"
        except Exception:
            device = "CPU"
    except ImportError:
        pass
    return {
        "tensorflow_version": tf_version,
        "keras_version": keras_version,
        "device": device,
    }


@router.get("/health", summary="Health check de la IA")
def ia_health(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_admin),
) -> Dict[str, Any]:
    """Devuelve el estado real de salud de la IA.

    Estados posibles:
    - ``healthy``  — modelo activo resuelto, archivo existe y está cargado.
    - ``degraded`` — servicio activo pero el modelo aún no está cargado
                     (ruta válida pero ``_model is None``).
    - ``unhealthy`` — no se pudo resolver el modelo activo, el archivo no
                      existe o el modelo activo es inconsistente.

    No ejecuta ninguna inferencia.
    """
    from sqlalchemy import text
    from ia.modelos import lichen_classifier

    # Salud REAL de la base de datos (consulta mínima). Se comprueba ANTES
    # que el modelo: si la BD está caída, el estado no puede derivarse de un
    # valor cacheado ni de la resolución del modelo activo.
    database_healthy = False
    try:
        db.execute(text("SELECT 1"))
        database_healthy = True
    except Exception as exc:
        logger.warning("Database health check falló: %s", exc)

    meta = _get_model_metadata(db)
    tf_info = _get_tf_info()
    state = monitoring_service.get_model_state()

    model_loaded = getattr(lichen_classifier, "_model", None) is not None
    model_path = getattr(lichen_classifier, "_model_path", None)
    model_path_str = str(model_path) if model_path else (meta["active_path"])

    # Determinar estado. La BD es la fuente de verdad base: sin ella no hay
    # forma fiable de verificar el modelo activo ni la persistencia.
    if not database_healthy:
        status_level = "unhealthy"
        status_detail = "Base de datos no disponible; no se puede verificar el modelo activo."
    elif not meta["model_resolved"]:
        status_level = "unhealthy"
        status_detail = "No se pudo resolver el modelo activo (BD)."
    elif not meta["file_exists"]:
        status_level = "unhealthy"
        status_detail = "El archivo del modelo activo no existe en disco."
    elif model_loaded:
        status_level = "healthy"
        status_detail = "Modelo cargado y operativo."
    else:
        # Ruta válida pero modelo no cargado todavía.
        status_level = "degraded"
        status_detail = "Servicio activo, modelo no cargado todavía."

    uptime = None
    if model_loaded:
        uptime = state.get("model_uptime_seconds")
        if uptime is None:
            uptime = monitoring_service.get_uptime_seconds()
    else:
        uptime = monitoring_service.get_uptime_seconds()

    return {
        "status": status_level,
        "status_detail": status_detail,
        "model_loaded": model_loaded,
        "model_name": meta["model_name"],
        "model_version": meta["model_version"],
        "model_path": model_path_str,
        "classes": lichen_classifier.CLASS_NAMES,
        "tensorflow_version": tf_info["tensorflow_version"],
        "keras_version": tf_info["keras_version"],
        "device": tf_info["device"],
        "model_loaded_at": state.get("model_loaded_at"),
        "model_uptime_seconds": uptime,
        "reload_count": state.get("model_reload_count", 0),
        "database_healthy": database_healthy,
        "uptime_seconds": monitoring_service.get_uptime_seconds(),
        "timestamp": _now_iso(),
    }


@router.get("/diagnostics", summary="Diagnóstico determinístico de la IA")
def ia_diagnostics(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_admin),
) -> Dict[str, Any]:
    """Diagnóstico automático de la IA basado en reglas determinísticas.

    Combina el estado real de salud con las métricas acumuladas para producir:
    - ``score`` (0-100) para el indicador visual de salud.
    - ``status`` global (healthy / degraded / critical / unhealthy).
    - lista de ``checks`` (ok / warn / critical / info).
    - ``recommended_actions`` sugeridas.
    """
    health = ia_health(db=db, current_user=current_user)
    metrics = ia_metrics(db=db, current_user=current_user)

    checks: List[Dict[str, str]] = []
    actions: List[str] = []
    worst: str = "healthy"  # healthy < degraded < critical < unhealthy

    def check(ckid: str, status: str, message: str) -> None:
        checks.append({"id": ckid, "status": status, "message": message})

    # --- API ---
    check("api", "ok", "API respondiendo correctamente")

    # --- Modelo ---
    model_status = health.get("status")
    if model_status == "healthy":
        check("model", "ok", "Modelo cargado y operativo")
    elif model_status == "degraded":
        check("model", "warn", "Modelo aún no cargado (servicio activo)")
        worst = max(worst, "degraded", key=_severity_order)
    else:
        check("model", "critical", "Modelo no disponible")
        worst = max(worst, "unhealthy", key=_severity_order)
        actions.append("Verificar disponibilidad y archivo del modelo activo.")

    # --- Base de datos ---
    db_ok = health.get("database_healthy")
    if db_ok:
        check("database", "ok", "Conexión a la base de datos saludable")
    else:
        check("database", "critical", "Problema de conexión con la base de datos")
        worst = max(worst, "unhealthy", key=_severity_order)
        actions.append("Restaurar o verificar la conexión a la base de datos.")

    # --- Latencia ---
    avg_latency = metrics.get("average_inference_time_ms")
    if avg_latency is None:
        check("latency", "info", "Sin inferencias para evaluar latencia")
    elif avg_latency <= 400:
        check("latency", "ok", "Latencia de inferencia normal")
    elif avg_latency <= 800:
        check("latency", "warn", "Latencia de inferencia elevada")
        worst = max(worst, "degraded", key=_severity_order)
    else:
        check("latency", "critical", "Latencia de inferencia excesiva")
        worst = max(worst, "unhealthy", key=_severity_order)

    # --- Tasa de error ---
    error_rate = metrics.get("error_rate", 0.0)
    total = metrics.get("total_inferences", 0)
    if total == 0:
        check("errors", "info", "Sin actividad para evaluar tasa de error")
    elif error_rate <= 0.05:
        check("errors", "ok", "Tasa de error normal")
    elif error_rate <= 0.2:
        check("errors", "warn", "Tasa de error incrementada")
        worst = max(worst, "degraded", key=_severity_order)
        actions.append("Revisar los últimos errores de inferencia.")
    else:
        check("errors", "critical", "Tasa de error crítica")
        worst = max(worst, "unhealthy", key=_severity_order)
        actions.append("Revisar fallos de inferencia: posible problema del modelo o entrada.")

    # --- Confianza ---
    avg_conf = metrics.get("average_confidence")
    if avg_conf is None:
        check("confidence", "info", "Sin datos de confianza")
    elif avg_conf >= 0.7:
        check("confidence", "ok", "Confianza promedio normal")
    elif avg_conf >= 0.55:
        check("confidence", "warn", "Confianza por debajo del umbral")
        worst = max(worst, "degraded", key=_severity_order)
    else:
        check("confidence", "critical", "Confianza promedio críticamente baja")
        worst = max(worst, "unhealthy", key=_severity_order)

    n_critical = sum(1 for c in checks if c["status"] == "critical")
    n_warn = sum(1 for c in checks if c["status"] == "warn")
    score = max(min(100 - n_critical * 25 - n_warn * 8, 100), 0)

    if not actions:
        actions.append("No se requieren acciones correctivas.")

    return {
        "status": worst,
        "score": score,
        "checks": checks,
        "recommended_actions": actions,
        "rules_version": 1,
        "timestamp": _now_iso(),
    }


def _severity_order(status: str) -> int:
    return {
        "healthy": 0,
        "degraded": 1,
        "critical": 2,
        "unhealthy": 3,
    }.get(status, 0)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.get("/metrics", summary="Métricas de inferencia de la IA")
def ia_metrics(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_admin),
) -> Dict[str, Any]:
    """Devuelve las métricas acumuladas de inferencias en memoria."""
    return monitoring_service.get_metrics()


@router.get("/events", summary="Eventos en tiempo real (SSE)")
async def ia_events(
    request: Request,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_admin),
    limit: int | None = Query(default=None, ge=1, description="Limitar a N eventos (para polling de salud)"),
) -> EventSourceResponse:
    """Canal SSE de eventos de la IA.

    Cada conexión recibe su propia cola (no se comparten eventos entre
    suscriptores) y un *replay* de los últimos eventos históricos.

    Autenticación: el token JWT se pasa en el header ``Authorization``
    o como query param ``token`` (útil para clientes que no soportan
    headers en conexiones SSE).

    ``limit``: si se especifica, el stream se cierra después de N eventos.
    Útil para health-check polling o pruebas.
    """
    subscriber_q: queue_module.Queue = monitoring_service.subscribe()

    async def _is_disconnected() -> bool:
        try:
            return await request.is_disconnected()
        except Exception:
            return False

    async def event_stream():
        count = 0
        # Replay de eventos recientes para el nuevo suscriptor.
        for evt in monitoring_service.recent_events:
            if await _is_disconnected():
                break
            yield _format_sse(evt)
            count += 1
            if limit is not None and count >= limit:
                return

        # Stream en vivo.
        try:
            while True:
                if await _is_disconnected():
                    break
                if limit is not None and count >= limit:
                    return
                try:
                    evt = subscriber_q.get_nowait()
                    yield _format_sse(evt)
                    count += 1
                except queue_module.Empty:
                    # Heartbeat periódico para mantener viva la conexión.
                    yield _format_sse({"type": "heartbeat", "data": {"ts": _now_iso()}})
                    await asyncio_sleep(1.0)
        finally:
            monitoring_service.unsubscribe(subscriber_q)

    return EventSourceResponse(event_stream())


def _format_sse(event: Dict[str, Any]) -> str:
    """Formatea un evento como mensaje SSE válido."""
    event_type = event.get("type", "message")
    data = event.get("data", {})
    # Asegurar que 'timestamp' esté siempre presente en data.
    if isinstance(data, dict) and "timestamp" not in data:
        data = {**data, "timestamp": _now_iso()}
    try:
        data_str = json.dumps(data, default=str)
    except (TypeError, ValueError):
        data_str = "{}"
    return f"event: {event_type}\ndata: {data_str}\n\n"


async def asyncio_sleep(seconds: float):
    import asyncio
    await asyncio.sleep(seconds)
