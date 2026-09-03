import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import numpy as np
import cv2
import tensorflow as tf

DATASET = Path(__file__).resolve().parent / "datasets"
V3 = Path(__file__).resolve().parent / "modelos" / "lichen_model_v3.keras"
V5 = Path(__file__).resolve().parent / "modelos" / "lichen_model_v5.keras"
CLASSES = ["liquen saludable", "liquen contaminado", "desconocido"]


def preprocess(p):
    img = cv2.imread(str(p), cv2.IMREAD_UNCHANGED)
    if img.ndim == 3 and img.shape[2] == 4:
        img = cv2.cvtColor(img, cv2.COLOR_BGRA2RGB)
    elif img.ndim == 3 and img.shape[2] == 3:
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    elif img.ndim == 2:
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    img = cv2.resize(img, (224, 224)).astype(np.float32) / 255.0
    return np.expand_dims(img, 0)


def first_files(folder, n):
    fs = [p for p in folder.iterdir()
          if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".bmp", ".webp"}]
    return sorted(fs)[:n]


m3 = tf.keras.models.load_model(str(V3))
m5 = tf.keras.models.load_model(str(V5))

print("=== PRUEBA REAL (V3 = activo por BD; V5 comparativo) ===")
for label, folder in [("liquen saludable", DATASET / "liquenes_saludables"),
                      ("liquen contaminado", DATASET / "liquenes_contaminados")]:
    for p in first_files(folder, 3):
        x = preprocess(p)
        for name, m in [("v3", m3), ("v5", m5)]:
            probs = m.predict(x, verbose=0)
            idx = int(np.argmax(probs[0]))
            print(f"{p.name} | esperado={label} | {name}={CLASSES[idx]} conf={float(probs[0][idx]):.3f}")

print("\n=== lcp_* y desconocidos ===")
for p in first_files(DATASET / "liquenes_contaminados", 0):  # placeholder vacio
    pass
lcp = sorted([f for f in (DATASET / "liquenes_contaminados").iterdir()
              if f.is_file() and f.name.startswith("lcp_")])[:3]
for p in lcp:
    x = preprocess(p)
    for name, m in [("v3", m3), ("v5", m5)]:
        probs = m.predict(x, verbose=0)
        idx = int(np.argmax(probs[0]))
        print(f"{p.name} | esperado=liquen contaminado | {name}={CLASSES[idx]} conf={float(probs[0][idx]):.3f}")

for sub in ["agua", "pasto_hierba", "animales", "objetos", "vehiculos"]:
    folder = DATASET / "liquenes_desconocidos" / sub
    for p in first_files(folder, 1):
        x = preprocess(p)
        for name, m in [("v3", m3), ("v5", m5)]:
            probs = m.predict(x, verbose=0)
            idx = int(np.argmax(probs[0]))
            print(f"{sub}/{p.name} | esperado=desconocido | {name}={CLASSES[idx]} conf={float(probs[0][idx]):.3f}")