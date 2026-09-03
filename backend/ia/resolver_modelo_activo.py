"""Resolver estricto del modelo activo (anti-fallback silencioso).

Politica (requisito #21 del pipeline V7):
- El modelo de produccion DEBE corresponder al modelo activo registrado en BD
  (tabla ModeloIA, estado_modelo == 'activo'), con un archivo .keras que exista
  en disco.
- Si no se puede resolver de forma SEGURA, se FALLA explicitamente (excepcion),
  en lugar de seleccionar silenciosamente el ultimo .keras del directorio.

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


class ActiveModelError(RuntimeError):
    """Se levanta cuando no se puede resolver el modelo activo de forma segura."""


PROJECT_ROOT = Path(__file__).resolve().parent
MODEL_DIR = PROJECT_ROOT / "ia" / "modelos"


def _info(ruta):
    """Extrae el path del archivo desde observaciones (JSON)."""
    if not ruta:
        return None
    try:
        info = _json.loads(ruta)
    except Exception:
        return None
    return info.get("archivo")


def resolver_modelo_activo(version=None):
    """Devuelve el Path del modelo activo registrado (o el de la version pedida).

    Reglas:
    - Consulta BD (ModeloIA). Si version se omite, elige el activo mas
      reciente (estado='activo'); si version se pasa, busca esa version
      concreta (debe estar registrada).
    - Requiere que el archivo referenciado exista en disco.
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
        p = Path(archivo)
        if p.exists():
            return p
        raise ActiveModelError(
            f"el modelo registrado {fila.version!r} apunta a un archivo inexistente: {archivo}")

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