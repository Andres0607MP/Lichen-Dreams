"""Entrenamiento V6 - aprovechando la senal textural.

Reglas aplicadas desde la auditoria:
- Split anti-leakage: lcp_* + lcp_aug_* SOLO en TRAIN; val/test de contaminados
  UNICAMENTE con lc_*. Saludables y desconocidos se dividen 70/15/15 (los
  desconocidos se dividen por subcarpeta entera para no repartir categorias).
- Batches equilibrados (las 3 clases aportan ~1/3 por batch, sobremuestreando
  minoritarias en memoria; NO se toca el dataset).
- Focal loss multiclase (gamma 2, alpha balanceado por la distribucion de train).
- Transfer learning dos fases; preprocessing del backbone ([-1,1]) dentro del
  modelo para que la inferencia del backend (/255) sea identica.
- Metricas por clase en validation; decision por macro F1 (no solo accuracy).
"""
import json
import time
from pathlib import Path

import cv2
import numpy as np
from tensorflow import keras

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
DATASET_DIR = PROJECT_ROOT / "ia" / "datasets"
MODEL_DIR = PROJECT_ROOT / "ia" / "modelos"
REPORTS_DIR = PROJECT_ROOT / "ia" / "entrenamiento" / "reportes"
REPORTS_DIR.mkdir(parents=True, exist_ok=True)

INPUT_SIZE = (224, 224)
CLASSES = ["liquen saludable", "liquen contaminado", "desconocido"]
EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
FINAL_MODEL = MODEL_DIR / "lichen_model_v6.keras"
CLASS_MAPPING = MODEL_DIR / "class_mapping_v6.json"
BATCH = 24
GAMMA = 2.0
PHASE1_EPOCHS = 10
PHASE2_EPOCHS = 12
LR1 = 1e-3
LR2 = 1e-4


def flat(folder):
    return [p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in EXT]


def list_sub(path):
    """Lista archivos por subcarpeta (para desconocidos)."""
    out = []
    for sub in sorted(path.iterdir()):
        if sub.is_dir():
            out.append([p for p in sub.iterdir() if p.is_file() and p.suffix.lower() in EXT])
    return out


def read_array(paths):
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
    return X


def build_splits():
    sal = flat(DATASET_DIR / "liquenes_saludables")
    cont = flat(DATASET_DIR / "liquenes_contaminados")
    lc = [p for p in cont if p.name.startswith("lc_") and "aug" not in p.name]
    lcp = [p for p in cont if p.name.startswith("lcp_") and "aug" not in p.name]
    aug = [p for p in cont if "aug" in p.name]

    rng = np.random.default_rng(7)
    rng.shuffle(sal)
    sal_tr, sal_va, sal_te = sal[:350], sal[350:425], sal[425:]

    n_lc = len(lc)
    rng.shuffle(lc)
    lc_tr, lc_va, lc_te = lc[:int(n_lc * 0.6)], lc[int(n_lc * 0.6):int(n_lc * 0.8)], lc[int(n_lc * 0.8):]

    # Desconocidos: dividir por subcarpeta (sin repartir la misma categoria)
    subs = list_sub(DATASET_DIR / "liquenes_desconocidos")
    rng.shuffle(subs)
    n = len(subs)
    n_tr = int(n * 0.7)
    n_va = int(n * 0.15)
    sub_tr = [p for s in subs[:n_tr] for p in s]
    sub_va = [p for s in subs[n_tr:n_tr + n_va] for p in s]
    sub_te = [p for s in subs[n_tr + n_va:] for p in s]

    return {
        "train": {"sal": sal_tr, "cont": lcp + aug + lc_tr, "desc": sub_tr},
        "val": {"sal": sal_va, "cont": lc_va, "desc": sub_va},
        "test": {"sal": sal_te, "cont": lc_te, "desc": sub_te},
    }


def focal_loss(gamma=2.0, alpha=None):
    """Focal loss multiclase estable para etiquetas SPARSE (indices 0..C-1).

    FL = -alpha_t * (1-p_t)^gamma * log(p_t), con p_t = probabilidad de la
    clase real. alpha: vector por clase (balanceado por la distribucion train).
    Usa tf.gather (estable) en lugar de one-hot.
    """
    import tensorflow as tf

    def loss(y_true, y_pred):
        y_pred = tf.clip_by_value(y_pred, keras.backend.epsilon(), 1.0 - keras.backend.epsilon())
        idx = tf.cast(y_true, tf.int32)
        pt = tf.gather(y_pred, idx, batch_dims=1)
        if alpha is not None:
            al = tf.gather(tf.constant(alpha, dtype="float32"), idx)
            return tf.reduce_mean(-al * tf.pow(1.0 - pt, gamma) * tf.math.log(pt))
        return tf.reduce_mean(-tf.pow(1.0 - pt, gamma) * tf.math.log(pt))

    return loss


def build_backbone(name):
    import tensorflow as tf
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


def build_model(base):
    import tensorflow as tf
    from tensorflow.keras import layers, models

    inp = layers.Input(shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3))
    x = layers.Rescaling(scale=1.0 / 127.5, offset=-1.0)(inp)  # preprocessing del backbone
    x = base(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(256, activation="relu")(x)
    x = layers.Dropout(0.3)(x)
    out = layers.Dense(3, activation="softmax")(x)
    mod = models.Model(inp, out)
    # Auxiliares conectados a la cabeza para easy fine-tune
    return mod, base


def balanced_generator(Xs, ys, batch, rng):
    """Batches con contribucion equitativa de las 3 clases (1/3 cada una)."""
    n_per = max(1, batch // 3)
    while True:
        idxs = []
        for cls_data, cls_y in zip(Xs, ys):
            i = rng.integers(0, len(cls_data), size=n_per)
            idxs.append((cls_data[i], cls_y[i]))
        Xb = np.concatenate([t[0] for t in idxs], axis=0)
        Yb = np.concatenate([t[1] for t in idxs], axis=0)
        perm = rng.permutation(len(Xb))
        yield Xb[perm], Yb[perm]


def per_class_metrics(y, pred):
    from sklearn.metrics import classification_report, balanced_accuracy_score, f1_score
    pred_idx = np.argmax(pred, axis=1)
    rpt = classification_report(y, pred_idx, labels=[0, 1, 2], output_dict=True, zero_division=0)
    rec = {c: rpt.get(str(c), {}).get("recall", 0.0) if str(c) in rpt else rpt[c]["recall"] for c in (0, 1, 2)}
    f1 = {c: (rpt[str(c)]["f1-score"] if str(c) in rpt else 0.0) for c in (0, 1, 2)}
    macro = np.mean([f1[c] for c in (0, 1, 2)])
    bal = balanced_accuracy_score(y, pred_idx)
    return {"recall": rec, "f1": f1, "macro_f1": float(macro), "balanced_acc": float(bal)}


def main():
    import tensorflow as tf

    t0 = time.time()
    splits = build_splits()

    def stats(name):
        sp = splits[name]
        return {k: len(v) for k, v in sp.items()}

    print("=== SPLIT (configurado) ===")
    for name in ("train", "val", "test"):
        s = stats(name)
        print(f"{name}: sal={s['sal']} cont={s['cont']} desc={s['desc']} total={sum(s.values())}")

    def load(sp, cls):
        return read_array(sp[cls]), np.full(len(sp[cls]), {"sal": 0, "cont": 1, "desc": 2}[cls])

    tr = {c: load(splits["train"], c) for c in ("sal", "cont", "desc")}
    va = {c: load(splits["val"], c) for c in ("sal", "cont", "desc")}
    te = {c: load(splits["test"], c) for c in ("sal", "cont", "desc")}

    X_val = np.concatenate([va[c][0] for c in ("sal", "cont", "desc")])
    y_val = np.concatenate([va[c][1] for c in ("sal", "cont", "desc")])
    X_test = np.concatenate([te[c][0] for c in ("sal", "cont", "desc")])
    y_test = np.concatenate([te[c][1] for c in ("sal", "cont", "desc")])

    # Efectivo (por epoca): minimo por clase en train -> equilibrio 1/3.
    min_tr = min(len(tr[c][0]) for c in ("sal", "cont", "desc"))
    n_batches = max(1, (min_tr * 3) // BATCH)
    total_per_epoch = min_tr * 3
    counts = {c: len(tr[c][0]) for c in ("sal", "cont", "desc")}
    print(f"\nEfectivo por epoca (sampling equilibrado): {total_per_epoch} "
          f"por epoca; minimo clase train={min_tr}; batches/epoca={n_batches}")
    print(f"Tamaño real train por clase: {counts}")

    total_clases = sum(counts.values())
    alpha = np.array([total_clases / (3 * counts[c]) for c in ("sal", "cont", "desc")], dtype="float32")
    print(f"Alpha focal (balanceado): {alpha.tolist()}")

    # Backbone: intentar EfficientNetB1 -> B2 -> MobileNetV3 -> MobileNetV2
    print("\n>>> Cargando backbone...")
    backbone_name = None
    base = None
    for cand in ["efficientnetb1", "efficientnetb2", "mobilenetv3", "mobilenetv2"]:
        try:
            base = build_backbone(cand)
            backbone_name = cand
            break
        except Exception as e:
            print(f"  {cand} no disponible ({type(e).__name__}: {e}); siguiente...")
    if base is None:
        raise RuntimeError("Ningun backbone preentrenado pudo cargarse (sin red?)")

    model, base = build_model(base)
    print(f"Backbone final: {backbone_name}")

    best_state = {"macro": -1.0}

    class MacroF1Checkpoint(tf.keras.callbacks.Callback):
        def __init__(self, val_x, val_y, save_path):
            super().__init__()
            self.vx, self.vy = val_x, val_y
            self.path = save_path

        def on_epoch_end(self, epoch, logs=None):
            preds = self.model.predict(self.vx, batch_size=BATCH, verbose=0)
            m = per_class_metrics(self.vy, preds)["macro_f1"]
            if m > best_state["macro"]:
                best_state["macro"] = m
                best_state["epoch"] = epoch + 1
                self.model.save(self.path)
            logs["val_macro_f1"] = m

    gen = balanced_generator(
        [tr["sal"][0], tr["cont"][0], tr["desc"][0]],
        [tr["sal"][1], tr["cont"][1], tr["desc"][1]], BATCH, np.random.default_rng(42))

    # FASE 1: backbone congelado
    base.trainable = False
    model.compile(optimizer=tf.keras.optimizers.Adam(LR1), loss=focal_loss(GAMMA, alpha),
                  metrics=["accuracy"])
    ck1 = MacroF1Checkpoint(X_val, y_val, str(FINAL_MODEL))
    print(f"\n>>> FASE 1 ({PHASE1_EPOCHS} epocas, lr {LR1})")
    model.fit(gen, steps_per_epoch=n_batches, epochs=PHASE1_EPOCHS,
              validation_data=(X_val, y_val), callbacks=[ck1], verbose=1)

    # Restaurar mejor de fase 1 y descongelar parcialmente
    if best_state["macro"] >= 0:
        model = tf.keras.models.load_model(str(FINAL_MODEL),
                                           custom_objects={"loss": focal_loss(GAMMA, alpha)})
    # localizamos la subred backbone dentro del modelo cargado
    bb = None
    for layer in model.layers:
        if layer.__class__.__name__.startswith("Functional"):
            bb = layer
            break
    if bb is None:
        raise RuntimeError("No se encontro el submodelo backbone para fine-tune")
    for layer in bb.layers:
        layer.trainable = False
    for layer in bb.layers[-40:]:
        layer.trainable = True
    model.compile(optimizer=tf.keras.optimizers.Adam(LR2), loss=focal_loss(GAMMA, alpha),
                  metrics=["accuracy"])
    ck2 = MacroF1Checkpoint(X_val, y_val, str(FINAL_MODEL))
    print(f"\n>>> FASE 2 (fine-tune {PHASE2_EPOCHS} epocas, lr {LR2})")
    model.fit(gen, steps_per_epoch=n_batches, epochs=PHASE2_EPOCHS,
              validation_data=(X_val, y_val), callbacks=[ck2], verbose=1)

    best = tf.keras.models.load_model(str(FINAL_MODEL),
                                      custom_objects={"loss": focal_loss(GAMMA, alpha)})

    # TEST FINAL
    probs = best.predict(X_test, batch_size=BATCH, verbose=0)
    preds = np.argmax(probs, axis=1)
    from sklearn.metrics import (accuracy_score, precision_score, recall_score,
                                 f1_score, classification_report, confusion_matrix,
                                 balanced_accuracy_score)
    acc = accuracy_score(y_test, preds)
    prec = precision_score(y_test, preds, average="macro", zero_division=0)
    rec = recall_score(y_test, preds, average="macro", zero_division=0)
    f1 = f1_score(y_test, preds, average="macro", zero_division=0)
    bal = balanced_accuracy_score(y_test, preds)
    cm = confusion_matrix(y_test, preds, labels=[0, 1, 2])
    rpt = classification_report(y_test, preds, labels=[0, 1, 2],
                                target_names=CLASSES, digits=4, output_dict=True)
    rep_str = classification_report(y_test, preds, labels=[0, 1, 2],
                                    target_names=CLASSES, digits=4)
    dist = {CLASSES[i]: int(np.sum(preds == i)) for i in range(3)}
    conf_mean = 100.0 * float(np.max(probs, axis=1).mean())

    metrics = {
        "accuracy": float(acc), "precision_macro": float(prec),
        "recall_macro": float(rec), "f1_macro": float(f1),
        "balanced_accuracy": float(bal),
        "confianza_promedio": conf_mean, "prediction_distribution": dist,
        "confusion_matrix": cm.tolist(), "classification_report": rep_str,
        "per_class": rpt,
        "split": {name: stats(name) for name in ("train", "val", "test")},
        "epochs": {"phase1": PHASE1_EPOCHS, "phase2": PHASE2_EPOCHS, "best_val_macro_epoch": best_state.get("epoch")},
        "focal": {"gamma": GAMMA, "alpha": alpha.tolist()},
        "class_mapping": {str(i): c for i, c in enumerate(CLASSES)},
        "backbone": backbone_name,
    }
    (REPORTS_DIR / "metrics_v6.json").write_text(json.dumps(metrics, indent=2, ensure_ascii=False), encoding="utf-8")
    CLASS_MAPPING.write_text(json.dumps({str(i): c for i, c in enumerate(CLASSES)}, ensure_ascii=False), encoding="utf-8")

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
    plt.title("Confusion Matrix V6")
    plt.tight_layout()
    plt.savefig(REPORTS_DIR / "confusion_matrix_v6.png", dpi=150)
    plt.close()

    print("\n=== RESULTADO V6 ===")
    print(f"Backbone: {backbone_name}")
    print(f"Accuracy: {acc:.4f} | Balanced acc: {bal:.4f}")
    print(f"Precision macro: {prec:.4f} | Recall macro: {rec:.4f} | F1 macro: {f1:.4f}")
    print(f"Confianza media: {conf_mean:.2f}% | Distrib. pred: {dist}")
    print(f"Matriz:\n{cm}")
    print(rep_str)
    print(f"Archivo: {FINAL_MODEL}")
    print(f"Tiempo total: {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()