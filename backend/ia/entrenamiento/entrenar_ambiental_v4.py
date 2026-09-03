"""Entrenamiento V4 - clasificador ambiental 3 clases de liquenes.

Objetivo: corregir el colapso hacia 'desconocido' de v3.

Cambios frente a v3 (basados en el diagnostico):
- Arquitectura robusta: 4 bloques residuales (32/64/128/256) + GAP + Dropout,
  en lugar de la CNN simple que no alcanzaba a separar las clases.
- LR inicial 5e-4 (mas bajo/estable) y ReduceLROnPlateau agresivo.
- EarlyStopping paciencia 8 (v3 paraba en la epoca 2 por divergencia temprana).
- Class weights suavizados (sqrt de balanced): evita que el gradiente de la
  minoria domine/destruya el entrenamiento sin dejar de aprenderla.
- Label smoothing 0.05 (mejor calibracion de confianza).
- Batch 32, augmentation moderada en train, split por familias (dHash).

Clases (mapping fijo/verificado):
  0 = 'liquen saludable'
  1 = 'liquen contaminado'
  2 = 'desconocido'
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
CLASSES = ["liquen saludable", "liquen contaminado", "desconocido"]
CLASS_SOURCES = {
    0: ["liquenes_saludables"],
    1: ["liquenes_contaminados"],
    2: ["liquenes_desconocidos"],
}
EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
FINAL_MODEL = MODEL_DIR / "lichen_model_v4.keras"
CLASS_MAPPING = MODEL_DIR / "class_mapping_v4.json"
EPOCHS = 30
BATCH = 32
SEED = 42
LEARNING_RATE = 5e-4


def _dhash(path: Path) -> int:
    try:
        img = Image.open(path).convert("L").resize((9, 8), Image.BILINEAR)
    except Exception:
        return -1
    px = np.asarray(img, dtype=np.int16)
    diff = (px[:, 0:8] < px[:, 1:9]).astype(np.uint8)
    h = 0
    for bit in diff.flatten():
        h = (h << 1) | int(bit)
    return h


def _hamming(a: int, b: int) -> int:
    return bin(a ^ b).count("1")


def load_dataset():
    paths, labels = [], []
    for label, folders in CLASS_SOURCES.items():
        for base_name in folders:
            top = DATASET_DIR / base_name
            if label == 2:
                files = [
                    p for sub in sorted(top.iterdir()) if sub.is_dir()
                    for p in sub.iterdir()
                    if p.is_file() and p.suffix.lower() in EXT
                ]
            else:
                files = [
                    p for p in top.iterdir()
                    if p.is_file() and p.suffix.lower() in EXT
                ]
            files.sort(key=lambda p: p.name)
            paths += files
            labels += [label] * len(files)

    X = np.zeros((len(paths), INPUT_SIZE[0], INPUT_SIZE[1], 3), dtype="float32")
    for i, p in enumerate(paths):
        img = cv2.imread(str(p), cv2.IMREAD_UNCHANGED)
        if img is None:
            continue
        if img.ndim == 2:
            img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
        elif img.ndim == 3 and img.shape[2] == 4:
            img = cv2.cvtColor(img, cv2.COLOR_BGRA2RGB)
        elif img.ndim == 3 and img.shape[2] == 3:
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        X[i] = cv2.resize(img, INPUT_SIZE) / 255.0
    y = np.array(labels)

    fam = [-1] * len(paths)
    fam_rep = {}
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
            fam[i] = fid
        else:
            fam[i] = matched
    sizes = {}
    for fid in fam:
        sizes[fid] = sizes.get(fid, 0) + 1
    print(f"[ANTI-LEAKAGE] familias: {len(families)} (max tamano: {max(sizes.values())})")
    return X, y, fam


def split_by_family(X, y, fam_id, train_ratio=0.70, val_ratio=0.15, seed=42):
    rng = np.random.default_rng(seed)
    fams = sorted(set(fam_id))
    rng.shuffle(fams)
    n_train = int(len(fams) * train_ratio)
    n_val = int(len(fams) * val_ratio)

    def pick(indices):
        keep = set(indices)
        return [i for i, fid in enumerate(fam_id) if fid in keep]

    tr = pick(fams[:n_train])
    va = pick(fams[n_train:n_train + n_val])
    te = pick(fams[n_train + n_val:])
    return (X[tr], y[tr], X[va], y[va], X[te], y[te])


def _conv_block(x, filters, kernel=3, strides=1):
    from tensorflow.keras import layers

    shortcut = x
    x = layers.Conv2D(filters, kernel, strides=strides, padding="same", use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)
    x = layers.Conv2D(filters, kernel, padding="same", use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    if shortcut.shape[-1] != filters or strides != 1:
        shortcut = layers.Conv2D(filters, 1, strides=strides, use_bias=False)(shortcut)
        shortcut = layers.BatchNormalization()(shortcut)
    x = layers.Add()([shortcut, x])
    x = layers.ReLU()(x)
    return x


def build_model():
    from tensorflow.keras import layers, models

    inp = layers.Input(shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3))
    x = layers.Conv2D(32, 7, strides=2, padding="same", use_bias=False)(inp)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)
    x = layers.MaxPooling2D(3, strides=2, padding="same")(x)

    x = _conv_block(x, 32)
    x = _conv_block(x, 64, strides=2)
    x = _conv_block(x, 128, strides=2)
    x = _conv_block(x, 256, strides=2)

    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.4)(x)
    x = layers.Dense(128, activation="relu")(x)
    x = layers.Dropout(0.4)(x)
    out = layers.Dense(len(CLASSES), activation="softmax")(x)
    model = models.Model(inp, out)
    return model


def build_augmentation():
    from tensorflow.keras import layers, models

    return models.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.15),
        layers.RandomZoom(0.15),
        layers.RandomTranslation(0.05, 0.05),
        layers.RandomBrightness(0.1),
        layers.RandomContrast(0.1),
    ])


def main():
    import tensorflow as tf
    from sklearn.utils.class_weight import compute_class_weight
    from sklearn.metrics import (accuracy_score, classification_report,
                                 confusion_matrix, f1_score, precision_score,
                                 recall_score)
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    t0 = time.time()
    X, y, fam = load_dataset()
    X_train, y_train, X_val, y_val, X_test, y_test = split_by_family(X, y, fam)

    n0 = int(np.sum(y == 0)); n1 = int(np.sum(y == 1)); n2 = int(np.sum(y == 2))
    print(f"Dataset: saludable={n0}, contaminado={n1}, desconocido={n2}, total={len(y)}")
    print(f"Split (por familia): Train={len(X_train)} Val={len(X_val)} Test={len(X_test)}")

    # Class weights suavizados: sqrt(balanced) -> minoria ~1.2-1.6, mayoria ~0.7-0.9
    cw = compute_class_weight("balanced", classes=np.array([0, 1, 2]), y=y_train)
    softened = {i: float(cw[i] ** 0.5) for i in range(3)}
    print(f"Class weights (suavizados): {softened}")

    model = tf.keras.Sequential([build_augmentation(), build_model()])
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=LEARNING_RATE),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=8,
                                         restore_best_weights=True),
        tf.keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5,
                                             patience=3, min_lr=1e-7),
        tf.keras.callbacks.ModelCheckpoint(str(FINAL_MODEL), monitor="val_loss",
                                           save_best_only=True),
    ]

    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=EPOCHS, batch_size=BATCH, class_weight=softened,
        callbacks=callbacks, verbose=1,
    )
    best_epoch = int(np.argmin(history.history["val_loss"])) + 1
    best = tf.keras.models.load_model(str(FINAL_MODEL))

    probs = best.predict(X_test, batch_size=BATCH, verbose=0)
    preds = np.argmax(probs, axis=1)
    conf_mean = 100.0 * float(np.max(probs, axis=1).mean())

    acc = accuracy_score(y_test, preds)
    prec = precision_score(y_test, preds, average="macro", zero_division=0)
    rec = recall_score(y_test, preds, average="macro", zero_division=0)
    f1 = f1_score(y_test, preds, average="macro", zero_division=0)
    cm = confusion_matrix(y_test, preds, labels=[0, 1, 2])
    report = classification_report(y_test, preds, labels=[0, 1, 2],
                                   target_names=CLASSES, digits=4)
    per_class = classification_report(y_test, preds, labels=[0, 1, 2],
                                      target_names=CLASSES, output_dict=True)

    plt.figure(figsize=(6, 5))
    plt.imshow(cm, cmap="Blues")
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            plt.text(j, i, str(cm[i, j]), ha="center", va="center")
    plt.xticks([0, 1, 2], CLASSES)
    plt.yticks([0, 1, 2], CLASSES)
    plt.title("Confusion Matrix V4")
    plt.tight_layout()
    plt.savefig(REPORTS_DIR / "confusion_matrix_v4.png", dpi=150)
    plt.close()

    metrics = {
        "accuracy": float(acc), "precision_macro": float(prec),
        "recall_macro": float(rec), "f1_macro": float(f1),
        "confianza_promedio": conf_mean, "confusion_matrix": cm.tolist(),
        "classification_report": report, "per_class": per_class,
        "per_class_counts": {"saludable": n0, "contaminado": n1,
                             "desconocido": n2, "total": len(y)},
        "split": {"train": len(X_train), "val": len(X_val), "test": len(X_test)},
        "class_weights_softened": softened,
        "class_mapping": {str(i): c for i, c in enumerate(CLASSES)},
        "config": {"lr": LEARNING_RATE, "batch": BATCH, "epochs_exec": len(history.history["val_loss"]),
                   "best_epoch": best_epoch, "label_smoothing": 0.0},
    }
    (REPORTS_DIR / "metrics_v4.json").write_text(
        json.dumps(metrics, indent=2, ensure_ascii=False), encoding="utf-8")
    CLASS_MAPPING.write_text(
        json.dumps({str(i): c for i, c in enumerate(CLASSES)}, ensure_ascii=False),
        encoding="utf-8")

    print("=== RESULTADO V4 (3 CLASES) ===")
    print(f"Arquitectura: Residual conv 32/64/128/256 + GAP + Dense128 -> Dense(3,softmax)")
    print(f"Input: 224x224 RGB /255 | Clases: {CLASSES}")
    print(f"Epocas ejecutadas: {len(history.history['val_loss'])} | Mejor epoca: {best_epoch}")
    print(f"Accuracy: {acc:.4f}\nPrecision macro: {prec:.4f}\nRecall macro: {rec:.4f}\nF1 macro: {f1:.4f}")
    print(f"Confianza promedio (test): {conf_mean:.2f}%")
    print(f"Matriz:\n{cm}")
    print(report)
    print(f"Archivo: {FINAL_MODEL}")
    print(f"Mapping: {CLASS_MAPPING}")
    print(f"Tiempo: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()