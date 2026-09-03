"""Entrenamiento del clasificador ambiental binario de liquenes.

Clases (orden de salida del modelo, MANTENER tal cual):
    0 -> 'liquen saludable'
    1 -> 'liquen contaminado'

- Usa SOLO liquenes_saludables (500) y liquenes_contaminados (500).
- 'liquenes_desconocidos' NO se usa para entrenar (etiqueta no confiable como
  saludable/contaminado); solo se podra usar despues como prueba
  out-of-distribution.
- Anti data-leakage: imagenes practicamente identicas se agrupan mediante un
  perceptual hash (dHash 8x8, Hamming <= 1) y el split train/val/test se hace
  POR GRUPO (nunca se separan variantes de una misma familia entre conjuntos).
  Limitacion documentada: tras el renombrado no se puede reconstruir el
  parentesco original<>aumentada de forma exacta; si una aumentada quedo tan
  distinta que su hash difiere, no se detecta la familia y se usa el metodo
  mas seguro posible (lo mismo aplica de forma estricta a las detectadas).
- Preprocesado identico a inferencia: 224x224 RGB, /255.
- Augmentation dinamica SOLO en train.
- Guarda el mejor modelo (por val_loss) en ia/modelos/lichen_model_v2.keras.
"""
import json
import time
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
DATASET_DIR = PROJECT_ROOT / "ia" / "datasets"
MODEL_DIR = PROJECT_ROOT / "ia" / "modelos"
REPORTS_DIR = PROJECT_ROOT / "ia" / "entrenamiento" / "reportes"
REPORTS_DIR.mkdir(parents=True, exist_ok=True)

INPUT_SIZE = (224, 224)
CLASSES = ["liquen saludable", "liquen contaminado"]
CLASS_PREFIX = {"liquenes_saludables": 0, "liquenes_contaminados": 1}
FINAL_MODEL = MODEL_DIR / "lichen_model_v2.keras"
CLASS_MAPPING = MODEL_DIR / "class_mapping_v2.json"
EPOCHS = 15
BATCH = 16
SEED = 42


def _dhash(path: Path, size: int = 8) -> int:
    try:
        img = Image.open(path).convert("L").resize((size + 1, size), Image.BILINEAR)
    except Exception:
        return -1
    px = np.asarray(img, dtype=np.int16)
    diff = (px[:, 0:size] < px[:, 1:size + 1]).astype(np.uint8)
    h = 0
    _ = diff.flatten()
    for diffpixel in diff.flatten():
        h = (h << 1) | int(diffpixel)
    return h


def _hamming(a: int, b: int) -> int:
    return bin(a ^ b).count("1")


def load_dataset():
    """Devuelve X, y, familias (imagenes parecidas agrupadas)."""
    paths, labels = [], []
    for sub, label in CLASS_PREFIX.items():
        folder = DATASET_DIR / sub
        files = sorted(
            p for p in folder.iterdir()
            if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
        )
        paths += files
        labels += [label] * len(files)

    X = np.zeros((len(paths), INPUT_SIZE[0], INPUT_SIZE[1], 3), dtype="float32")
    for i, p in enumerate(paths):
        img = cv2.imread(str(p), cv2.IMREAD_UNCHANGED)
        if img is None:
            # Si una fuente falla, se completa con ceros (no deberia pasar).
            continue
        if img.ndim == 2:
            img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
        elif img.ndim == 3 and img.shape[2] == 4:
            img = cv2.cvtColor(img, cv2.COLOR_BGRA2RGB)
        elif img.ndim == 3 and img.shape[2] == 3:
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        X[i] = cv2.resize(img, INPUT_SIZE) / 255.0

    y = np.array(labels)

    # Agrupar por dHash (solo dentro de la misma clase).
    fam_id = [-1] * len(paths)
    fam_rep = {}  # clase -> [(hash, family_index)]
    families = []
    for i, p in enumerate(paths):
        h = _dhash(p)
        matched = None
        for (rep_h, fid) in fam_rep.get(y[i], []):
            if h >= 0 and _hamming(h, rep_h) <= 1:
                matched = fid
                break
        if matched is None:
            fid = len(families)
            families.append(y[i])
            fam_rep.setdefault(y[i], []).append((h, fid))
            fam_id[i] = fid
        else:
            fam_id[i] = matched

    sizes = {}
    for fid in fam_id:
        sizes[fid] = sizes.get(fid, 0) + 1
    print(f"[ANTI-LEAKAGE] familias detectadas: {len(families)} "
          f"(max tamano familia: {max(sizes.values())})")
    return X, y, fam_id


def split_by_family(X, y, fam_id, train_ratio=0.70, val_ratio=0.15, seed=42):
    """Split estratificado por familia (nunca separa variantes de una familia)."""
    rng = np.random.default_rng(seed)
    fams = sorted(set(fam_id))
    rng.shuffle(fams)
    n = len(fams)
    n_train = int(n * train_ratio)
    n_val = int(n * val_ratio)

    def pick(lo, hi):
        keep = set(fams[lo:hi])
        idx = [i for i, fid in enumerate(fam_id) if fid in keep]
        return X[idx], y[idx]

    X_train, y_train = pick(0, n_train)
    X_val, y_val = pick(n_train, n_train + n_val)
    X_test, y_test = pick(n_train + n_val, n)
    return X_train, y_train, X_val, y_val, X_test, y_test


def build_model():
    from tensorflow.keras import layers, models

    model = models.Sequential([
        layers.Input(shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3)),
        layers.Conv2D(32, (3, 3), activation="relu", padding="same"),
        layers.BatchNormalization(),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),
        layers.Conv2D(64, (3, 3), activation="relu", padding="same"),
        layers.BatchNormalization(),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),
        layers.Conv2D(128, (3, 3), activation="relu", padding="same"),
        layers.BatchNormalization(),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),
        layers.Flatten(),
        layers.Dense(128, activation="relu"),
        layers.Dropout(0.5),
        layers.Dense(len(CLASSES), activation="softmax"),
    ])
    model.compile(
        optimizer="adam",
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def build_augmentation():
    from tensorflow.keras import layers, models

    return models.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.08),
        layers.RandomZoom(0.08),
        layers.RandomBrightness(0.08),
        layers.RandomContrast(0.08),
    ])


def train(model, X_train, y_train, X_val, y_val):
    import tensorflow as tf

    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=EPOCHS,
        batch_size=BATCH,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(
                monitor="val_loss", patience=6, restore_best_weights=True
            ),
            tf.keras.callbacks.ReduceLROnPlateau(
                monitor="val_loss", factor=0.5, patience=3, min_lr=1e-6
            ),
            tf.keras.callbacks.ModelCheckpoint(
                str(FINAL_MODEL), monitor="val_loss", save_best_only=True
            ),
        ],
    )
    best_epoch = int(np.argmin(history.history["val_loss"])) + 1
    return history, best_epoch


def evaluate(model, X, y):
    from sklearn.metrics import (
        accuracy_score,
        classification_report,
        confusion_matrix,
        f1_score,
        precision_score,
        recall_score,
    )
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    probs = model.predict(X, batch_size=BATCH, verbose=0)
    preds = np.argmax(probs, axis=1)
    conf = 100.0 * float(np.max(probs, axis=1).mean())
    acc = accuracy_score(y, preds)
    prec = precision_score(y, preds, average="binary", zero_division=0)
    rec = recall_score(y, preds, average="binary", zero_division=0)
    f1 = f1_score(y, preds, average="binary", zero_division=0)
    cm = confusion_matrix(y, preds, labels=[0, 1])
    report = classification_report(y, preds, labels=[0, 1], target_names=CLASSES, digits=4)

    plt.figure(figsize=(5, 4))
    plt.imshow(cm, cmap="Blues")
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            plt.text(j, i, str(cm[i, j]), ha="center", va="center")
    plt.xticks([0, 1], CLASSES)
    plt.yticks([0, 1], CLASSES)
    plt.title("Confusion Matrix - V2")
    plt.tight_layout()
    plt.savefig(REPORTS_DIR / "confusion_matrix_v2.png", dpi=150)
    plt.close()

    metrics = {
        "accuracy": float(acc),
        "precision": float(prec),
        "recall": float(rec),
        "f1": float(f1),
        "confianza_promedio": conf,
        "confusion_matrix": cm.tolist(),
        "classification_report": report,
        "class_mapping": {i: c for i, c in enumerate(CLASSES)},
    }
    return preds, metrics


def main():
    import tensorflow as tf

    t0 = time.time()
    X, y, fam = load_dataset()
    X_train, y_train, X_val, y_val, X_test, y_test = split_by_family(X, y, fam)

    print(f"Dataset: saludables={int(np.sum(y == 0))}, contaminados={int(np.sum(y == 1))}")
    print(f"Split (por familia): Train={len(X_train)} Val={len(X_val)} Test={len(X_test)}")

    # Modelo base + augmentation (SOLO train).
    model = tf.keras.Sequential([build_augmentation(), build_model()])
    model.compile(
        optimizer="adam",
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    history, best_epoch = train(model, X_train, y_train, X_val, y_val)

    # Mejor modelo guardado por checkpoint; recargar para evaluar.
    best = tf.keras.models.load_model(str(FINAL_MODEL))
    preds_test, metrics = evaluate(best, X_test, y_test)
    epochs_run = len(history.history["val_loss"])

    (REPORTS_DIR / "metrics_v2.json").write_text(
        json.dumps(metrics, indent=2), encoding="utf-8"
    )
    CLASS_MAPPING.write_text(
        json.dumps({"0": CLASSES[0], "1": CLASSES[1]}), encoding="utf-8"
    )

    print(f"\n=== RESULTADO V2 ===")
    print(f"Arquitectura: CNN (conv 32/64/128 + Dense128) - {len(CLASSES)} clases")
    print(f"Input: {INPUT_SIZE[0]}x{INPUT_SIZE[1]} RGB /255")
    print(f"Clases: {CLASSES}")
    print(f"Épocas ejecutadas: {epochs_run} | Mejor época (val_loss): {best_epoch}")
    print(f"Accuracy: {metrics['accuracy']:.4f}")
    print(f"Precision: {metrics['precision']:.4f}")
    print(f"Recall: {metrics['recall']:.4f}")
    print(f"F1: {metrics['f1']:.4f}")
    print(f"Confianza promedio (test): {metrics['confianza_promedio']:.2f}%")
    print(f"Matriz de confusión:\n{metrics['confusion_matrix']}")
    print(metrics["classification_report"])
    print(f"Modelo guardado: {FINAL_MODEL}")
    print(f"Mapping clases guardado: {CLASS_MAPPING}")
    print(f"Tiempo total: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()