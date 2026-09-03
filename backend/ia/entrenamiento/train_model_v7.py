"""Pipeline de entrenamiento V7 (preparado para ejecutar, NO se ejecuta aqui).

Reproducible y leakage-safe: lee el manifest generado por create_split_v7.py y
solo entrena con las imagenes de TRAIN del manifest (las aumentadas solo en
train por construccion). Los splits val/test son originales reales.

Caracteristicas:
- seed fija (CLI --seed, default 42).
- Utiliza el manifest dataset_v7_manifest.csv (no re-escanea carpetas).
- Batches equilibrados ~1/3 por clase (sampling en memoria, sin tocar dataset).
- Focal loss multiclase con alpha balanceado.
- Transfer learning 2 fases; preprocessing del backbone dentro del modelo.
- CONTROL DE CLASS COLLAPSE por epoca (distribucion de predicciones + recall
  por clase); si una clase predomina > 90% o una clase tiene recall 0 despues
  de las primeras epocas, se registra como aviso en el historial.
- METRICA PRINCIPAL: macro F1 (checkpoint por val_macro_f1), junto con
  balanced accuracy y recalls por clase. NO se elige por accuracy.
- Salidas: metrics_v7.json, confusion_matrix_v7.png, classification_report_v7.json,
  training_history_v7.json, comparison_v3_v7.json, class_mapping_v7.json.

IMPORTANTE: este script NO registra el modelo en MySQL ni lo activa. Eso se
hace aparte con registrar_modelo_v7.py tras validar los resultados.

Uso (FASE POSTERIOR):
    python ia/entrenamiento/train_model_v7.py
    python ia/entrenamiento/train_model_v7.py --seed 42 --epochs 22 --batch 24 \\
        --arch efficientnetb1 --out-dir ia/entrenamiento/reportes

Dependencias extra: tensorflow, sklearn, matplotlib (ya usadas por v4-v6).
"""
import argparse
import csv
import json
import sys
import time
from collections import Counter
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
OUT_DIR_DEFAULT = Path(__file__).resolve().parent / "reportes"
MANIFEST_DEFAULT = Path(__file__).resolve().parent / "dataset_v7_manifest.csv"
MODEL_DIR = PROJECT_ROOT / "ia" / "modelos"
V3_METRICS = OUT_DIR_DEFAULT / "metrics_v3.json"

INPUT_SIZE = (224, 224)
CLASSES = ["liquen saludable", "liquen contaminado", "desconocido"]
CLASS_ID = {"saludable": 0, "contaminado": 1, "desconocido": 2}
SEED_DEFAULT = 42
BATCH_DEFAULT = 24
PHASE1_EPOCHS_DEFAULT = 10
PHASE2_EPOCHS_DEFAULT = 12
LR1_DEFAULT = 1e-3
LR2_DEFAULT = 1e-4
FINAL_MODEL = MODEL_DIR / "lichen_model_v7.keras"
CLASS_MAPPING = MODEL_DIR / "class_mapping_v7.json"


# ---------------------------------------------------------------------------
# Lectura del manifest
# ---------------------------------------------------------------------------
def load_manifest(path=MANIFEST_DEFAULT):
    with open(path, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    if len(rows) != 2159:
        raise ValueError(f"manifest con {len(rows)} filas (esperado 2159)")
    return rows


def split_rows(rows, split):
    return [r for r in rows if r["split"] == split]


def read_image(path, size=INPUT_SIZE):
    import cv2
    import numpy as np
    img = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if img is None:
        raise ValueError(f"No se pudo leer: {path}")
    if img.ndim == 2:
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    elif img.ndim == 3 and img.shape[2] == 4:
        img = cv2.cvtColor(img, cv2.COLOR_BGRA2RGB)
    elif img.ndim == 3 and img.shape[2] == 3:
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    img = cv2.resize(img, size)
    return img.astype(np.float32) / 255.0


def load_split(rows, size=INPUT_SIZE):
    import numpy as np
    X = np.zeros((len(rows), size[0], size[1], 3), dtype="float32")
    y = np.zeros((len(rows),), dtype=np.int32)
    for i, r in enumerate(rows):
        X[i] = read_image(r["filepath"], size)
        y[i] = int(r["class_id"])
    return X, y


# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------
def pipeline(args):
    import tensorflow as tf

    t0 = time.time()
    rows = load_manifest(args.manifest)
    tr_rows = split_rows(rows, "train")
    va_rows = split_rows(rows, "val")
    te_rows = split_rows(rows, "test")
    print("=== SPLIT (desde manifest) ===")
    for name, subset in (("train", tr_rows), ("val", va_rows), ("test", te_rows)):
        c = Counter(r["class_name"] for r in subset)
        print(f"{name}: total={len(subset)} sal={c['saludable']} cont={c['contaminado']} desc={c['desconocido']}")

    X_train, y_train = load_split(tr_rows)
    X_val, y_val = load_split(va_rows)
    X_test, y_test = load_split(te_rows)

    counts = Counter(int(r["class_id"]) for r in tr_rows)
    n_per = max(1, args.batch // 3)
    rng = np_random(args.seed)
    alpha = np_array([sum(counts.values()) / (3 * counts[c]) for c in (0, 1, 2)])

    def balanced_generator():
        class_idx = {}
        for c in (0, 1, 2):
            class_idx[c] = np_where(y_train == c)
        while True:
            Xb, Yb = [], []
            for c in (0, 1, 2):
                i = rng.integers(0, len(class_idx[c]), size=n_per)
                Xb.append(X_train[class_idx[c][i]])
                Yb.append(np_full(n_per, c, dtype="int32"))
            Xb = np_concatenate(Xb, axis=0)
            Yb = np_concatenate(Yb, axis=0)
            perm = rng.permutation(len(Xb))
            yield Xb[perm], Yb[perm]

    steps = max(1, (min(counts.values()) * 3) // args.batch)
    print(f"Efectivo por epoca ~ {min(counts.values()) * 3}; steps/epoca ~ {steps}")
    print(f"Alpha focal: {alpha.tolist()}")

    gen = balanced_generator()
    model, backbone_name = build_model_and_backbone(args)

    best = {"macro": -1.0, "epoch": 0}
    history = {"fase": [], "epoch": [], "accuracy": [], "loss": [], "val_macro_f1": [],
               "balanced_acc": [], "recall_sal": [], "recall_cont": [], "recall_desc": [],
               "pred_class_0": [], "pred_class_1": [], "pred_class_2": [], "collapse_warn": []}

    class V7Callback(tf.keras.callbacks.Callback):
        def __init__(self, xv, yv, path, fase):
            self.xv, self.yv, self.path, self.fase = xv, yv, path, fase

        def on_epoch_end(self, epoch, logs=None):
            preds = self.model.predict(self.xv, batch_size=args.batch, verbose=0)
            m = per_class_metrics(self.yv, preds)
            dist = Counter(int(p) for p in np_argmax(preds, axis=1))
            n = max(1, len(self.yv))
            d0 = dist.get(0, 0) / n
            d1 = dist.get(1, 0) / n
            d2 = dist.get(2, 0) / n
            warn = ""
            if max(d0, d1, d2) > 0.90 and epoch >= 3:
                warn = "CLASS COLLAPSE: una clase predomina >90% en val"
            for c in (0, 1, 2):
                if m["recall"][c] == 0.0 and m["f1"][c] == 0.0 and epoch >= 5:
                    warn = f"RECALL 0 en clase {CLASSES[c]} (posible colapso)"
            history["fase"].append(self.fase)
            history["epoch"].append(epoch + 1)
            history["accuracy"].append(float(logs.get("accuracy", 0.0)))
            history["loss"].append(float(logs.get("loss", 0.0)))
            history["val_macro_f1"].append(m["macro_f1"])
            history["balanced_acc"].append(m["balanced_acc"])
            history["recall_sal"].append(m["recall"][0])
            history["recall_cont"].append(m["recall"][1])
            history["recall_desc"].append(m["recall"][2])
            history["pred_class_0"].append(d0)
            history["pred_class_1"].append(d1)
            history["pred_class_2"].append(d2)
            history["collapse_warn"].append(warn)
            if warn:
                print(f"  [WARN] epoca {epoch + 1}: {warn}")
            if m["macro_f1"] > best["macro"]:
                best["macro"] = m["macro_f1"]
                best["epoch"] = epoch + 1
                self.model.save(self.path)
            logs["val_macro_f1"] = m["macro_f1"]
            save_json(args.out_dir, "training_history_v7.json", history)

    # FASE 1: backbone congelado
    bb = None
    for layer in model.layers:
        if layer.name == "_bb":
            bb = layer
            break
    if bb is None:
        for layer in model.layers:
            if layer.__class__.__name__.startswith("Functional"):
                bb = layer
                break
    if bb is None:
        raise RuntimeError("No se encontro la subred backbone")
    bb.trainable = False
    model.compile(optimizer=tf.keras.optimizers.Adam(args.lr1),
                  loss=focal_loss(GAMMA_DEFAULT, alpha), metrics=["accuracy"])
    ck = V7Callback(X_val, y_val, str(FINAL_MODEL), "phase1")
    print(f"\n>>> FASE 1 (epochs={args.epochs_phase1}, lr={args.lr1})")
    model.fit(gen, steps_per_epoch=steps, epochs=args.epochs_phase1,
              validation_data=(X_val, y_val), callbacks=[ck], verbose=1)

    # FASE 2: fine-tune ultimas 40 capas del backbone
    if best["macro"] >= 0 and FINAL_MODEL.exists():
        model = tf.keras.models.load_model(str(FINAL_MODEL), compile=False)
    bb = None
    for layer in model.layers:
        if layer.name == "_bb":
            bb = layer
            break
    if bb is None:
        for layer in model.layers:
            if layer.__class__.__name__.startswith("Functional"):
                bb = layer
                break
    if bb is None:
        raise RuntimeError("No se encontro la subred backbone")
    for layer in bb.layers:
        layer.trainable = False
    for layer in bb.layers[-40:]:
        layer.trainable = True
    model.compile(optimizer=tf.keras.optimizers.Adam(args.lr2),
                  loss=focal_loss(GAMMA_DEFAULT, alpha), metrics=["accuracy"])
    ck2 = V7Callback(X_val, y_val, str(FINAL_MODEL), "phase2")
    print(f"\n>>> FASE 2 (fine-tune epochs={args.epochs_phase2}, lr={args.lr2})")
    model.fit(gen, steps_per_epoch=steps, epochs=args.epochs_phase2,
              validation_data=(X_val, y_val), callbacks=[ck2], verbose=1)

    best_model = tf.keras.models.load_model(str(FINAL_MODEL), compile=False)
    probs = best_model.predict(X_test, batch_size=args.batch, verbose=0)
    preds = np_argmax(probs, axis=1)

    from sklearn.metrics import (accuracy_score, precision_score, recall_score,
                                 f1_score, classification_report, confusion_matrix,
                                 balanced_accuracy_score)
    acc = float(accuracy_score(y_test, preds))
    prec = float(precision_score(y_test, preds, average="macro", zero_division=0))
    rec = float(recall_score(y_test, preds, average="macro", zero_division=0))
    f1 = float(f1_score(y_test, preds, average="macro", zero_division=0))
    bal = float(balanced_accuracy_score(y_test, preds))
    cm = confusion_matrix(y_test, preds, labels=[0, 1, 2])
    rpt = classification_report(y_test, preds, labels=[0, 1, 2],
                                target_names=CLASSES, digits=4, output_dict=True)
    rep_str = classification_report(y_test, preds, labels=[0, 1, 2],
                                    target_names=CLASSES, digits=4)
    dist = {CLASSES[i]: int(np_sum(preds == i)) for i in range(3)}

    metrics = {
        "accuracy": acc, "precision_macro": prec, "recall_macro": rec,
        "f1_macro": f1, "balanced_accuracy": bal,
        "confianza_promedio": 100.0 * float(np_max(probs, axis=1).mean()),
        "prediction_distribution": dist,
        "confusion_matrix": cm.tolist(),
        "classification_report": rep_str,
        "per_class": rpt,
        "split": {name: {k: v for k, v in Counter(r["class_name"] for r in subset).items()}
                  for name, subset in (("train", tr_rows), ("val", va_rows), ("test", te_rows))},
        "seed": args.seed,
        "best_val_macro_f1_epoch": best["epoch"],
        "backbone": backbone_name,
        "class_mapping": {str(i): c for i, c in enumerate(CLASSES)},
    }
    save_json(args.out_dir, "metrics_v7.json", metrics)
    save_json(args.out_dir, "training_history_v7.json", history)
    save_json(args.out_dir, "classification_report_v7.json", rpt)
    CLASS_MAPPING.write_text(json.dumps({str(i): c for i, c in enumerate(CLASSES)},
                                        ensure_ascii=False), encoding="utf-8")
    plot_confusion(cm, args.out_dir / "confusion_matrix_v7.png")
    compara_v3_v7(metrics, args.out_dir)

    print("\n=== RESULTADO V7 ===")
    print(f"Accuracy: {acc:.4f} | Balanced acc: {bal:.4f}")
    print(f"Precision macro: {prec:.4f} | Recall macro: {rec:.4f} | F1 macro: {f1:.4f}")
    print(f"Distrib. pred: {dist}")
    print(rep_str)
    print(f"Archivo: {FINAL_MODEL}")
    print(f"Tiempo total: {time.time() - t0:.1f}s")
    print("\nV7 NO se registra ni se activa. Revisa metrics antes de registrar.")


# ---------------------------------------------------------------------------
# Metricas / helpers
# ---------------------------------------------------------------------------
def per_class_metrics(y, pred):
    from sklearn.metrics import classification_report, balanced_accuracy_score, f1_score
    import numpy as _np
    pred_idx = _np.argmax(pred, axis=1)
    rpt = classification_report(y, pred_idx, labels=[0, 1, 2], output_dict=True, zero_division=0)
    rec = {c: rpt[str(c)]["recall"] for c in (0, 1, 2)}
    f1c = {c: rpt[str(c)]["f1-score"] for c in (0, 1, 2)}
    macro = float(_np.mean([f1c[c] for c in (0, 1, 2)]))
    return {"recall": rec, "f1": f1c, "macro_f1": macro,
            "balanced_acc": float(balanced_accuracy_score(y, pred_idx))}


def focal_loss(gamma=2.0, alpha=None):
    import tensorflow as tf
    from tensorflow import keras

    def loss(y_true, y_pred):
        y_pred = tf.clip_by_value(y_pred, keras.backend.epsilon(), 1.0 - keras.backend.epsilon())
        idx = tf.cast(y_true, tf.int32)
        pt = tf.gather(y_pred, idx, batch_dims=1)
        if alpha is not None:
            al = tf.gather(tf.constant(alpha, dtype="float32"), idx)
            return tf.reduce_mean(-al * tf.pow(1.0 - pt, gamma) * tf.math.log(pt))
        return tf.reduce_mean(-tf.pow(1.0 - pt, gamma) * tf.math.log(pt))
    return loss


def build_model_and_backbone(args):
    import tensorflow as tf
    from tensorflow.keras import layers, models

    def backbone(name):
        if name == "efficientnetb1":
            return tf.keras.applications.EfficientNetB1(
                input_shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3), include_top=False, weights="imagenet")
        if name == "efficientnetb2":
            return tf.keras.applications.EfficientNetB2(
                input_shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3), include_top=False, weights="imagenet")
        if name == "mobilenetv3":
            return tf.keras.applications.MobileNetV3Large(
                input_shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3), include_top=False, weights="imagenet")
        return tf.keras.applications.MobileNetV2(
            input_shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3), include_top=False, weights="imagenet")

    name_used = None
    base = None
    candidatos = [args.arch] + [c for c in ("efficientnetb1", "efficientnetb2", "mobilenetv3", "mobilenetv2") if c != args.arch]
    for cand in candidatos:
        try:
            base = backbone(cand)
            name_used = cand
            break
        except Exception as e:
            print(f"  {cand} no disponible ({type(e).__name__}: {e}); siguiente...")
    if base is None:
        raise RuntimeError("Ningun backbone preentrenado disponible (sin red?)")

    inp = layers.Input(shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3))
    x = layers.Rescaling(scale=1.0 / 127.5, offset=-1.0)(inp)
    x = base(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(256, activation="relu")(x)
    x = layers.Dropout(0.3)(x)
    out = layers.Dense(3, activation="softmax")(x)
    model = models.Model(inp, out)
    model._bb = base
    # registrar la capa por su nombre para rescatarla al recargar
    base._name = "_bb"
    return model, name_used


def save_json(out_dir, name, obj):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / name).write_text(json.dumps(obj, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  -> {out_dir / name}")


def plot_confusion(cm, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.figure(figsize=(6, 5))
    plt.imshow(cm, cmap="Blues")
    for i in range(3):
        for j in range(3):
            plt.text(j, i, str(cm[i, j]), ha="center", va="center")
    plt.xticks([0, 1, 2], CLASSES)
    plt.yticks([0, 1, 2], CLASSES)
    plt.title("Confusion Matrix - V7")
    plt.tight_layout()
    plt.savefig(out, dpi=150)
    plt.close()
    print(f"  -> {out}")


def compara_v3_v7(m7, out_dir):
    out_dir = Path(out_dir)
    if not V3_METRICS.exists():
        print("  Aviso: metrics_v3.json no existe; no se genera comparison_v3_v7.json")
        return
    m3 = json.loads(V3_METRICS.read_text(encoding="utf-8"))
    def rc(m, c):
        try:
            return m["per_class"][CLASSES[c]]["recall"]
        except Exception:
            return None
    comparacion = {
        "v3": {"accuracy": m3.get("accuracy"), "f1_macro": m3.get("f1_macro"),
               "balanced_accuracy": m3.get("balanced_accuracy"),
               "recall_saludable": rc(m3, 0), "recall_contaminado": rc(m3, 1),
               "recall_desconocido": rc(m3, 2)},
        "v7": {"accuracy": m7["accuracy"], "f1_macro": m7["f1_macro"],
               "balanced_accuracy": m7["balanced_accuracy"],
               "recall_saludable": rc(m7, 0), "recall_contaminado": rc(m7, 1),
               "recall_desconocido": rc(m7, 2)},
        "mejora_v7_sobre_v3": {
            "f1_macro": (m7["f1_macro"] - m3.get("f1_macro", 0)) if m3.get("f1_macro") is not None else None,
            "balanced_accuracy": (m7["balanced_accuracy"] - m3.get("balanced_accuracy", 0))
            if m3.get("balanced_accuracy") is not None else None,
        },
        "decision": "V7 candidato solo si f1_macro y balanced accuracy superan claramente a V3; "
                    "no se activa automaticamente.",
    }
    (out_dir / "comparison_v3_v7.json").write_text(
        json.dumps(comparacion, indent=2, ensure_ascii=False), encoding="utf-8")
    print("  -> comparison_v3_v7.json")


# np helpers (evitan importar numpy al definir main)
def np_random(seed):
    import numpy as np
    return np.random.default_rng(seed)


def np_array(lst):
    import numpy as np
    return np.array(lst, dtype=np.float32)


def np_where(arr):
    import numpy as np
    return np.where(arr)[0]


def np_full(n, val, dtype=None):
    import numpy as np
    return np.full(n, val, dtype=dtype)


def np_concatenate(parts, axis=0):
    import numpy as np
    return np.concatenate(parts, axis=axis)


def np_argmax(a, axis=1):
    import numpy as np
    return np.argmax(a, axis=axis)


def np_max(a, axis=1):
    import numpy as np
    return np.max(a, axis=axis)


def np_sum(a):
    import numpy as np
    return np.sum(a)


GAMMA_DEFAULT = 2.0


def main():
    ap = argparse.ArgumentParser(description="Entrenamiento V7 (leakage-safe, reproducible)")
    ap.add_argument("--seed", type=int, default=SEED_DEFAULT)
    ap.add_argument("--manifest", type=Path, default=MANIFEST_DEFAULT)
    ap.add_argument("--epochs-phase1", type=int, default=PHASE1_EPOCHS_DEFAULT)
    ap.add_argument("--epochs-phase2", type=int, default=PHASE2_EPOCHS_DEFAULT)
    ap.add_argument("--batch", type=int, default=BATCH_DEFAULT)
    ap.add_argument("--lr1", type=float, default=LR1_DEFAULT)
    ap.add_argument("--lr2", type=float, default=LR2_DEFAULT)
    ap.add_argument("--image-size", type=int, default=224, help="lado del cuadrado (224)")
    ap.add_argument("--arch", default="efficientnetb1",
                    help="backbone preferido (fallback: efficientnetb2/mobilenetv3/mobilenetv2)")
    ap.add_argument("--out-dir", type=Path, default=OUT_DIR_DEFAULT)
    args = ap.parse_args()
    pipeline(args)


if __name__ == "__main__":
    main()