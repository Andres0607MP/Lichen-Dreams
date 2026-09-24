import cv2
import numpy as np
from pathlib import Path
import csv
import json
import tempfile
import os
import sys
import time

sys.path.insert(0, r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend")

# Load model directly from local file (bypassing DB resolver)
import tensorflow as tf

MODEL_PATH = Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\modelos\lichen_model_v8.keras")
CLASS_NAMES = ["liquen saludable", "liquen contaminado", "liquen desconocido"]
INPUT_SIZE = (224, 224)

print("Loading model directly from local file...")
t0 = time.time()
model = tf.keras.models.load_model(str(MODEL_PATH), compile=False)
print(f"Model loaded in {time.time()-t0:.1f}s")
print(f"Model input shape: {model.input_shape}")
print(f"Model output shape: {model.output_shape}")

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
        raise ValueError(f"Formato de imagen no soportado: {img.shape[2]} canales en {image_path}")

    img = cv2.resize(img, INPUT_SIZE)
    img = img.astype(np.float32) / 255.0
    img = np.expand_dims(img, axis=0)
    return img

def predict_with_probs(image_path):
    tensor = _preprocess_image(str(image_path))
    predictions = model.predict(tensor, verbose=0)
    probs = predictions[0].tolist()
    class_index = int(np.argmax(predictions[0]))
    confidence = float(predictions[0][class_index])
    categoria = CLASS_NAMES[class_index]
    return {
        "categoria": categoria,
        "confianza": confidence,
        "probs": dict(zip(CLASS_NAMES, probs)),
        "class_index": class_index
    }

# Image manipulation functions
def crop_lichen(image_path, crop_ratio=0.7):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    ch = int(h * crop_ratio)
    cw = int(w * crop_ratio)
    y1 = (h - ch) // 2
    x1 = (w - cw) // 2
    return img[y1:y1+ch, x1:x1+cw]

def darken_image(image_path, factor=0.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    return cv2.convertScaleAbs(img, alpha=factor, beta=0)

def brighten_image(image_path, factor=1.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    return cv2.convertScaleAbs(img, alpha=factor, beta=0)

def resize_down_up(image_path, scale=0.3):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    small = cv2.resize(img, (int(w*scale), int(h*scale)), interpolation=cv2.INTER_AREA)
    back = cv2.resize(small, (w, h), interpolation=cv2.INTER_CUBIC)
    return back

def crop_more_background(image_path, expand_factor=1.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    new_h = int(h * expand_factor)
    new_w = int(w * expand_factor)
    canvas = np.full((new_h, new_w, 3), 128, dtype=np.uint8)
    y1 = (new_h - h) // 2
    x1 = (new_w - w) // 2
    canvas[y1:y1+h, x1:x1+w] = img
    return canvas

def save_temp_image(img, suffix="_tmp"):
    tf = tempfile.NamedTemporaryFile(suffix=suffix + ".jpg", delete=False)
    cv2.imwrite(tf.name, img)
    return tf.name

# Load test images from manifest
import csv
manifest_path = r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\entrenamiento\dataset_v7_manifest.csv"
with open(manifest_path, encoding="utf-8") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

test_saludable = [r for r in rows if r["split"] == "test" and r["class_name"] == "saludable"][:3]
test_contaminado = [r for r in rows if r["split"] == "test" and r["class_name"] == "contaminado"][:3]
test_desconocido = [r for r in rows if r["split"] == "test" and r["class_name"] == "desconocido"][:3]

print(f"Test samples: saludable={len(test_saludable)}, contaminado={len(test_contaminado)}, desconocido={len(test_desconocido)}")

all_samples = []
for r in test_saludable:
    all_samples.append(("saludable", r["filename"], Path(r["filepath"])))
for r in test_contaminado:
    all_samples.append(("contaminado", r["filename"], Path(r["filepath"])))
for r in test_desconocido:
    all_samples.append(("desconocido", r["filename"], Path(r["filepath"])))

print(f"Test samples: {len(all_samples)} total")

# Image manipulation functions
def crop_lichen(image_path, crop_ratio=0.7):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    ch = int(h * crop_ratio)
    cw = int(w * crop_ratio)
    y1 = (h - ch) // 2
    x1 = (w - cw) // 2
    return img[y1:y1+ch, x1:x1+cw]

def darken_image(image_path, factor=0.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    return cv2.convertScaleAbs(img, alpha=factor, beta=0)

def brighten_image(image_path, factor=1.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    return cv2.convertScaleAbs(img, alpha=factor, beta=0)

def resize_down_up(image_path, scale=0.3):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    small = cv2.resize(img, (int(w*scale), int(h*scale)), interpolation=cv2.INTER_AREA)
    back = cv2.resize(small, (w, h), interpolation=cv2.INTER_CUBIC)
    return back

def crop_more_background(image_path, expand_factor=1.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    new_h = int(h * expand_factor)
    new_w = int(w * expand_factor)
    canvas = np.full((new_h, new_w, 3), 128, dtype=np.uint8)
    y1 = (new_h - h) // 2
    x1 = (new_w - w) // 2
    canvas[y1:y1+h, x1:x1+w] = img
    return canvas

def save_temp_image(img, suffix="_tmp"):
    tf = tempfile.NamedTemporaryFile(suffix=suffix + ".jpg", delete=False)
    cv2.imwrite(tf.name, img)
    return tf.name

def predict_with_probs(image_path):
    tensor = _preprocess_image(str(image_path))
    predictions = model.predict(tensor, verbose=0)
    probs = predictions[0].tolist()
    class_index = int(np.argmax(predictions[0]))
    confidence = float(predictions[0][class_index])
    categoria = CLASS_NAMES[class_index]
    return {
        "categoria": categoria,
        "confianza": confidence,
        "probs": dict(zip(CLASS_NAMES, probs)),
        "class_index": class_index
    }

def crop_lichen(image_path, crop_ratio=0.7):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    ch = int(h * crop_ratio)
    cw = int(w * crop_ratio)
    y1 = (h - ch) // 2
    x1 = (w - cw) // 2
    return img[y1:y1+ch, x1:x1+cw]

def darken_image(image_path, factor=0.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    return cv2.convertScaleAbs(img, alpha=factor, beta=0)

def brighten_image(image_path, factor=1.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    return cv2.convertScaleAbs(img, alpha=factor, beta=0)

def resize_down_up(image_path, scale=0.3):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    small = cv2.resize(img, (int(w*scale), int(h*scale)), interpolation=cv2.INTER_AREA)
    back = cv2.resize(small, (w, h), interpolation=cv2.INTER_CUBIC)
    return back

def crop_more_background(image_path, expand_factor=1.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    new_h = int(h * expand_factor)
    new_w = int(w * expand_factor)
    canvas = np.full((new_h, new_w, 3), 128, dtype=np.uint8)
    y1 = (new_h - h) // 2
    x1 = (new_w - w) // 2
    canvas[y1:y1+h, x1:x1+w] = img
    return canvas

def save_temp_image(img, suffix="_tmp"):
    tf = tempfile.NamedTemporaryFile(suffix=suffix + ".jpg", delete=False)
    cv2.imwrite(tf.name, img)
    return tf.name

def predict_with_probs(image_path):
    tensor = _preprocess_image(str(image_path))
    predictions = model.predict(tensor, verbose=0)
    probs = predictions[0].tolist()
    class_index = int(np.argmax(predictions[0]))
    confidence = float(predictions[0][class_index])
    categoria = CLASS_NAMES[class_index]
    return {
        "categoria": categoria,
        "confianza": confidence,
        "probs": dict(zip(CLASS_NAMES, probs)),
        "class_index": class_index
    }

def crop_lichen(image_path, crop_ratio=0.7):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    ch = int(h * crop_ratio)
    cw = int(w * crop_ratio)
    y1 = (h - ch) // 2
    x1 = (w - cw) // 2
    return img[y1:y1+ch, x1:x1+cw]

def darken_image(image_path, factor=0.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    return cv2.convertScaleAbs(img, alpha=factor, beta=0)

def brighten_image(image_path, factor=1.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    return cv2.convertScaleAbs(img, alpha=factor, beta=0)

def resize_down_up(image_path, scale=0.3):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    small = cv2.resize(img, (int(w*scale), int(h*scale)), interpolation=cv2.INTER_AREA)
    back = cv2.resize(small, (w, h), interpolation=cv2.INTER_CUBIC)
    return back

def crop_more_background(image_path, expand_factor=1.5):
    img = cv2.imread(str(image_path))
    if img is None: return None
    h, w = img.shape[:2]
    new_h = int(h * expand_factor)
    new_w = int(w * expand_factor)
    canvas = np.full((new_h, new_w, 3), 128, dtype=np.uint8)
    y1 = (new_h - h) // 2
    x1 = (new_w - w) // 2
    canvas[y1:y1+h, x1:x1+w] = img
    return canvas

def save_temp_image(img, suffix="_tmp"):
    tf = tempfile.NamedTemporaryFile(suffix=suffix + ".jpg", delete=False)
    cv2.imwrite(tf.name, img)
    return tf.name

# Select samples
test_saludable = [r for r in rows if r["split"] == "test" and r["class_name"] == "saludable"][:3]
test_contaminado = [r for r in rows if r["split"] == "test" and r["class_name"] == "contaminado"][:3]
test_desconocido = [r for r in rows if r["split"] == "test" and r["class_name"] == "desconocido"][:3]

print(f"Test samples: saludable={len(test_saludable)}, contaminado={len(test_contaminado)}, desconocido={len(test_desconocido)}")

all_samples = []
for r in test_saludable:
    all_samples.append(("saludable", r["filename"], Path(r["filepath"])))
for r in test_contaminado:
    all_samples.append(("contaminado", r["filename"], Path(r["filepath"])))
for r in test_desconocido:
    all_samples.append(("desconocido", r["filename"], Path(r["filepath"])))

print(f"Total samples to test: {len(all_samples)}")

results = []

for true_class, filename, filepath in all_samples:
    print(f"\n--- Testing {filename} (true: {true_class}) ---")
    
    # ORIGINAL
    orig_result = predict_with_probs(filepath)
    print(f"  Original: {orig_result['categoria']} ({orig_result['confianza']:.3f}) - probs: {orig_result['probs']}")
    
    # CROP 70%
    cropped = crop_lichen(filepath, 0.7)
    if cropped is not None:
        tmp_path = save_temp_image(cropped, "_crop")
        crop_result = predict_with_probs(tmp_path)
        print(f"  Crop 70%: {crop_result['categoria']} ({crop_result['confianza']:.3f})")
        os.unlink(tmp_path)
    
    # DARK
    dark = darken_image(filepath, 0.5)
    if dark is not None:
        tmp_path = save_temp_image(dark, "_dark")
        dark_result = predict_with_probs(tmp_path)
        print(f"  Dark 0.5x: {dark_result['categoria']} ({dark_result['confianza']:.3f})")
        os.unlink(tmp_path)
    
    # BRIGHT
    bright = brighten_image(filepath, 1.5)
    if bright is not None:
        tmp_path = save_temp_image(bright, "_bright")
        bright_result = predict_with_probs(tmp_path)
        print(f"  Bright 1.5x: {bright_result['categoria']} ({bright_result['confianza']:.3f})")
        os.unlink(tmp_path)
    
    # LOWRES
    lowres = resize_down_up(filepath, 0.3)
    if lowres is not None:
        tmp_path = save_temp_image(lowres, "_lowres")
        lr_result = predict_with_probs(tmp_path)
        print(f"  LowRes 0.3x: {lr_result['categoria']} ({lr_result['confianza']:.3f})")
        os.unlink(tmp_path)

print("\n=== DONE ===")