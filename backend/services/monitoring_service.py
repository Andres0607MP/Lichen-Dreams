"""Servicio centralizado de monitoreo e instrumentación de la IA.

Diseñado para ser:
- **Thread-safe**: usa locks para métricas y suscriptores.
- **Resiliente**: NUNCA debe provocar que una inferencia falle. Cada método
  de registro envuelve su lógica en ``try/except`` para que un error en el
  monitoreo sea silencioso.
- **Extensible**: la API está pensada para poder reemplazarse fácilmente por
  Prometheus u otro backend sin tocar ``AnalysisService``.

Arquitectura de eventos:
- Cada suscripción SSE crea su propia ``queue.Queue`` (NO se comparte una
  cola global). ``publish_event`` reenvía el evento a todas las colas
  activas y la guarda en un histórico circular para *replay* a nuevos
  suscriptores.
"""
from __future__ import annotations

import json
import logging
import queue
import threading
import time
from collections import deque
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

logger = logging.getLogger("lichdreams.monitoring")
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("[%(asctime)s] [MONITORING] %(message)s"))
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _safe(fn, *args, **kwargs):
    """Ejecuta *fn* ignorando silenciosamente cualquier error."""
    try:
        return fn(*args, **kwargs)
    except Exception as exc:  # pragma: no cover - defensivo
        logger.warning("Monitoring error (ignored): %s", exc)
        return None


class MonitoringService:
    """Singleton de monitoreo en memoria."""

    _instance: Optional["MonitoringService"] = None
    _init_lock = threading.Lock()

    def __new__(cls) -> "MonitoringService":
        if cls._instance is None:
            with cls._init_lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self) -> None:
        if getattr(self, "_initialized", False):
            return
        self._initialized = True

        self._metrics_lock = threading.Lock()
        self._events_lock = threading.Lock()

        # ---- Métricas de inferencia ----
        self._total_inferences = 0
        self._successful_inferences = 0
        self._failed_inferences = 0
        self._active_inferences = 0
        self._inference_times_ms: List[float] = []
        self._min_time_ms: Optional[float] = None
        self._max_time_ms: Optional[float] = None
        self._sum_time_ms = 0.0
        self._confidences: List[float] = []
        self._sum_confidence = 0.0
        self._last_inference_at: Optional[str] = None
        self._last_error: Optional[str] = None
        self._last_error_at: Optional[str] = None

        # ---- Distribución de predicciones por categoría ----
        self._pred_healthy = 0
        self._pred_critical = 0
        self._pred_unknown = 0

        # ---- Ventana de tiempo (req/min) y serie temporal por minuto ----
        self._request_times: deque = deque(maxlen=2000)
        # Muestras recientes (epoch, latencia_ms) para métricas de ventana 60 s.
        self._window_samples: deque = deque(maxlen=5000)
        self._buckets: deque = deque(maxlen=60)
        self._bucket_start: Optional[float] = None
        self._bucket_requests = 0
        self._bucket_success = 0
        self._bucket_failed = 0
        self._bucket_sum_latency = 0.0
        self._bucket_latencies: List[float] = []
        self._bucket_sum_confidence = 0.0
        self._bucket_confidences: List[float] = []
        self._bucket_pred_healthy = 0
        self._bucket_pred_critical = 0
        self._bucket_pred_unknown = 0

        # Reloj inyectable (tests): por defecto time.time() real.
        self._now = time.time

        # ---- Estado del modelo ----
        self._model_loaded_at: Optional[str] = None
        self._model_loaded_at_epoch: Optional[float] = None
        self._model_reload_count = 0
        self._model_path: Optional[str] = None
        self._model_version: Optional[str] = None

        # ---- Temporada de arranque ----
        self._start_epoch = time.time()

        # ---- Bus de eventos ----
        self._subscribers: List[queue.Queue] = []
        self._event_history: deque = deque(maxlen=200)

    # ------------------------------------------------------------------ #
    #  Suscripción SSE
    # ------------------------------------------------------------------ #
    def subscribe(self) -> queue.Queue:
        """Registra una nueva suscripción y devuelve su cola thread-safe."""
        with self._events_lock:
            q: queue.Queue = queue.Queue(maxsize=200)
            self._subscribers.append(q)
            logger.debug("Suscriptor registrado (%d activos)", len(self._subscribers))
            return q

    def unsubscribe(self, q: queue.Queue) -> None:
        with self._events_lock:
            try:
                self._subscribers.remove(q)
                logger.debug("Suscriptor eliminado (%d activos)", len(self._subscribers))
            except ValueError:
                pass

    @property
    def recent_events(self) -> List[Dict[str, Any]]:
        """Histórico de eventos (máximo 200) para *replay* a nuevos suscriptores."""
        with self._events_lock:
            return [dict(e) for e in self._event_history]

    def publish_event(self, event_type: str, data: Optional[Dict[str, Any]] = None) -> None:
        """Publica un evento a todas las suscripciones activas y al histórico."""
        if data is None:
            data = {}
        data.setdefault("timestamp", _now_iso())
        event = {"type": event_type, "data": data}

        with self._events_lock:
            self._event_history.append(event)
            subscribers = list(self._subscribers)

        for q in subscribers:
            try:
                q.put_nowait(event)
            except queue.Full:
                # El suscriptor no consume rápido suficiente; se descarta
                # el evento para esa cola sin bloquear a los demás.
                pass

    # ------------------------------------------------------------------ #
    #  Registro de eventos de inferencia / análisis
    # ------------------------------------------------------------------ #
    def record_analysis_started(self, analysis_id: Optional[int] = None) -> None:
        """Marca el inicio de un intento de análisis (predicción)."""
        with self._metrics_lock:
            self._active_inferences += 1
        event_data: Dict[str, Any] = {"active_inferences": self._active_inferences}
        if analysis_id is not None:
            event_data["analysis_id"] = analysis_id
        self.publish_event("analysis_started", event_data)

    def record_inference(
        self,
        *,
        success: bool,
        inference_time_ms: Optional[float] = None,
        confidence: Optional[float] = None,
        category: Optional[str] = None,
        analysis_id: Optional[int] = None,
        error_type: Optional[str] = None,
    ) -> None:
        """Registra el resultado de una inferencia individual.

        Este método es el único punto de entrada para actualizar métricas de
        inferencia; se llma desde ``AnalysisService`` tras cada ``predict()``.
        """
        _safe(self._record_inference_impl, success, inference_time_ms, confidence,
              category, analysis_id, error_type)

    def _record_inference_impl(
        self,
        success: bool,
        inference_time_ms: Optional[float],
        confidence: Optional[float],
        category: Optional[str],
        analysis_id: Optional[int],
        error_type: Optional[str],
    ) -> None:
        now_epoch = self._now()
        bucket_key = int(now_epoch // 60) * 60.0

        with self._metrics_lock:
            self._advance_bucket_locked(bucket_key)

            self._total_inferences += 1
            self._active_inferences = max(0, self._active_inferences - 1)
            self._last_inference_at = _now_iso()
            self._request_times.append(now_epoch)

            self._bucket_requests += 1
            if success:
                self._successful_inferences += 1
                self._bucket_success += 1
            else:
                self._failed_inferences += 1
                self._bucket_failed += 1
                if error_type:
                    self._last_error = error_type
                    self._last_error_at = _now_iso()

            if inference_time_ms is not None:
                self._sum_time_ms += inference_time_ms
                self._inference_times_ms.append(inference_time_ms)
                self._window_samples.append((now_epoch, inference_time_ms))
                self._bucket_sum_latency += inference_time_ms
                self._bucket_latencies.append(inference_time_ms)
                if self._min_time_ms is None or inference_time_ms < self._min_time_ms:
                    self._min_time_ms = inference_time_ms
                if self._max_time_ms is None or inference_time_ms > self._max_time_ms:
                    self._max_time_ms = inference_time_ms

            if confidence is not None:
                self._sum_confidence += confidence
                self._confidences.append(confidence)
                self._bucket_sum_confidence += confidence
                self._bucket_confidences.append(confidence)

            # Distribución de predicciones por categoría (clases del modelo).
            pred_kind = self._classify_category(category)
            if pred_kind == "healthy":
                self._pred_healthy += 1
                self._bucket_pred_healthy += 1
            elif pred_kind == "critical":
                self._pred_critical += 1
                self._bucket_pred_critical += 1
            else:
                self._pred_unknown += 1
                self._bucket_pred_unknown += 1

            active = self._active_inferences

        event_data: Dict[str, Any] = {
            "analysis_id": analysis_id,
            "active_inferences": active,
        }
        if inference_time_ms is not None:
            event_data["processing_time_ms"] = round(inference_time_ms, 2)

        if success:
            if confidence is not None:
                event_data["confidence"] = round(confidence, 4)
            if category is not None:
                event_data["category"] = category
            self.publish_event("analysis_completed", event_data)
        else:
            if error_type:
                event_data["error_type"] = error_type
            self.publish_event("analysis_failed", event_data)

    @staticmethod
    def _classify_category(category: Optional[str]) -> str:
        """Clasifica una categoría en healthy / critical / unknown."""
        if not category:
            return "unknown"
        c = category.lower()
        if "saludable" in c or "healthy" in c or "sano" in c:
            return "healthy"
        if "contaminad" in c or "afectad" in c or "critical" in c or "critical" in c or "crítico" in c:
            return "critical"
        return "unknown"

    def _advance_bucket_locked(self, target_key: float) -> None:
        """Avanza la serie hasta el minuto `target_key`.

        Cierra el cubo actual (aunque esté vacío) y completa los minutos
        intermedios SIN actividad con buckets de ``requests = 0``, de modo que
        la serie **nunca comprime** el eje temporal. `target_key` debe ser un
        minuto alineado UTC (nunca futuro).
        """
        if self._bucket_start is None:
            self._bucket_start = target_key
            return
        if self._bucket_start == target_key:
            return
        old_start = self._bucket_start
        self._flush_bucket_locked()
        cursor = old_start + 60.0
        while cursor < target_key:
            self._append_empty_bucket(cursor)
            cursor += 60.0
        self._bucket_start = target_key

    def _bucket_to_dict_locked(self, start: float) -> Dict[str, Any]:
        latencies = self._bucket_latencies
        confidences = self._bucket_confidences
        return {
            "ts": datetime.fromtimestamp(start, tz=timezone.utc).isoformat(),
            "requests": self._bucket_requests,
            "success": self._bucket_success,
            "failed": self._bucket_failed,
            "avg_latency_ms": round(sum(latencies) / len(latencies), 2) if latencies else None,
            "min_latency_ms": round(min(latencies), 2) if latencies else None,
            "max_latency_ms": round(max(latencies), 2) if latencies else None,
            "p95_latency_ms": round(self._percentile(sorted(latencies), 95), 2) if latencies else None,
            "avg_confidence": round(sum(confidences) / len(confidences), 4) if confidences else None,
            "healthy": self._bucket_pred_healthy,
            "critical": self._bucket_pred_critical,
            "unknown": self._bucket_pred_unknown,
        }

    def _flush_bucket_locked(self) -> None:
        """Cierra el cubo actual y lo agrega a la serie (incluso si quedó vacío)."""
        if self._bucket_start is None:
            return
        self._buckets.append(self._bucket_to_dict_locked(self._bucket_start))
        self._bucket_start = None
        self._bucket_requests = 0
        self._bucket_success = 0
        self._bucket_failed = 0
        self._bucket_sum_latency = 0.0
        self._bucket_latencies.clear()
        self._bucket_sum_confidence = 0.0
        self._bucket_confidences.clear()
        self._bucket_pred_healthy = 0
        self._bucket_pred_critical = 0
        self._bucket_pred_unknown = 0

    def _append_empty_bucket(self, start: float) -> None:
        """Agrega un bucket de un minuto sin actividad (requests = 0)."""
        prev_req = self._bucket_requests
        prev_success = self._bucket_success
        prev_failed = self._bucket_failed
        prev_lat = self._bucket_latencies
        prev_conf = self._bucket_confidences
        prev_ph = self._bucket_pred_healthy
        prev_pc = self._bucket_pred_critical
        prev_pu = self._bucket_pred_unknown
        self._bucket_requests = 0
        self._bucket_success = 0
        self._bucket_failed = 0
        self._bucket_latencies = []
        self._bucket_confidences = []
        self._bucket_pred_healthy = 0
        self._bucket_pred_critical = 0
        self._bucket_pred_unknown = 0
        self._buckets.append(self._bucket_to_dict_locked(start))
        self._bucket_requests = prev_req
        self._bucket_success = prev_success
        self._bucket_failed = prev_failed
        self._bucket_latencies = prev_lat
        self._bucket_confidences = prev_conf
        self._bucket_pred_healthy = prev_ph
        self._bucket_pred_critical = prev_pc
        self._bucket_pred_unknown = prev_pu

    @staticmethod
    def _percentile(sorted_values: List[float], percentile: float) -> float:
        if not sorted_values:
            return 0.0
        if len(sorted_values) == 1:
            return sorted_values[0]
        rank = (percentile / 100.0) * (len(sorted_values) - 1)
        low = int(rank)
        high = min(low + 1, len(sorted_values) - 1)
        frac = rank - low
        return sorted_values[low] * (1 - frac) + sorted_values[high] * frac

    # ------------------------------------------------------------------ #
    #  Registro de eventos del modelo
    # ------------------------------------------------------------------ #
    def record_model_loaded(self, model_path: str) -> None:
        _safe(self._record_model_loaded_impl, model_path, is_reload=False)

    def record_model_reloaded(self, model_path: str) -> None:
        _safe(self._record_model_loaded_impl, model_path, is_reload=True)

    def _record_model_loaded_impl(self, model_path: str, *, is_reload: bool) -> None:
        with self._metrics_lock:
            now = time.time()
            self._model_loaded_at_epoch = now
            self._model_loaded_at = _now_iso()
            if model_path:
                import os as _os
                self._model_path = model_path
                self._model_version = _os.path.basename(model_path) or model_path
            if is_reload:
                self._model_reload_count += 1

        if is_reload:
            self.publish_event("model_reloaded", {
                "model_path": model_path,
                "reload_count": self._model_reload_count,
            })
        else:
            self.publish_event("model_loaded", {
                "model_path": model_path,
                "model_version": self._model_version,
            })

    # ------------------------------------------------------------------ #
    #  Lectura de métricas
    # ------------------------------------------------------------------ #
    def get_metrics(self) -> Dict[str, Any]:
        with self._metrics_lock:
            total = self._total_inferences
            successful = self._successful_inferences
            failed = self._failed_inferences
            confidences = list(self._confidences)

            error_rate = (failed / total) if total > 0 else 0.0
            avg_conf = (self._sum_confidence / len(confidences)) if confidences else None

            # Ventana reciente de 60 segundos (fuente única de requests/latencia).
            now = self._now()
            window_start = now - 60.0
            requests_last_minute = sum(1 for t in self._request_times if t >= window_start)
            window_latencies = [
                latency for (ts, latency) in self._window_samples if ts >= window_start
            ]
            if window_latencies:
                avg_latency = sum(window_latencies) / len(window_latencies)
                min_latency = min(window_latencies)
                max_latency = max(window_latencies)
                p95_latency = self._percentile(sorted(window_latencies), 95)
            else:
                avg_latency = min_latency = max_latency = p95_latency = None

            throughput = requests_last_minute / 60.0

            # Serie temporal: cierra los minutos COMPLETOS (con o sin actividad,
            # backfilling minutos vacíos) y expone el minuto actual como último
            # bucket "abierto".
            current_minute = int(now // 60) * 60.0
            self._advance_bucket_locked(current_minute)
            series = list(self._buckets)
            if self._bucket_start == current_minute:
                series.append(self._bucket_to_dict_locked(current_minute))
            # Aproximadamente 60 buckets: descartar el más antiguo si se excede.
            if len(series) > 60:
                series = series[-60:]

        return {
            "total_inferences": total,
            "successful_inferences": successful,
            "failed_inferences": failed,
            "active_inferences": self._active_inferences,
            "average_inference_time_ms": round(avg_latency, 2) if avg_latency is not None else None,
            "min_inference_time_ms": round(min_latency, 2) if min_latency is not None else None,
            "max_inference_time_ms": round(max_latency, 2) if max_latency is not None else None,
            "p95_latency_ms": round(p95_latency, 2) if p95_latency is not None else None,
            "error_rate": round(error_rate, 4),
            "average_confidence": round(avg_conf, 4) if avg_conf is not None else None,
            "last_inference_timestamp": self._last_inference_at,
            "last_error": self._last_error,
            "last_error_timestamp": self._last_error_at,
            "requests_per_minute": requests_last_minute,
            "throughput_per_second": round(throughput, 4),
            "predictions": {
                "healthy": self._pred_healthy,
                "critical": self._pred_critical,
                "unknown": self._pred_unknown,
            },
            "series": series,
        }

    def get_model_state(self) -> Dict[str, Any]:
        with self._metrics_lock:
            loaded_at = self._model_loaded_at
            loaded_epoch = self._model_loaded_at_epoch
            uptime = None
            if loaded_epoch is not None:
                uptime = round(time.time() - loaded_epoch, 1)
            return {
                "model_loaded_at": loaded_at,
                "model_path": self._model_path,
                "model_version": self._model_version,
                "model_reload_count": self._model_reload_count,
                "model_uptime_seconds": uptime,
            }

    def get_uptime_seconds(self) -> float:
        return round(time.time() - self._start_epoch, 1)

    def reset(self) -> None:
        """Reinicia todo el estado acumulado (usado en tests y warm-up)."""
        with self._metrics_lock:
            self._total_inferences = 0
            self._successful_inferences = 0
            self._failed_inferences = 0
            self._active_inferences = 0
            self._inference_times_ms.clear()
            self._min_time_ms = None
            self._max_time_ms = None
            self._sum_time_ms = 0.0
            self._confidences.clear()
            self._sum_confidence = 0.0
            self._last_inference_at = None
            self._last_error = None
            self._last_error_at = None
            self._pred_healthy = 0
            self._pred_critical = 0
            self._pred_unknown = 0
            self._request_times.clear()
            self._window_samples.clear()
            self._buckets.clear()
            self._bucket_start = None
            self._bucket_requests = 0
            self._bucket_success = 0
            self._bucket_failed = 0
            self._bucket_sum_latency = 0.0
            self._bucket_latencies.clear()
            self._bucket_sum_confidence = 0.0
            self._bucket_confidences.clear()
            self._bucket_pred_healthy = 0
            self._bucket_pred_critical = 0
            self._bucket_pred_unknown = 0
            self._model_loaded_at = None
            self._model_loaded_at_epoch = None
            self._model_reload_count = 0
            self._model_path = None
            self._model_version = None
        with self._events_lock:
            self._event_history.clear()
            self._subscribers.clear()


# Instancia global lista para import directo en rutas y servicios.
monitoring_service = MonitoringService()
