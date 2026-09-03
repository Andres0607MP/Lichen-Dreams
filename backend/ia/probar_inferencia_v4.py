import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import numpy as np
from ia.modelos.lichen_classifier import predict, _preprocess_image, MODEL_PATH
import tensorflow as tf

DATASET = Path(__file__).resolve().parent / "datasets"
V4 = Path(__file__).resolve().parent / "modelos" / "lichen_model_v4.keras"


def first_files(folder, n):
    fs = [p for p in folder.iterdir()
          if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".bmp", ".webp"}]
    return sorted(fs)[:n]


print(f"MODELO ACTIVO (resolucion BD): {MODEL_PATH.name}")
print("=== PRUEBA 3 CATEGORIAS -> modelo activo ===")
for label, folder in [("liquen saludable", DATASET / "liquenes_saludables"),
                      ("liquen contaminado", DATASET / "liquenes_contaminados")]:
    for p in first_files(folder, 3):
        r = predict(str(p))
        print(f"{p.name} | esperado={label} | predicho={r['categoria']} | conf={r['confianza']:.3f}")

print("\n=== DESCONOCIDOS (clase entrenada) ===")
for sub in ["agua", "pasto_hierba", "animales", "objetos", "vehiculos"]:
    folder = DATASET / "liquenes_desconocidos" / sub
    for p in first_files(folder, 2):
        r = predict(str(p))
        print(f"{sub}/{p.name} | esperado=desconocido | predicho={r['categoria']} | conf={r['confianza']:.3f}")

print("\n=== COMPARACION V4 (explicita, modelo no activo) ===")
v4 = tf.keras.models.load_model(str(V4))
for label, folder in [("liquen saludable", DATASET / "liquenes_saludables"),
                      ("liquen contaminado", DATASET / "liquenes_contaminados"),
                      ("desconocido", DATASET / "liquenes_desconocidos" / "objetos")]:
    for p in first_files(folder, 2):
        probs = v4.predict(_preprocess_image(str(p)), verbose=0)
        idx = int(np.argmax(probs[0]))
        cls = ["liquen saludable", "liquen contaminado", "desconocido"][idx]
        print(f"{p.name} | esperado={label} | v4={cls} | conf={float(probs[0][idx]):.3f}")