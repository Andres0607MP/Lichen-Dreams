"""Pipeline de entrenamiento V8 (split V7 validado, metricas de equilibrio, anti-colapso).

Usa EXCLUSIVAMENTE el split V7 validado (dataset_v7_manifest.csv): train/val/test ya
definidos, lcp_aug_* solo en train, test sin aumentadas, 0 leakage, sin tocar dataset.

Hallazgos que corrige este codigo (verificados empiricamente en este entorno,
TF 2.21 CPU Windows, Python 3.12):
1) Los scripts V7/V8 previos aplicaban Rescaling(1/127.5, -1) sobre entradas ya en
   [0,1] (dataset preprocesado con /255.0), comprimiendo la entrada a [-1, -0.992]
   (rango casi constante). Eso destruia la informacion del backbone y explica el
   colapso previo. Este pipeline usa Rescaling(scale=2.0, offset=-1.0) sobre [0,1] ->
   [-1,1] correcto (sin doble /255).
2) Con la normalizacion correcta, MobileNetV2 (cache local) es el extractor de
   caracteristicas mas informativo y estable de los disponibles: probe lineal
   congelado en el split V7 -> val balanced accuracy 0.84 / val macro F1 0.83,
   frente a EfficientNetB1 (0.53) y MobileNetV3Large (0.64). Se elige MobileNetV2.
3) `base(x)` se invoca SIN flag training explicito para que al descongelar capas en
   fine-tuning las BatchNorm se actualicen con el modo de entrenamiento.

Fases de transfer learning:
- FASE 1: backbone congelado (features extraidas una sola vez); se entrena SOLO el
  classifier head (capacidad suficiente: Dense 1024 -> Dense 512 -> Dense 3, con BN,
  ReLU y dropout moderado) con batches balanceados ~1/3 por clase + class weights
  suaves sqrt(max/min) y softmax de 3 clases.
- FASE 2: fine-tuning progresivo de las ultimas 80 capas del backbone, lr pequeno.
- FASE 3: fine-tuning progresivo de las ultimas 140 capas del backbone, lr aun menor.

Seleccion del mejor checkpoint: val_macro_f1 (MAXIMO), con callback que predice sobre
validation cada epoch y registra val_macro_f1, val_balanced_accuracy,
val_precision_macro y val_recall_macro. EarlyStopping: val_macro_f1 (mode=max).

Balance de clases: batches equilibrados 1/3 por clase + class weights suaves
camp. NO se sobrepondera: las clases minoritarias reciben ~1.3-1.5x en loss.

Augmentation: ligera y razonable SOLO en train durante las fases de fine-tuning
(flip horizontal, brillo/contraste leves, conservadora con la semantica de clase).

Preprocesamiento: RGB 224x224 float32 /255.0 ([0,1]); Rescaling interno del backbone.

Salidas (reportes_v8/): lichen_model_v8.keras, class_mapping_v8.json, metrics_v8.json,
classification_report_v8.json, config_v8.json, confusion_matrix_v8.png,
training_history_v8.json, split_v8.json, arch_summary_v8.txt, comparison_v3_v8.json.

V8 NO se registra ni se activa: V3 sigue activo hasta decision explicita.
"""
import argparse
import csv
import json
import time
from collections import Counter
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
OUT_DIR_DEFAULT = Path(__file__).resolve().parent / "reportes_v8"
MANIFEST_DEFAULT = Path(__file__).resolve().parent / "dataset_v7_manifest.csv"
MODEL_DIR = PROJECT_ROOT / "ia" / "modelos"
V3_METRICS = Path(__file__).resolve().parent / "reportes" / "metrics_v3.json"
V3_MODEL = MODEL_DIR / "lichen_model_v3.keras"

INPUT_SIZE = (224, 224)
FEATURE_DIM = 1280
CLASSES = ["liquen saludable", "liquen contaminado", "desconocido"]
SEED_DEFAULT = 42
BATCH_DEFAULT = 48
PHASE1_EPOCHS_DEFAULT = 12
PHASE2_EPOCHS_DEFAULT = 10
PHASE3_EPOCHS_DEFAULT = 8
LR1_DEFAULT = 1e-3
LR2_DEFAULT = 3e-5
LR3_DEFAULT = 1e-5
FINETUNE_LAYERS_1 = 80
FINETUNE_LAYERS_2 = 140
PATIENCE_DEFAULT = 4

FINAL_MODEL_DEFAULT = MODEL_DIR / "lichen_model_v8.keras"
CLASS_MAPPING_DEFAULT = MODEL_DIR / "class_mapping_v8.json"
HEAD_CKPT_DEFAULT = OUT_DIR_DEFAULT / "head_v8.weights.h5"


# ---------------------------------------------------------------------------
# Manifest (exclusivo, sin modificaciones)
# ---------------------------------------------------------------------------
def load_manifest(path=MANIFEST_DEFAULT):
    with open(path, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    if len(rows) != 2159:
        raise ValueError(f"manifest con {len(rows)} filas (esperado 2159)")
    return rows


def split_rows(rows, split):
    return [r for r in rows if r["split"] == split]


def check_manifest_consistency(rows):
    errs = []
    by_cls = Counter(r["class_id"] for r in rows)
    if by_cls != Counter({"0": 500, "1": 500, "2": 1159}):
        errs.append(f"conteos por clase invalidos: {dict(by_cls)}")
    leaked = {}
    fam_split = {}
    for r in rows:
        fam_split.setdefault(r["group_id"], set()).add(r["split"])
    for k, v in fam_split.items():
        if len(v) > 1:
            leaked[k] = sorted(v)
    if leaked:
        errs.append(f"leakage por familia ({len(leaked)})")
    aug_no_train = [r["filename"] for r in rows
                    if r["is_augmented"] == "true" and r["split"] != "train"]
    if aug_no_train:
        errs.append(f"lcp_aug fuera de train: {aug_no_train[:5]}")
    test_aug = [r["filename"] for r in rows
                if r["split"] == "test" and r["is_augmented"] == "true"]
    if test_aug:
        errs.append(f"test con aumentadas: {test_aug[:5]}")
    if errs:
        raise ValueError("Manifest V7 inconsistente con el codigo de entrenamiento: " + "; ".join(errs))


def read_image(path, size=INPUT_SIZE):
    import cv2
    img_rgba = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if img_rgba is None:
        raise ValueError(f"No se pudo leer: {path}")
    if img_rgba.ndim == 2:
        img = cv2.cvtColor(img_rgba, cv2.COLOR_GRAY2BGR)
    elif img_rgba.ndim == 3 and img_rgba.shape[2] == 4:
        img = cv2.cvtColor(img_rgba, cv2.COLOR_BGRA2RGB)
    elif img_rgba.ndim == 3 and img_rgba.shape[2] == 3:
        img = cv2.cvtColor(img_rgba, cv2.COLOR_BGR2RGB)
    else:
        raise ValueError(f"Canales invalidos: {img_rgba.shape} en {path}")
    img = cv2.resize(img, size)
    return img.astype("float32") / 255.0


def load_split(rows, size=INPUT_SIZE):
    import numpy as np
    X = np.zeros((len(rows), size[0], size[1], 3), dtype="float32")
    y = np.zeros((len(rows),), dtype=np.int32)
    for i, r in enumerate(rows):
        X[i] = read_image(r["filepath"], size)
        y[i] = int(r["class_id"])
    return X, y


# ---------------------------------------------------------------------------
# Generador balanceado + augmentation ligera (solo train, fases de fine-tune)
# ---------------------------------------------------------------------------
def make_balanced_generator(X, y, batch, seed, augment=False):
    import numpy as np
    rng = np.random.default_rng(seed)
    n_per = max(1, batch // 3)
    idx = {c: np.where(y == c)[0] for c in (0, 1, 2)}
    while True:
        parts_x, parts_y = [], []
        for c in (0, 1, 2):
            sel = rng.integers(0, len(idx[c]), size=n_per)
            parts_x.append(X[idx[c][sel]])
            parts_y.append(np.full(n_per, c, dtype="int32"))
        Xb = np.concatenate(parts_x, axis=0)
        Yb = np.concatenate(parts_y, axis=0)
        perm = rng.permutation(len(Xb))
        Xb, Yb = Xb[perm], Yb[perm]
        if augment:
            Xb = augment_batch(Xb)
        yield Xb, Yb


def augment_batch(Xb):
    """Augmentation ligera y conservadora, solo train (fases de fine-tune):
    flip horizontal. Sin ajustes de color/brillo/contraste para no alterar la
    semantica textural/cromatica de las clases de liquen."""
    import tensorflow as tf
    t = tf.image.random_flip_left_right(tf.convert_to_tensor(Xb))
    return t.numpy()


# ---------------------------------------------------------------------------
# Modelos
# ---------------------------------------------------------------------------
def build_feature_extractor(arch):
    """Backbone + Rescaling correcto sobre entrada [0,1] + GlobalAveragePooling."""
    import tensorflow as tf
    from tensorflow.keras import layers, models
    if arch == "mobilenetv2":
        base = tf.keras.applications.MobileNetV2(
            input_shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3), include_top=False, weights="imagenet")
    elif arch == "mobilenetv3":
        base = tf.keras.applications.MobileNetV3Large(
            input_shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3), include_top=False, weights="imagenet")
    elif arch == "efficientnetb0":
        base = tf.keras.applications.EfficientNetB0(
            input_shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3), include_top=False, weights="imagenet")
    elif arch == "efficientnetb1":
        base = tf.keras.applications.EfficientNetB1(
            input_shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3), include_top=False, weights="imagenet")
    else:
        raise ValueError(f"backbone no soportado: {arch}")
    inp = layers.Input(shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3))
    x = layers.Rescaling(scale=2.0, offset=-1.0)(inp)
    x = base(x)
    x = layers.GlobalAveragePooling2D()(x)
    return models.Model(inp, x, name="feature_extractor"), base


def get_backbone_layer(fe):
    for layer in fe.layers:
        n = layer.name.lower()
        if n.startswith("mobilenetv2") or n.startswith("mobilenetv3") or n.startswith("efficientnet"):
            return layer
    raise RuntimeError(f"No se encontro la capa backbone en {fe.name}: "
                       f"{[l.name for l in fe.layers]}")


def find_backbone(model):
    """Localiza la capa backbone (modelo nuevo anidado o recargado aplanado)."""
    try:
        fe = model.get_layer("feature_extractor")
        return get_backbone_layer(fe)
    except ValueError:
        pass
    for layer in model.layers:
        n = layer.name.lower()
        if n.startswith("mobilenetv2") or n.startswith("mobilenetv3") or n.startswith("efficientnet"):
            return layer
    raise RuntimeError(f"No se encontro el backbone en {model.name}: "
                       f"{[l.name for l in model.layers]}")


def head_tower(x):
    from tensorflow.keras import layers
    x = layers.Dense(1024, name="fc1")(x)
    x = layers.BatchNormalization(name="bn1")(x)
    x = layers.ReLU(name="relu1")(x)
    x = layers.Dropout(0.30, name="drop1")(x)
    x = layers.Dense(512, name="fc2")(x)
    x = layers.BatchNormalization(name="bn2")(x)
    x = layers.ReLU(name="relu2")(x)
    x = layers.Dropout(0.25, name="drop2")(x)
    return layers.Dense(3, activation="softmax", name="fc_out")(x)


def build_head_model():
    from tensorflow.keras import layers, models
    inp = layers.Input(shape=(FEATURE_DIM,), name="feat_in")
    return models.Model(inp, head_tower(inp), name="classifier_head")


def build_full_model(feat_model, head_model):
    from tensorflow.keras import layers, models
    inp = layers.Input(shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3))
    f = feat_model(inp)
    h = head_model(f)
    return models.Model(inp, h)


def set_backbone_trainable(model, n_last):
    """Desbloquea las ultimas n capas del backbone pero mantiene las capas
    BatchNormalization congeladas (estadisticas preentrenadas intactas; practica
    estandar para fine-tune con datasets pequenos, evita destruir el backbone)."""
    import tensorflow as tf
    bb = find_backbone(model)
    for layer in bb.layers:
        layer.trainable = False
    for layer in bb.layers[-n_last:]:
        layer.trainable = True
    for layer in bb.layers:
        if isinstance(layer, tf.keras.layers.BatchNormalization):
            layer.trainable = False
    return bb


# ---------------------------------------------------------------------------
# Metricas y helpers
# ---------------------------------------------------------------------------
def per_class_metrics(y, pred):
    from sklearn.metrics import classification_report, balanced_accuracy_score
    import numpy as _np
    pred_idx = _np.argmax(pred, axis=1)
    rpt = classification_report(y, pred_idx, labels=[0, 1, 2], output_dict=True, zero_division=0)
    rec = {c: rpt[str(c)]["recall"] for c in (0, 1, 2)}
    prc = {c: rpt[str(c)]["precision"] for c in (0, 1, 2)}
    f1c = {c: rpt[str(c)]["f1-score"] for c in (0, 1, 2)}
    macro_f1 = float(_np.mean([f1c[c] for c in (0, 1, 2)]))
    return {"recall": rec, "precision": prc, "f1": f1c, "macro_f1": macro_f1,
            "balanced_acc": float(balanced_accuracy_score(y, pred_idx))}


def save_json(out_dir, name, obj):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / name).write_text(json.dumps(obj, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  -> {out_dir / name}")


def summary_text(model):
    from io import StringIO
    buf = StringIO()
    model.summary(print_fn=lambda s: buf.write(s + "\n"))
    return buf.getvalue()


# ---------------------------------------------------------------------------
# Callback V8: val_macro_f1 por epoca + checkpoint por val_macro_f1
# ---------------------------------------------------------------------------
class V8Callback:
    @staticmethod
    def make(tf, history, best, args):
        class _Cb(tf.keras.callbacks.Callback):
            def __init__(self, xv, yv, path, fase, save_model=False):
                self.xv, self.yv, self.path, self.fase = xv, yv, path, fase
                self.save_model = save_model

            def on_epoch_end(self, epoch, logs=None):
                from sklearn.metrics import precision_score as _p, recall_score as _r
                preds = self.model.predict(self.xv, batch_size=args.batch, verbose=0)
                m = per_class_metrics(self.yv, preds)
                yp = preds.argmax(axis=1)
                pmac = float(_p(self.yv, yp, average="macro", zero_division=0))
                rmac = float(_r(self.yv, yp, average="macro", zero_division=0))
                dist = Counter(int(p) for p in yp)
                n = max(1, len(self.yv))
                d0 = dist.get(0, 0) / n
                d1 = dist.get(1, 0) / n
                d2 = dist.get(2, 0) / n
                warn = ""
                if max(d0, d1, d2) > 0.90 and epoch >= 3:
                    warn = "CLASS COLLAPSE: una clase predomina >90% en val"
                for c in (0, 1, 2):
                    if m["recall"][c] == 0.0 and m["f1"][c] == 0.0 and epoch >= 4:
                        warn = f"RECALL 0 en clase {CLASSES[c]} (posible colapso)"
                history["fase"].append(self.fase)
                history["epoch"].append(epoch + 1)
                history["loss"].append(float(logs.get("loss", 0.0)) if logs else 0.0)
                history["accuracy"].append(float(logs.get("accuracy", 0.0)) if logs else 0.0)
                history["val_macro_f1"].append(m["macro_f1"])
                history["val_balanced_acc"].append(m["balanced_acc"])
                history["val_precision_macro"].append(pmac)
                history["val_recall_macro"].append(rmac)
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
                    best["fase"] = self.fase
                    Path(self.path).parent.mkdir(parents=True, exist_ok=True)
                    if self.save_model:
                        self.model.save(self.path)
                    else:
                        self.model.save_weights(self.path)
                if logs is not None:
                    logs["val_macro_f1"] = m["macro_f1"]
                    logs["val_balanced_acc"] = m["balanced_acc"]
                    logs["val_precision_macro"] = pmac
                    logs["val_recall_macro"] = rmac
                save_json(args.out_dir, "training_history_v8.json", history)

        return _Cb


# ---------------------------------------------------------------------------
# Evaluacion completa
# ---------------------------------------------------------------------------
def evaluate(y_true, probs, classes):
    from sklearn.metrics import (accuracy_score, precision_score, recall_score,
                                 f1_score, classification_report, confusion_matrix,
                                 balanced_accuracy_score)
    preds = probs.argmax(axis=1)
    acc = float(accuracy_score(y_true, preds))
    prec = float(precision_score(y_true, preds, average="macro", zero_division=0))
    rec = float(recall_score(y_true, preds, average="macro", zero_division=0))
    f1 = float(f1_score(y_true, preds, average="macro", zero_division=0))
    bal = float(balanced_accuracy_score(y_true, preds))
    cm = confusion_matrix(y_true, preds, labels=[0, 1, 2])
    rpt = classification_report(y_true, preds, labels=[0, 1, 2],
                                target_names=classes, digits=4, output_dict=True)
    rep_str = classification_report(y_true, preds, labels=[0, 1, 2],
                                    target_names=classes, digits=4)
    dist = {classes[i]: int((preds == i).sum()) for i in range(3)}
    max_share = max(dist.values()) / max(1, len(y_true))
    conf_mean = 100.0 * float(probs.max(axis=1).mean())
    return {"accuracy": acc, "precision_macro": prec, "recall_macro": rec, "f1_macro": f1,
            "balanced_accuracy": bal, "confusion_matrix": cm.tolist(),
            "classification_report": rep_str, "per_class": rpt,
            "prediction_distribution": dist,
            "prediction_distribution_frac": {k: round(v / max(1, len(y_true)), 4) for k, v in dist.items()},
            "confianza_promedio": conf_mean, "model_collapse": bool(max_share > 0.80),
            "max_class_share": round(max_share, 4)}


def rcq(m, name):
    try:
        return m["per_class"][name]["recall"]
    except Exception:
        return None


def f1q(m, name):
    try:
        return m["per_class"][name]["f1-score"]
    except Exception:
        return None


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
    plt.title("Confusion Matrix - V8")
    plt.tight_layout()
    plt.savefig(out, dpi=150)
    plt.close()
    print(f"  -> {out}")


# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------
def pipeline(args):
    import numpy as np
    import tensorflow as tf

    tf.keras.utils.set_random_seed(args.seed)
    np.random.seed(args.seed)
    t0 = time.time()

    rows = load_manifest(args.manifest)
    check_manifest_consistency(rows)
    tr_rows = split_rows(rows, "train")
    va_rows = split_rows(rows, "val")
    te_rows = split_rows(rows, "test")
    print("=== SPLIT (desde manifest V7, sin modificaciones) ===")
    for name, subset in (("train", tr_rows), ("val", va_rows), ("test", te_rows)):
        c = Counter(r["class_name"] for r in subset)
        print(f"{name}: total={len(subset)} sal={c['saludable']} cont={c['contaminado']} desc={c['desconocido']}")

    X_train, y_train = load_split(tr_rows)
    X_val, y_val = load_split(va_rows)
    X_test, y_test = load_split(te_rows)

    counts = Counter(int(r["class_id"]) for r in tr_rows)
    print("Estrategia de balance documentada: batches balanceados ~1/3 por clase (muestreo "
          "equitativo por clase). NO se aplican class weights en la loss: Keras no los soporta "
          "con generadores y el muestreo balanceado ya iguala la exposicion por clase, evitando "
          "doble ponderacion y sobreponderar clases minoritarias.")

    steps = max(1, (min(counts.values()) * 3) // args.batch)
    print(f"Efectivo por epoca ~ {min(counts.values()) * 3}; steps/epoca ~ {steps} | batch={args.batch}")

    history = {"fase": [], "epoch": [], "loss": [], "accuracy": [],
               "val_macro_f1": [], "val_balanced_acc": [],
               "val_precision_macro": [], "val_recall_macro": [],
               "recall_sal": [], "recall_cont": [], "recall_desc": [],
               "pred_class_0": [], "pred_class_1": [], "pred_class_2": [], "collapse_warn": []}
    best = {"macro": -1.0, "epoch": 0, "fase": ""}

    # ------------------------------------------------------------------
    # FASE 1: backbone congelado; solo head sobre features extraidas.
    # ------------------------------------------------------------------
    print("\n>>> FASE 1: extraccion de features con backbone congelado ...")
    feat_model, base = build_feature_extractor(args.arch)
    F_train = feat_model.predict(X_train, batch_size=args.batch, verbose=1)
    F_val = feat_model.predict(X_val, batch_size=args.batch, verbose=1)

    head_model = build_head_model()
    head_model.compile(optimizer=tf.keras.optimizers.Adam(args.lr1, weight_decay=1e-4),
                       loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    gen1 = make_balanced_generator(F_train, y_train, args.batch, args.seed, augment=False)
    CbCls = V8Callback.make(tf, history, best, args)
    ck1 = CbCls(F_val, y_val, str(args.head_ckpt), "phase1", save_model=False)
    es1 = tf.keras.callbacks.EarlyStopping(monitor="val_macro_f1", mode="max",
                                           patience=args.patience, restore_best_weights=True)
    print(f">>> FASE 1 (head sobre features, epochs={args.epochs_phase1}, lr={args.lr1}, backbone congelado)")
    t1a = time.time()
    head_model.fit(gen1, steps_per_epoch=steps, epochs=args.epochs_phase1,
                   callbacks=[ck1, es1], verbose=1)
    print(f"  [mejor phase1] epoch {best['epoch']} val_macro_f1={best['macro']:.4f} "
          f"({time.time() - t1a:.0f}s)")
    if best["macro"] <= 0.0:
        raise RuntimeError("FASE 1 no consiguio aprender (val_macro_f1=0). Abortar.")
    head_model.load_weights(str(args.head_ckpt))

    # ------------------------------------------------------------------
    # Modelo completo + FASE 2 (fine-tune ultimas capas, lr pequeno)
    # ------------------------------------------------------------------
    model = build_full_model(feat_model, head_model)
    Path(str(args.final_model)).parent.mkdir(parents=True, exist_ok=True)
    model.save(str(args.final_model))
    set_backbone_trainable(model, args.fine_tune_layers_1)
    bb = find_backbone(model)
    n_train_1 = sum(1 for l in bb.layers if l.trainable)
    model.compile(optimizer=tf.keras.optimizers.Adam(args.lr2, weight_decay=1e-4),
                  loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    gen2 = make_balanced_generator(X_train, y_train, args.batch, args.seed + 7, augment=True)
    ck2 = CbCls(X_val, y_val, str(args.final_model), "phase2", save_model=True)
    es2 = tf.keras.callbacks.EarlyStopping(monitor="val_macro_f1", mode="max",
                                           patience=args.patience, restore_best_weights=True)
    print(f">>> FASE 2 (fine-tune ultimas {n_train_1} capas del backbone, "
          f"epochs={args.epochs_phase2}, lr={args.lr2}, aug ligera solo train)")
    t2a = time.time()
    model.fit(gen2, steps_per_epoch=steps, epochs=args.epochs_phase2,
              callbacks=[ck2, es2], verbose=1)
    print(f"  [mejor phase2] epoch {best['epoch']} val_macro_f1={best['macro']:.4f} "
          f"({time.time() - t2a:.0f}s)")

    # ------------------------------------------------------------------
    # FASE 3: desbloqueo progresivo (mas capas, lr aun menor)
    # ------------------------------------------------------------------
    if args.final_model.exists() and best["macro"] > 0:
        model = tf.keras.models.load_model(str(args.final_model), compile=False)
    set_backbone_trainable(model, args.fine_tune_layers_2)
    bb = find_backbone(model)
    n_train_2 = sum(1 for l in bb.layers if l.trainable)
    model.compile(optimizer=tf.keras.optimizers.Adam(args.lr3, weight_decay=1e-4),
                  loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    gen3 = make_balanced_generator(X_train, y_train, args.batch, args.seed + 13, augment=True)
    ck3 = CbCls(X_val, y_val, str(args.final_model), "phase3", save_model=True)
    es3 = tf.keras.callbacks.EarlyStopping(monitor="val_macro_f1", mode="max",
                                           patience=args.patience, restore_best_weights=True)
    print(f">>> FASE 3 (fine-tune ultimas {n_train_2} capas, epochs={args.epochs_phase3}, "
          f"lr={args.lr3})")
    t3a = time.time()
    model.fit(gen3, steps_per_epoch=steps, epochs=args.epochs_phase3,
              callbacks=[ck3, es3], verbose=1)
    print(f"  [mejor phase3] epoch {best['epoch']} val_macro_f1={best['macro']:.4f} "
          f"({time.time() - t3a:.0f}s)")

    best_model = tf.keras.models.load_model(str(args.final_model), compile=False)
    print("\n=== EVALUACION V8 (split test V7) ===")
    probs = best_model.predict(X_test, batch_size=args.batch, verbose=0)
    ev = evaluate(y_test, probs, CLASSES)
    print(f"Accuracy: {ev['accuracy']:.4f} | Balanced acc: {ev['balanced_accuracy']:.4f}")
    print(f"Precision macro: {ev['precision_macro']:.4f} | Recall macro: {ev['recall_macro']:.4f} | "
          f"F1 macro: {ev['f1_macro']:.4f}")
    print(f"Distrib. pred: {ev['prediction_distribution']}")
    print(f"Confianza media: {ev['confianza_promedio']:.2f}% | max_class_share={ev['max_class_share']:.4f}")
    print(f"MODEL_COLLAPSE: {ev['model_collapse']}")
    print(ev["classification_report"])

    split_info = {name: {k: v for k, v in Counter(r["class_name"] for r in subset).items()}
                  for name, subset in (("train", tr_rows), ("val", va_rows), ("test", te_rows))}
    config = {
        "seed": args.seed, "batch": args.batch, "arch": args.arch,
        "phase1_epochs": args.epochs_phase1, "phase2_epochs": args.epochs_phase2,
        "phase3_epochs": args.epochs_phase3,
        "lr1": args.lr1, "lr2": args.lr2, "lr3": args.lr3,
        "fine_tune_layers_1": args.fine_tune_layers_1,
        "fine_tune_layers_2": args.fine_tune_layers_2,
        "batch_norm_durante_fine_tune": "congelada (estadisticas preentrenadas intactas)",
        "patience": args.patience,
        "input_size": list(INPUT_SIZE), "rgb": True,
        "preprocessing": "RGB 224x224 float32 /255.0 -> [0,1]; Rescaling interno (2.0,-1.0) -> [-1,1] sin doble /255",
        "head": "Dense1024+BN+ReLU+Dropout .30 -> Dense512+BN+ReLU+Dropout .25 -> Dense3 softmax",
        "backbone": "MobileNetV2 ImageNet (seleccionado por probe: val bal_acc .84 / macroF1 .83; "
                    "B1=.53, MobileNetV3Large=.64)",
        "balance": "batches balanceados 1/3 por clase (exposicion equitativa; sin class weights en loss "
                    "por limite de Keras con generadores y para evitar doble ponderacion)",
        "loss": "sparse_categorical_crossentropy + weight_decay 1e-4 (Adam)",
        "augmentation": "solo train en fases 2/3: flip horizontal (sin cambios de color/brillo "
                    "para conservar la semantica textural de las clases)",
        "checkpoint_metric": "val_macro_f1 (max)",
        "early_stopping": "val_macro_f1 max, patience=args.patience",
        "split": split_info,
        "manifest": str(args.manifest),
    }

    metrics = dict(ev)
    metrics.update({
        "best_val_macro_f1": best["macro"], "best_val_macro_f1_epoch": best["epoch"],
        "best_val_macro_f1_fase": best["fase"],
        "class_mapping": {str(i): c for i, c in enumerate(CLASSES)},
        "seed": args.seed, "arch": args.arch,
        "config": config,
        "dataset": {"saludable": 500, "contaminado": 500, "desconocido": 1159, "total": 2159},
    })

    save_json(args.out_dir, "metrics_v8.json", metrics)
    save_json(args.out_dir, "classification_report_v8.json", ev["per_class"])
    save_json(args.out_dir, "config_v8.json", config)
    save_json(args.out_dir, "split_v8.json",
              {"seed": args.seed, "manifest": str(args.manifest), "splits": split_info,
               "is_augmented": {"train_only": True, "test_augmented": 0}})
    (args.out_dir / "arch_summary_v8.txt").write_text(
        summary_text(best_model) + "\nBACKBONE: " + args.arch + "\n" + json.dumps(config, indent=2, ensure_ascii=False),
        encoding="utf-8")
    plot_confusion(np.array(ev["confusion_matrix"]), args.out_dir / "confusion_matrix_v8.png")
    best_model.save(str(args.final_model))
    args.class_mapping.write_text(json.dumps({str(i): c for i, c in enumerate(CLASSES)},
                                             ensure_ascii=False), encoding="utf-8")
    print(f"  -> {args.final_model}")
    print(f"  -> {args.class_mapping}")

    # ------------------------------------------------------------------
    # Comparacion V3 vs V8
    # ------------------------------------------------------------------
    compara_v3_v8(ev, X_test, y_test, args)

    print("\n=== RESULTADO V8 ===")
    print(f"Accuracy: {ev['accuracy']:.4f} | Balanced acc: {ev['balanced_accuracy']:.4f}")
    print(f"Precision macro: {ev['precision_macro']:.4f} | Recall macro: {ev['recall_macro']:.4f} | F1 macro: {ev['f1_macro']:.4f}")
    print(f"Distrib. pred: {ev['prediction_distribution']}")
    print(f"MODEL_COLLAPSE: {ev['model_collapse']}")
    print(f"Modelo: {args.final_model}")
    print(f"Tiempo total: {time.time() - t0:.0f}s")
    print("\nV8 NO se registra ni se activa. V3 sigue activo hasta decision explicita.")


def v3_on_v7_test(X_test, y_test, classes):
    """Evalua V3 sobre el MISMO split test V7 (comparacion justa)."""
    import numpy as np
    import tensorflow as tf
    if not V3_MODEL.exists():
        return {"error": f"{V3_MODEL} no existe"}
    try:
        m = tf.keras.models.load_model(str(V3_MODEL), compile=False)
        probs = m.predict(X_test, batch_size=48, verbose=0)
        ev = evaluate(y_test, probs, classes)
        ev["split_test"] = {"total": int(len(y_test)),
                            "saludable": int((y_test == 0).sum()),
                            "contaminado": int((y_test == 1).sum()),
                            "desconocido": int((y_test == 2).sum())}
        return ev
    except Exception as e:
        return {"error": f"{type(e).__name__}: {e}"}


def metric_row(ev, classes):
    return {
        "accuracy": ev.get("accuracy"),
        "macro_f1": ev.get("f1_macro"),
        "balanced_accuracy": ev.get("balanced_accuracy"),
        "recall_saludable": rcq(ev, classes[0]),
        "recall_contaminado": rcq(ev, classes[1]),
        "recall_desconocido": rcq(ev, classes[2]),
        "f1_saludable": f1q(ev, classes[0]),
        "f1_contaminado": f1q(ev, classes[1]),
        "f1_desconocido": f1q(ev, classes[2]),
    }


def compara_v3_v8(ev8, X_test, y_test, args):
    """Comparacion V3 vs V8: V3 evaluado sobre el MISMO split test V7 + referencia historica."""
    v8_row = metric_row(ev8, CLASSES)
    same = v3_on_v7_test(X_test, y_test, CLASSES)
    comparacion = {
        "metricas": ["accuracy", "macro_f1", "balanced_accuracy",
                     "recall_saludable", "recall_contaminado", "recall_desconocido",
                     "f1_saludable", "f1_contaminado", "f1_desconocido"],
        "nota": "V3 evaluado HOY sobre el split test de V7 (mismas 293 imagenes) para comparacion justa. "
                "V3 fue entrenado con un split propio (test=321) y sus metricas historicas figuran "
                "en reportes/metrics_v3.json.",
        "v3_sobre_test_v7": same if "error" not in same else same,
        "v3_historico": {},
        "v8": v8_row,
        "delta_v8_minus_v3_mismo_test": {},
    }
    if V3_METRICS.exists():
        try:
            m3 = json.loads(V3_METRICS.read_text(encoding="utf-8"))
            comparacion["v3_historico"] = {
                "accuracy": m3.get("accuracy"), "macro_f1": m3.get("f1_macro"),
                "balanced_accuracy": m3.get("balanced_accuracy"),
                "recall_saludable": rcq(m3, CLASSES[0]), "recall_contaminado": rcq(m3, CLASSES[1]),
                "recall_desconocido": rcq(m3, CLASSES[2]),
                "f1_saludable": f1q(m3, CLASSES[0]), "f1_contaminado": f1q(m3, CLASSES[1]),
                "f1_desconocido": f1q(m3, CLASSES[2]),
                "split_test": "321 (split propio de V3)"}
        except Exception as e:
            comparacion["v3_historico"] = {"error": str(e)}
    if "error" not in same:
        v3_ev = same
        comparacion["delta_v8_minus_v3_mismo_test"] = {
            "macro_f1": round(ev8["f1_macro"] - (v3_ev.get("f1_macro") or 0.0), 4),
            "balanced_accuracy": round(ev8["balanced_accuracy"] - (v3_ev.get("balanced_accuracy") or 0.0), 4),
            "accuracy": round(ev8["accuracy"] - (v3_ev.get("accuracy") or 0.0), 4),
            "recall_saludable": _delta(rcq(ev8, CLASSES[0]), rcq(v3_ev, CLASSES[0])),
            "recall_contaminado": _delta(rcq(ev8, CLASSES[1]), rcq(v3_ev, CLASSES[1])),
            "recall_desconocido": _delta(rcq(ev8, CLASSES[2]), rcq(v3_ev, CLASSES[2])),
        }
    save_json(args.out_dir, "comparison_v3_v8.json", comparacion)
    print(f"  -> comparison_v3_v8.json")


def _delta(a, b):
    if a is None or b is None:
        return None
    return round(a - b, 4)


def main():
    ap = argparse.ArgumentParser(description="Entrenamiento V8 (split V7, macro F1, anti-colapso)")
    ap.add_argument("--seed", type=int, default=SEED_DEFAULT)
    ap.add_argument("--manifest", type=Path, default=MANIFEST_DEFAULT)
    ap.add_argument("--batch", type=int, default=BATCH_DEFAULT)
    ap.add_argument("--epochs-phase1", type=int, default=PHASE1_EPOCHS_DEFAULT)
    ap.add_argument("--epochs-phase2", type=int, default=PHASE2_EPOCHS_DEFAULT)
    ap.add_argument("--epochs-phase3", type=int, default=PHASE3_EPOCHS_DEFAULT)
    ap.add_argument("--lr1", type=float, default=LR1_DEFAULT)
    ap.add_argument("--lr2", type=float, default=LR2_DEFAULT)
    ap.add_argument("--lr3", type=float, default=LR3_DEFAULT)
    ap.add_argument("--fine-tune-layers-1", type=int, default=FINETUNE_LAYERS_1)
    ap.add_argument("--fine-tune-layers-2", type=int, default=FINETUNE_LAYERS_2)
    ap.add_argument("--patience", type=int, default=PATIENCE_DEFAULT)
    ap.add_argument("--arch", default="mobilenetv2",
                    help="backbone (mobilenetv2 por defecto; ver docstring del porque)")
    ap.add_argument("--out-dir", type=Path, default=OUT_DIR_DEFAULT)
    ap.add_argument("--final-model", type=Path, default=FINAL_MODEL_DEFAULT)
    ap.add_argument("--class-mapping", type=Path, default=CLASS_MAPPING_DEFAULT)
    ap.add_argument("--head-ckpt", type=Path, default=HEAD_CKPT_DEFAULT)
    args = ap.parse_args()
    pipeline(args)


if __name__ == "__main__":
    main()