import os
from pathlib import Path

import cv2
import numpy as np

MODEL_FILENAME = "lichen_model.keras"
MODEL_DIR = Path(__file__).resolve().parent
MODEL_PATH = MODEL_DIR / MODEL_FILENAME
INPUT_SIZE = (224, 224)
NUM_CLASSES = 3
CLASS_NAMES = [
    "liquen saludable",
    "liquen contaminado",
    "liquen desconocido",
]

CONTAMINATION_MAP = {
    "liquen saludable": "baja",
    "liquen contaminado": "alta",
    "liquen desconocido": "desconocida",
}

AIR_QUALITY_MAP = {
    "liquen saludable": "buena",
    "liquen contaminado": "mala",
    "liquen desconocido": "desconocida",
}

_model = None


def _load_model():
    global _model
    if _model is not None:
        return _model
    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Modelo IA no encontrado en {MODEL_PATH}. "
            "Ejecuta train_model.py primero."
        )
    import tensorflow as tf

    _model = tf.keras.models.load_model(str(MODEL_PATH))
    return _model


def _preprocess_image(image_path: str) -> np.ndarray:
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Imagen no encontrada: {image_path}")

    img = cv2.imread(image_path, cv2.IMREAD_UNCHANGED)
    if img is None:
        raise ValueError(f"No se pudo leer la imagen: {image_path}")

    if img.ndim == 2:
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    elif img.shape[2] == 4:
        img = cv2.cvtColor(img, cv2.COLOR_BGRA2RGB)
    elif img.shape[2] == 3:
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    else:
        raise ValueError(
            f"Formato de imagen no soportado: {img.shape[2]} canales en {image_path}"
        )

    img = cv2.resize(img, INPUT_SIZE)
    img = img.astype(np.float32) / 255.0
    img = np.expand_dims(img, axis=0)
    return img


def predict(image_path: str) -> dict:
    model = _load_model()
    tensor = _preprocess_image(image_path)
    predictions = model.predict(tensor, verbose=0)
    class_index = int(np.argmax(predictions[0]))
    confidence = float(predictions[0][class_index])
    categoria = CLASS_NAMES[class_index]
    nivel_contaminacion = CONTAMINATION_MAP[categoria]
    calidad_aire = AIR_QUALITY_MAP[categoria]

    print(f"[PREDICT] model_path={MODEL_PATH}")
    print(f"[PREDICT] image_path={image_path}")
    print(f"[PREDICT] class_index={class_index} categoria={categoria} confidence={confidence}")
    print(f"[PREDICT] predictions={predictions[0].tolist()}")

    return {
        "categoria": categoria,
        "confianza": confidence,
        "nombre_especie": None,
        "nivel_contaminacion": nivel_contaminacion,
        "calidad_aire": calidad_aire,
    }

# Nota: La arquitectura actual del modelo CNN clasifica en 3 categorías
# generales (saludable / contaminado / desconocido), pero no incluye
# una cabeza de clasificación de especies. Por lo tanto, `nombre_especie`
# se mantiene como None hasta que se entrene un modelo específico de
# identificación de especies o se integre con la tabla `especies_liquenes`.