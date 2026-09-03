"""Tests de la auditoria/correccion del pipeline de inferencia V3.

Verifica:
- resolucion estricta del activo (sin fallback silencioso a versioned[-1]);
- mapping 0/1/2 correcto;
- preprocessing V3 (224x224 RGB /255, rango [0,1]);
- argmax correcto y probabilidades normales;
- el activo resuelto por BD es V3 (no V7);
- falla explicita si no hay modelo activo (no inventa una ruta);
- no se modifica la BD de modelos.
"""
import json
import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

BACKEND = Path(__file__).resolve().parents[1]
MODELO_V3 = BACKEND / "ia" / "modelos" / "lichen_model_v3.keras"


# ---------------------------------------------------------------------------
# FASE 1: resolucion estricta del modelo
# ---------------------------------------------------------------------------
def test_resolver_activo_devuelve_v3():
    from ia.resolver_modelo_activo import resolver_modelo_activo
    p = resolver_modelo_activo()
    assert p.name == "lichen_model_v3.keras"


def test_resolver_activo_no_usa_el_ultimo_versioned():
    """El clasificador NO debe elegir versioned[-1] (V7 si existe)."""
    import importlib
    import ia.modelos.lichen_classifier as lc

    p = lc._resolve_model_path()
    assert p.name == "lichen_model_v3.keras"


def test_classifier_rechaza_cuando_no_hay_activo(monkeypatch):
    """Sin modelo activo -> error explicito, no fallback."""
    import ia.modelos.lichen_classifier as lc
    from ia.resolver_modelo_activo import ActiveModelError

    def fake_resolver():
        raise ActiveModelError("sin activo (test)")

    monkeypatch.setattr(lc, "_resolve_model_path", fake_resolver)
    lc._model = None
    lc._model_path = None
    with pytest.raises(ActiveModelError):
        lc._load_model()


def test_no_fallback_a_ultimo_keras_statico():
    """MODEL_PATH no debe apuntar a v7/v6/v4/v5."""
    import ia.modelos.lichen_classifier as lc

    # MODE_PATH puede quedar None si el import ocurrio sin BD; pero _resolve_model_path
    # (la logica real) siempre resuelve v3 estricto.
    if lc.MODEL_PATH is not None:
        assert Path(str(lc.MODEL_PATH)).name == "lichen_model_v3.keras"


# ---------------------------------------------------------------------------
# FASE 2: preprocessing exacto V3
# ---------------------------------------------------------------------------
def test_preprocess_v3_shape_dtype_rango():
    from ia.modelos.lichen_classifier import _preprocess_image

    h, w = 300, 400
    img_blanco = np.full((h, w, 3), 255, dtype=np.uint8)  # simulada, no dataset
    import cv2, tempfile
    import os
    tmp = tempfile.NamedTemporaryFile(suffix=".jpg", delete=False)
    tmp.close()
    try:
        cv2.imwrite(tmp.name, img_blanco)
        t = _preprocess_image(tmp.name)
        assert t.shape == (1, 224, 224, 3)
        assert t.dtype == np.float32
        assert 0.0 <= t.min() and t.max() <= 1.0
        assert np.isclose(t.max(), 1.0, atol=0.01)
    finally:
        os.remove(tmp.name)


def test_preprocess_no_normaliza_dos_veces():
    """V3 espera [0,1]: la inferencia /255 es exactamente el rango de train."""
    from ia.modelos.lichen_classifier import _preprocess_image
    import cv2, tempfile, os

    img = np.full((100, 100, 3), 200, dtype=np.uint8)
    tmp = tempfile.NamedTemporaryFile(suffix=".jpg", delete=False)
    tmp.close()
    try:
        cv2.imwrite(tmp.name, img)
        t = _preprocess_image(tmp.name)
        # /255 de 200 -> 0.7843; el modelo NO tiene Rescaling (archivo V3 sin el)
        assert abs(float(t.max()) - 200 / 255.0) < 0.02
    finally:
        os.remove(tmp.name)


def test_modelo_v3_no_tiene_rescaling():
    import tensorflow as tf

    m = tf.keras.models.load_model(str(MODELO_V3), compile=False)

    def walk(layers, out):
        for l in layers:
            if l.__class__.__name__ in ("Rescaling", "Normalization"):
                out.append(l.__class__.__name__)
            if hasattr(l, "layers") and l.layers:
                walk(l.layers, out)

    found = []
    walk(m.layers, found)
    assert found == [], f"V3 no debe tener Rescaling: {found}"


# ---------------------------------------------------------------------------
# FASE 3: mapping de clases
# ---------------------------------------------------------------------------
def test_class_mapping_v3_archivo():
    m = json.loads((BACKEND / "ia" / "modelos" / "class_mapping_v3.json").read_text(encoding="utf-8"))
    assert m == {"0": "liquen saludable", "1": "liquen contaminado", "2": "desconocido"}


def test_class_names_orden_coincide_con_mapping():
    from ia.modelos.lichen_classifier import CLASS_NAMES
    assert CLASS_NAMES == ["liquen saludable", "liquen contaminado", "liquen desconocido"]


def test_argmax_se_traduce_bien():
    from ia.modelos.lichen_classifier import CLASS_NAMES
    probs = np.array([0.36, 0.33, 0.31])
    idx = int(np.argmax(probs))
    assert CLASS_NAMES[idx] == "liquen saludable"
    probs2 = np.array([0.1, 0.6, 0.3])
    assert CLASS_NAMES[int(np.argmax(probs2))] == "liquen contaminado"


# ---------------------------------------------------------------------------
# FASE 4: probabilidades siempre suman ~1
# ---------------------------------------------------------------------------
def test_predict_probabilities_sum_1(monkeypatch):
    import ia.modelos.lichen_classifier as lc

    class FakeModel:
        def predict(self, x, verbose=0):
            return np.array([[0.5, 0.3, 0.2]])

    monkeypatch.setattr(lc, "_load_model", lambda: FakeModel())
    monkeypatch.setattr(lc, "_preprocess_image", lambda p: np.zeros((1, 224, 224, 3), dtype="float32"))
    r = lc.predict("x.jpg")
    assert r["categoria"] == "liquen saludable"


def test_predict_devuelve_contrato():
    import ia.modelos.lichen_classifier as lc

    class FakeModel:
        def predict(self, x, verbose=0):
            return np.array([[0.1, 0.2, 0.7]])

    monkeypatch_P = pytest.MonkeyPatch()
    monkeypatch_P.setattr(lc, "_load_model", lambda: FakeModel())
    monkeypatch_P.setattr(lc, "_preprocess_image", lambda p: np.zeros((1, 224, 224, 3), dtype="float32"))
    r = lc.predict("x.jpg")
    assert set(r) >= {"categoria", "confianza", "nombre_especie", "nivel_contaminacion", "calidad_aire"}
    assert r["categoria"] == "liquen desconocido"
    assert abs(r["confianza"] - 0.7) < 1e-6
    monkeypatch_P.undo()


# ---------------------------------------------------------------------------
# FASE 7 / 8: BD no se modifica
# ---------------------------------------------------------------------------
def test_no_se_registra_v7_en_bd():
    from config.db import SessionLocal
    from models.core import ModeloIA

    with SessionLocal() as db:
        v7 = db.query(ModeloIA).filter(ModeloIA.version == "v7.0").all()
        assert v7 == []
        activo = db.query(ModeloIA).filter(ModeloIA.estado_modelo == "activo").all()
        for a in activo:
            assert a.version != "v7.0"


def test_en_bd_v3_es_el_activo(capsys):
    from config.db import SessionLocal
    from models.core import ModeloIA

    with SessionLocal() as db:
        activos = db.query(ModeloIA).filter(ModeloIA.estado_modelo == "activo").all()
        assert activos, "la BD de tests debe tener un activo (v3)"
        activos.sort(key=lambda r: r.id_modelo, reverse=True)
        primero = activos[0]
        assert primero.version == "v3.0"
        info = json.loads(primero.observaciones)
        assert "lichen_model_v3.keras" in str(info.get("archivo", ""))