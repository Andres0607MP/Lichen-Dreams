"""Entrenamiento V5 - Transfer Learning (MobileNetV2) - 3 clases.

Clases: 0 saludable | 1 contaminado | 2 desconocido
Dataset: 2159 imagenes sin modificar.
Split por familia (dHash, Hamming<=1): train/val/test.
Class weights moderados (sqrt(balanced)) solo en train.
Metas: F1 macro + recall de saludable/contaminado equilibradas (NO solo accuracy).
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
CLASS_SOURCES = {0: ["liquenes_saludables"], 1: ["liquenes_contaminados"], 2: ["liquenes_desconocidos"]}
EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
FINAL_MODEL = MODEL_DIR / "lichen_model_v5.keras"
CLASS_MAPPING = MODEL_DIR / "class_mapping_v5.json"
BATCH = 32
SEED = 42


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
                files = [p for sub in sorted(top.iterdir()) if sub.is_dir()
                         for p in sub.iterdir() if p.is_file() and p.suffix.lower() in EXT]
            else:
                files = [p for p in top.iterdir() if p.is_file() and p.suffix.lower() in EXT]
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
    return X[tr], y[tr], X[va], y[va], X[te], y[te]


def build_augmentation():
    from tensorflow.keras import layers, models

    return models.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.12),
        layers.RandomZoom(0.12),
        layers.RandomBrightness(0.08),
        layers.RandomContrast(0.08),
    ])


def build():
    import tensorflow as tf
    from tensorflow.keras import layers, models

    base = tf.keras.applications.MobileNetV2(
        input_shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3),
        include_top=False,
        weights="imagenet",
    )
    rescaled = tf.keras.Sequential([layers.Rescaling(scale=1.0 / 127.5, offset=-1.0)])
    inp = layers.Input(shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3))
    x = rescaled(inp)
    x = base(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(128, activation="relu")(x)
    x = layers.Dropout(0.3)(x)
    out = layers.Dense(len(CLASSES), activation="softmax")(x)
    return models.Model(inp, out), base


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
    print(f"Dataset: saludable={n0} contaminado={n1} desconocido={n2} total={len(y)}")
    print(f"Split (familia): Train={len(X_train)} Val={len(X_val)} Test={len(X_test)}")

    cw = compute_class_weight("balanced", classes=np.array([0, 1, 2]), y=y_train)
    softened = {i: float(cw[i] ** 0.5) for i in range(3)}
    print(f"Class weights (sqrt balanced): {softened}")

    model, base = build()
    # FASE 1: backbone congelado, entrenar cabeza
    base.trainable = False
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    ckpt = tf.keras.callbacks.ModelCheckpoint(str(FINAL_MODEL), monitor="val_loss",
                                              save_best_only=True)
    es1 = tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=4,
                                           restore_best_weights=True)

    print(">> FASE 1: cabeza sobre backbone congelado")
    model = tf.keras.Sequential([build_augmentation(), model])
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    h1 = model.fit(X_train, y_train, validation_data=(X_val, y_val),
                   epochs=10, batch_size=BATCH, class_weight=softened,
                   callbacks=[es1, ckpt])

    # Recargar mejor de fase1 y reconstruir sin augmentation para fase2
    best1 = tf.keras.models.load_model(str(FINAL_MODEL))
    base.trainable = True
    # Fine-tune parcial: descongelar las ultimas ~40 capas del backbone
    for layer in base.layers[:-40]:
        layer.trainable = False

    model2 = tf.keras.Sequential([build_augmentation(), best1])
    model2.compile(optimizer=tf.keras.optimizers.Adam(1e-4),
                   loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    es2 = tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=5,
                                           restore_best_weights=True)
    rlr = tf.keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5,
                                               patience=2, min_lr=1e-7)

    print(">> FASE 2: fine-tune parcial (lr 1e-4)")
    h2 = model2.fit(X_train, y_train, validation_data=(X_val, y_val),
                    epochs=12, batch_size=BATCH, class_weight=softened,
                    callbacks=[es2, rlr, ckpt])

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
    per = classification_report(y_test, preds, labels=[0, 1, 2],
                                target_names=CLASSES, output_dict=True)

    plt.figure(figsize=(6, 5))
    plt.imshow(cm, cmap="Blues")
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            plt.text(j, i, str(cm[i, j]), ha="center", va="center")
    plt.xticks([0, 1, 2], CLASSES)
    plt.yticks([0, 1, 2], CLASSES)
    plt.title("Confusion Matrix V5")
    plt.tight_layout()
    plt.savefig(REPORTS_DIR / "confusion_matrix_v5.png", dpi=150)
    plt.close()

    metrics = {
        "accuracy": float(acc), "precision_macro": float(prec),
        "recall_macro": float(rec), "f1_macro": float(f1),
        "confianza_promedio": conf_mean, "confusion_matrix": cm.tolist(),
        "classification_report": report, "per_class": per,
        "per_class_counts": {"saludable": n0, "contaminado": n1, "desconocido": n2, "total": len(y)},
        "split": {"train": len(X_train), "val": len(X_val), "test": len(X_test)},
        "class_weights_softened": softened,
        "class_mapping": {str(i): c for i, c in enumerate(CLASSES)},
        "phases": {"phase1_epochs": len(h1.history["val_loss"]),
                   "phase2_epochs": len(h2.history["val_loss"])},
    }
    (REPORTS_DIR / "metrics_v5.json").write_text(
        json.dumps(metrics, indent=2, ensure_ascii=False), encoding="utf-8")
    CLASS_MAPPING.write_text(
        json.dumps({str(i): c for i, c in enumerate(CLASSES)}, ensure_ascii=False),
        encoding="utf-8")

    print("=== RESULTADO V5 (MobileNetV2, 2 fases) ===")
    print(f"Accuracy: {acc:.4f}\nPrecision macro: {prec:.4f}\nRecall macro: {rec:.4f}\nF1 macro: {f1:.4f}")
    print(f"Confianza promedio: {conf_mean:.2f}%")
    print(f"Matriz:\n{cm}")
    print(report)
    print(f"Archivo: {FINAL_MODEL}")
    print(f"Tiempo: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()