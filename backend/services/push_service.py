"""Servicio de envío de notificaciones push mediante Firebase Cloud Messaging (FCM).

Inicializa el SDK de Firebase Admin de forma segura usando la variable de entorno
``FCM_SERVICE_ACCOUNT_JSON`` (JSON de la service account, configurado como secret
en el entorno de producción — nunca se comite al repositorio).

Cuando la variable no está definida o es inválida, el servicio se inicializa en
modo "deshabilitado": las llamadas a :meth:`send_to_token` devuelven
``FcmResult.disabled`` sin lanzar excepciones, de modo que el flujo de creación
de notificaciones en BD nunca se rompe.
"""

import json
import logging
from dataclasses import dataclass
from enum import Enum
from typing import Any, Dict, Optional

from config.settings import FCM_SERVICE_ACCOUNT_JSON, FCM_ENABLED

logger = logging.getLogger("lichdreams.push")

_dataclass_sentinel = object()


class FcmResult(str, Enum):
    ok = "ok"
    invalid_token = "invalid_token"
    failed = "failed"
    disabled = "disabled"


@dataclass
class FcmSendResult:
    result: FcmResult
    message_id: Optional[str] = None
    error: Optional[str] = None


_app = None
_initialized = _dataclass_sentinel  # type: Any


def _get_app():
    """Devuelve la aplicación de Firebase Admin inicializada (o None si no está habilitada)."""
    global _app, _initialized

    if _initialized is not _dataclass_sentinel:
        return _app

    _initialized = None  # marca como "en proceso"

    if not FCM_ENABLED:
        logger.info("[FCM] Firebase Admin no configurado (FCM_SERVICE_ACCOUNT_JSON no definida). "
                    "El envío de push está deshabilitado.")
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        service_account_info: Dict[str, Any]
        try:
            service_account_info = json.loads(FCM_SERVICE_ACCOUNT_JSON)
        except (json.JSONDecodeError, TypeError) as exc:
            logger.error(f"[FCM] FCM_SERVICE_ACCOUNT_JSON no es JSON válido: {exc}")
            return None

        if _app is None and not firebase_admin._apps:
            cred = credentials.Certificate(service_account_info)
            _app = firebase_admin.initialize_app(cred)
            logger.info("[FCM] Firebase Admin inicializado correctamente.")
        elif _app is None:
            _app = firebase_admin.get_app()
    except Exception as exc:
        logger.error(f"[FCM] Error inicializando Firebase Admin: {exc}")
        _app = None

    _initialized = _app
    return _app


def _ensure_app():
    """Fuerza la inicialización lazy y devuelve el app o None."""
    if _initialized is _dataclass_sentinel:
        return _get_app()
    return _app


def send_to_token(
    token: str,
    data: Dict[str, str],
    title: Optional[str] = None,
    body: Optional[str] = None,
) -> FcmSendResult:
    """Envía un mensaje de datos a un token FCM.

    El mensaje se envía como *data-only* (sin la clave ``notification``),
    permitiendo que la aplicación Flutter lo maneje con ``onMessage`` /
    ``onBackgroundMessage`` y muestre la notificación local con el canal y
    configuración deseada.

    Retorna :class:`FcmSendResult` con el estado del envío. Si el token es
    inválido o no registrado (``UNREGISTERED`` / ``INVALID_ARGUMENT``), el
    caller puede limpiarlo de la BD.
    """
    if _initialized is _dataclass_sentinel:
        _get_app()

    if _app is None:
        return FcmSendResult(result=FcmResult.disabled)

    try:
        from firebase_admin import messaging
    except ImportError:
        logger.debug("[FCM] firebase_admin no está instalado.")
        return FcmSendResult(result=FcmResult.disabled)

    android_notification = messaging.AndroidNotification(
        icon="ic_notification",
        color="#4F7A45",
        title=title,
        body=body,
    )

    android_config = messaging.AndroidConfig(
        priority="high",
        notification=android_notification,
    )

    try:
        message = messaging.Message(
            token=token,
            data={k: str(v) for k, v in data.items()},
            android=android_config,
        )
        message_id = messaging.send(message)
        return FcmSendResult(result=FcmResult.ok, message_id=message_id)
    except Exception as exc:
        error_str = str(exc)

        if "UNREGISTERED" in error_str or "SenderId mismatch" in error_str:
            logger.warning(f"[FCM] Token inválido o no registrado: {token[:30]}...")
            return FcmSendResult(
                result=FcmResult.invalid_token,
                error=error_str,
            )

        logger.error(f"[FCM] Error enviando a token {token[:30]}...: {error_str}")
        return FcmSendResult(result=FcmResult.failed, error=error_str)


def clear_invalid_token(db, token: str):
    """Limpia un token FCM inválido de las sesiones activas en la BD.

    Marca ``fcm_token = NULL`` para todas las sesiones activas que tengan
    exactamente este token. Esto evita acumulación de tokens muertos.
    """
    try:
        from models.core import Sesion

        affected = db.query(Sesion).filter(
            Sesion.fcm_token == token,
            Sesion.estado_sesion == "active",
        ).update(
            {Sesion.fcm_token: None},
            synchronize_session=False,
        )
        db.commit()
        if affected:
            logger.info(f"[FCM] Limpiado token inválido de {affected} sesión(es).")
    except Exception as exc:
        db.rollback()
        logger.warning(f"[FCM] No se pudo limpiar el token inválido: {exc}")
