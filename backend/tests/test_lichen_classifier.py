import os
from pathlib import Path

import cv2
import numpy as np
import pytest

from ia.modelos.lichen_classifier import (
    CONTAMINATION_MAP,
    AIR_QUALITY_MAP,
    CLASS_NAMES,
    INPUT_SIZE,
    NUM_CLASSES,
    _preprocess_image,
    predict,
)


REPO_ROOT = Path(__file__).resolve().parents[2]
DATASET_DIR = REPO_ROOT / "backend" / "ia" / "datasets"


def _find_sample_image():
    for subdir in DATASET_DIR.iterdir():
        if subdir.is_dir():
            for filename in sorted(subdir.iterdir()):
                if filename.suffix.lower() in {".jpg", ".jpeg", ".png"}:
                    return filename
    return None


SAMPLE_IMAGE = _find_sample_image()


def test_class_names_and_constants():
    assert CLASS_NAMES == [
        "liquen saludable",
        "liquen contaminado",
        "liquen desconocido",
    ]
    assert NUM_CLASSES == 3
    assert INPUT_SIZE == (224, 224)
    assert CONTAMINATION_MAP["liquen saludable"] == "baja"
    assert AIR_QUALITY_MAP["liquen contaminado"] == "mala"


def test_preprocess_image_valid(tmp_path):
    if SAMPLE_IMAGE is None:
        pytest.skip("No hay imágenes de dataset disponibles")

    tensor = _preprocess_image(str(SAMPLE_IMAGE))
    assert tensor.shape == (1, INPUT_SIZE[0], INPUT_SIZE[1], 3)
    assert tensor.dtype == np.float32
    assert float(tensor.min()) >= 0.0
    assert float(tensor.max()) <= 1.0


def test_preprocess_image_missing():
    with pytest.raises(FileNotFoundError):
        _preprocess_image("ruta/inexistente/imagen.png")


def test_predict_output_contract():
    from ia.modelos.lichen_classifier import MODEL_PATH

    if SAMPLE_IMAGE is None:
        pytest.skip("No hay imágenes de dataset disponibles")

    if not MODEL_PATH.exists():
        pytest.skip("Modelo IA no entrenado disponible")

    result = predict(str(SAMPLE_IMAGE))
    assert isinstance(result, dict)
    assert "categoria" in result
    assert "confianza" in result
    assert "nombre_especie" in result
    assert "nivel_contaminacion" in result
    assert "calidad_aire" in result

    assert result["categoria"] in CLASS_NAMES
    assert 0.0 <= result["confianza"] <= 1.0
    assert result["nivel_contaminacion"] in CONTAMINATION_MAP.values()
    assert result["calidad_aire"] in AIR_QUALITY_MAP.values()


def test_predict_nombre_especie_is_none_when_no_species_model():
    from ia.modelos.lichen_classifier import MODEL_PATH

    if SAMPLE_IMAGE is None:
        pytest.skip("No hay imágenes de dataset disponibles")

    if not MODEL_PATH.exists():
        pytest.skip("Modelo IA no entrenado disponible")

    result = predict(str(SAMPLE_IMAGE))
    assert result["nombre_especie"] is None


def test_predict_invalid_image_path():
    from ia.modelos.lichen_classifier import MODEL_PATH

    try:
        import tensorflow  # noqa: F401
    except ModuleNotFoundError:
        pytest.skip("TensorFlow no instalado en el entorno de pruebas")

    if not MODEL_PATH.exists():
        pytest.skip("Modelo IA no entrenado disponible")

    with pytest.raises((FileNotFoundError, ValueError)):
        predict("backend/ia/datasets/no_existe.png")
