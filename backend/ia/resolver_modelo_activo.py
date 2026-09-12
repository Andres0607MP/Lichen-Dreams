"""Resolver estricto del modelo activo (anti-fallback silencioso).

Politica (requisito #21 del pipeline V7):
- El modelo de produccion DEBE corresponder al modelo activo registrado en BD
  (tabla ModeloIA, estado_modelo == 'activo'), con un archivo .keras que exista
  en disco.
- Si no se puede resolver de forma SEGURA, se FALLA explicitamente (excepcion),
  en lugar de seleccionar silenciosamente el ultimo .keras del directorio.
- Soporta modelos almacenados en R2: si observaciones.archivo empieza con
  'models/' se descarga desde R2 al directorio local de modelos.

Uso en el pipeline/registro de V7:
    from ia.resolver_modelo_activo import resolver_modelo_activo
    path = resolver_modelo_activo()          # -> Path o lanza ActiveModelError
    path = resolver_modelo_activo(version="v3.0")   # modelo de una version concreta

No toca lichen_classifier.py (que conserva su logica actual para no romper la
resolucion dinamica existente). Este modulo es la referencia estricta para el
registro/activacion de V7 y para decidir si V7 puede reemplazar a V3.
"""
from pathlib import Path
import json as _json
import threading

# Lock para evitar descargas concurrentes del mismo modelo
_download_lock = threading.Lock()


class ActiveModelError(RuntimeError):
    """Se levanta cuando no se puede resolver el modelo activo de forma segura."""


PROJECT_ROOT = Path(__file__).resolve().parent
MODEL_DIR = PROJECT_ROOT / "modelos"
MODEL_PREFIX = "models/"  # Prefijo en R2 para modelos


def _info(ruta):
    """Extrae el path del archivo desde observaciones (JSON)."""
    if not ruta:
        return None
    try:
        info = _json.loads(ruta)
    except Exception:
        return None
    return info.get("archivo")


def _download_model_from_r2(key: str, local_path: Path) -> None:
    """Descarga un modelo desde R2 al filesystem local."""
    # Import local para evitar dependencias circulares
    from services.upload_service import _get_r2_client, R2_BUCKET_NAME
    from botocore.exceptions import ClientError

    try:
        client = _get_r2_client()
        # Asegurar directorio padre
        local_path.parent.mkdir(parents=True, exist_ok=True)
        # Descargar
        client.download_file(R2_BUCKET_NAME, key, str(local_path))
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            raise ActiveModelError(f"Modelo no encontrado en R2: {key}")
        raise ActiveModelError(f"Error descargando modelo desde R2: {e}")


def _resolve_model_path_local(archivo: str) -> Path:
    """
    Resuelve la ruta local del modelo.
    Si archivo empieza con 'models/', se trata como clave R2 y se descarga si no existe.
    """
    p = Path(archivo)
    if not p.is_absolute():
        # Ruta relativa: buscar en MODEL_DIR
        p = MODEL_DIR / archivo

    # Si ya existe localmente, devolverlo
    if p.exists():
        return p

    # Si la clave empieza con MODEL_PREFIX, intentar descargar de R2
    if archivo.startswith(MODEL_PREFIX):
        with _download_lock:
            # Doble comprobación tras adquirir lock
            if p.exists():
                return p
            _download_model_from_r2(archivo, p)
            if not p.exists():
                raise ActiveModelError(f"Falló la descarga del modelo: {archivo}")
            return p

    # No es una clave R2 conocida y no existe localmente
    raise ActiveModelError(
        f"El modelo registrado apunta a un archivo inexistente: {archivo}"
    )


def resolver_modelo_activo(version=None):
    """Devuelve el Path del modelo activo registrado (o el de la version pedida).

    Reglas:
    - Consulta BD (ModeloIA). Si version se omite, elige el activo mas
      reciente (estado='activo'); si version se pasa, busca esa version
      concreta (debe estar registrada).
    - Si observaciones.archivo empieza con 'models/', se descarga de R2.
    - Si la BD no puede consultarse o no hay registro valido -> ActiveModelError
      (NO fallback silencioso al ultimo .keras del directorio).
    """
    try:
        from config.db import SessionLocal
        from models.core import ModeloIA
    except Exception as e:
        raise ActiveModelError(f"no se pudo importar acceso a BD: {e}") from e

    try:
        with SessionLocal() as db:
            query = db.query(ModeloIA)
            if version is not None:
                query = query.filter(ModeloIA.version == version)
            else:
                query = query.filter(ModeloIA.estado_modelo == "activo")
            filas = query.order_by(ModeloIA.id_modelo.desc()).all()
    except Exception as e:
        raise ActiveModelError(f"no se pudo consultar la BD de modelos: {e}") from e

    if not filas:
        msg = (f"no hay modelo registrado {'con version ' + version if version else 'activo'}; "
               "no se selecciona un archivo .keras automaticamente")
        raise ActiveModelError(msg)

    for fila in filas:
        archivo = _info(fila.observaciones)
        if not archivo:
            continue
        try:
            return _resolve_model_path_local(archivo)
        except ActiveModelError:
            raise

    raise ActiveModelError("ningún registro válido con archivo existente en disco")


def resolver_mejor_version(*versiones):
    """Devuelve el path de la primera version disponible (para comparaciones).

    NO decide por si sola la activacion; solo localiza modelos existentes para
    evaluar (p. ej. comparar V3 vs V7). Si ninguna existe, ActiveModelError.
    """
    errores = []
    for v in versiones:
        try:
            return resolver_modelo_activo(version=v)
        except ActiveModelError as e:
            errores.append(str(e))
    raise ActiveModelError("ninguna version solicitada está registrada: " + "; ".join(errores))