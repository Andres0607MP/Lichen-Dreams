"""
Pruebas controladas de dependencia visual del modelo V8.
Ejecuta inferencias sobre imágenes del test V7 con varias modificaciones controladas.
"""
import cv2
import numpy as np
from pathlib import Path
import csv
import json
import tempfile
import os
import sys

# Add backend to path
sys.path.insert(0, r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend")

from ia.modelos.lichen_classifier import predict

# Paths
contaminado_dir = Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_contaminados")
saludable_dir = Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_saludables")
desconocido_dir = Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_desconocidos")

manifest_path = r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\entrenamiento\dataset_v7_manifest.csv"

# Load manifest and get test images
with open(manifest_path, encoding="utf-8") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

test_rows = [r for r in rows if r["split"] == "test"]

# Get test images by class
test_saludable = [r for r in test_rows if r["class_name"] == "saludable"]
test_contaminado = [r for r in test_rows if r["class_name"] == "contaminado"]
test_desconocido = [r for r in test_rows if r["class_name"] == "desconocido"]

print(f"Test saludable: {len(test_saludable)}")
print(f"Test contaminado: {len(test_contaminado)}")
print(f"Test desconocido: {len(test_desconocido)}")

# Select 5 from each class
def select_samples(rows, n=5):
    return rows[:n]

saludable_samples = select_samples(test_saludable, 5)
contaminado_samples = select_samples(test_contaminado, 5)
desconocido_samples = select_samples(test_desconocido, 5)

# Helper to run prediction on image path
def run_predict(image_path):
    try:
        result = predict(str(image_path))
        return {
            "categoria": result["categoria"],
            "confianza": result["confianza"],
            "nivel_contaminacion": result["nivel_contaminacion"],
            "calidad_aire": result["calidad_aire"],
            "raw_probs": None  # We don't have raw probs from predict()
        }
    except Exception as e:
        return {"error": str(e)}

# Since predict() only returns argmax, we need to access the model directly for probabilities
# Let's create a modified predict that returns probabilities
import tensorflow as tf
from ia.modelos.lichen_classifier import _load_model, _preprocess_image, CLASS_NAMES, _model, _model_path
from ia.resolver_modelo_activo import resolver_modelo_activo

def predict_with_probs(image_path):
    """Run inference and return full probability distribution."""
    model = _load_model()
    tensor = _preprocess_image(image_path)
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
    """Crop image to focus on center (simulate cropping to lichen)."""
    img = cv2.imread(str(image_path))
    if img is None:
        return None
    h, w = img.shape[:2]
    # Crop to center region
    ch = int(h * crop_ratio)
    cw = int(w * crop_ratio)
    y1 = (h - ch) // 2
    x1 = (w - cw) // 2
    cropped = img[y1:y1+ch, x1:x1+cw]
    return cropped

def darken_image(image_path, factor=0.5):
    """Darken image by factor."""
    img = cv2.imread(str(image_path))
    if img is None:
        return None
    darkened = cv2.convertScaleAbs(img, alpha=factor, beta=0)
    return darkened

def brighten_image(image_path, factor=1.5):
    """Brighten image by factor."""
    img = cv2.imread(str(image_path))
    if img is None:
        return None
    brightened = cv2.convertScaleAbs(img, alpha=factor, beta=0)
    return brightened

def resize_down_up(image_path, scale=0.3):
    """Reduce resolution then back to original size."""
    img = cv2.imread(str(image_path))
    if img is None:
        return None
    h, w = img.shape[:2]
    # Downscale
    small = cv2.resize(img, (int(w*scale), int(h*scale)), interpolation=cv2.INTER_AREA)
    # Upscale back
    back = cv2.resize(small, (w, h), interpolation=cv2.INTER_CUBIC)
    return back

def crop_more_background(image_path, expand_factor=1.5):
    """Expand crop to include more background (simulate by padding)."""
    img = cv2.imread(str(image_path))
    if img is None:
        return None
    h, w = img.shape[:2]
    # Create larger canvas with gray background
    new_h = int(h * expand_factor)
    new_w = int(w * expand_factor)
    canvas = np.full((new_h, new_w, 3), 128, dtype=np.uint8)  # gray background
    y1 = (new_h - h) // 2
    x1 = (new_w - w) // 2
    canvas[y1:y1+h, x1:x1+w] = img
    return canvas

def save_temp_image(img, suffix="_tmp"):
    """Save image to temp file and return path."""
    tf = tempfile.NamedTemporaryFile(suffix=suffix + ".jpg", delete=False)
    cv2.imwrite(tf.name, img)
    return tf.name

# Run tests
def run_all_tests():
    results = []
    
    # Collect test samples
    all_samples = []
    for r in saludable_samples:
        all_samples.append(("saludable", r["filename"], Path(r["filepath"])))
    for r in contaminado_samples:
        all_samples.append(("contaminado", r["filename"], Path(r["filepath"])))
    for r in desconocido_samples:
        all_samples.append(("desconocido", r["filename"], Path(r["filepath"])))
    
    for true_class, filename, filepath in all_samples:
        print(f"\n--- Testing {filename} (true: {true_class}) ---")
        
        # 1. ORIGINAL
        orig_result = predict_with_probs(filepath)
        print(f"  Original: {orig_result['categoria']} ({orig_result['confianza']:.3f}) - probs: {orig_result['probs']}")
        
        results.append({
            "imagen": filename,
            "clase_real": true_class,
            "variante": "original",
            "prediccion": orig_result["categoria"],
            "confianza": orig_result["confianza"],
            "probs": orig_result["probs"]
        })
        
        # Load image once for manipulations
        img = cv2.imread(str(filepath))
        if img is None:
            continue
            
        # 2. CROP LÍQUEN (center crop 70%)
        cropped = crop_lichen(filepath, 0.7)
        if cropped is not None:
            tmp_path = save_temp_image(cropped, "_crop")
            crop_result = predict_with_probs(tmp_path)
            print(f"  Crop 70%: {crop_result['categoria']} ({crop_result['confianza']:.3f}) - probs: {crop_result['probs']}")
            results.append({
                "imagen": filename,
                "clase_real": true_class,
                "variante": "crop_70",
                "prediccion": crop_result["categoria"],
                "confianza": crop_result["confianza"],
                "probs": crop_result["probs"]
            })
            os.unlink(tmp_path)
        
        # 3. FONDO SIN LÍQUEN (pad with gray to double size, lichen becomes small centered)
        bg_img = crop_more_background(filepath, 2.0)
        if bg_img is not None:
            tmp_path = save_temp_image(bg_img, "_bg")
            bg_result = predict_with_probs(tmp_path)
            print(f"  Fondo 2x: {bg_result['categoria']} ({bg_result['confianza']:.3f}) - probs: {bg_result['probs']}")
            results.append({
                "imagen": filename,
                "clase_real": true_class,
                "variante": "fondo_2x",
                "prediccion": bg_result["categoria"],
                "confianza": bg_result["confianza"],
                "probs": bg_result["probs"]
            })
            os.unlink(tmp_path)
        
        # 4. BRILLO - OSCURO (0.5x)
        dark = darken_image(filepath, 0.5)
        if dark is not None:
            tmp_path = save_temp_image(dark, "_dark")
            dark_result = predict_with_probs(tmp_path)
            print(f"  Oscuro 0.5x: {dark_result['categoria']} ({dark_result['confianza']:.3f}) - probs: {dark_result['probs']}")
            results.append({
                "imagen": filename,
                "clase_real": true_class,
                "variante": "oscuro_0.5x",
                "prediccion": dark_result["categoria"],
                "confianza": dark_result["confianza"],
                "probs": dark_result["probs"]
            })
            os.unlink(tmp_path)
        
        # 5. BRILLO - CLARO (1.5x)
        bright = brighten_image(filepath, 1.5)
        if bright is not None:
            tmp_path = save_temp_image(bright, "_bright")
            bright_result = predict_with_probs(tmp_path)
            print(f"  Claro 1.5x: {bright_result['categoria']} ({bright_result['confianza']:.3f}) - probs: {bright_result['probs']}")
            results.append({
                "imagen": filename,
                "clase_real": true_class,
                "variante": "claro_1.5x",
                "prediccion": bright_result["categoria"],
                "confianza": bright_result["confianza"],
                "probs": bright_result["probs"]
            })
            os.unlink(tmp_path)
        
        # 6. RESOLUCIÓN BAJA (0.25x down then up)
        lowres = resize_down_up(filepath, 0.25)
        if lowres is not None:
            tmp_path = save_temp_image(lowres, "_lowres")
            lr_result = predict_with_probs(tmp_path)
            print(f"  LowRes 0.25x: {lr_result['categoria']} ({lr_result['confianza']:.3f}) - probs: {lr_result['probs']}")
            results.append({
                "imagen": filename,
                "clase_real": true_class,
                "variante": "lowres_0.25x",
                "prediccion": lr_result["categoria"],
                "confianza": lr_result["confianza"],
                "probs": lr_result["probs"]
            })
            os.unlink(tmp_path)
        
        # 6b. RESOLUCIÓN MEDIA (0.5x down then up)
        midres = resize_down_up(filepath, 0.5)
        if midres is not None:
            tmp_path = save_temp_image(midres, "_midres")
            mr_result = predict_with_probs(tmp_path)
            print(f"  MidRes 0.5x: {mr_result['categoria']} ({mr_result['confianza']:.3f}) - probs: {mr_result['probs']}")
            results.append({
                "imagen": filename,
                "clase_real": true_class,
                "variante": "midres_0.5x",
                "prediccion": mr_result["categoria"],
                "confianza": mr_result["confianza"],
                "probs": mr_result["probs"]
            })
            os.unlink(tmp_path)
        
        # 7. ENCUADRE - Crop más fondo (1.5x padding)
        more_bg = crop_more_background(filepath, 1.5)
        if more_bg is not None:
            tmp_path = save_temp_image(more_bg, "_morebg")
            mbg_result = predict_with_probs(tmp_path)
            print(f"  Más fondo 1.5x: {mbg_result['categoria']} ({mbg_result['confianza']:.3f}) - probs: {mbg_result['probs']}")
            results.append({
                "imagen": filename,
                "clase_real": true_class,
                "variante": "mas_fondo_1.5x",
                "prediccion": mbg_result["categoria"],
                "confianza": mbg_result["confianza"],
                "probs": mbg_result["probs"]
            })
            os.unlink(tmp_path)
        
        # 7b. ENCUADRE - Crop centrado en líquen (0.5x)
        tight = crop_lichen(filepath, 0.5)
        if tight is not None:
            tmp_path = save_temp_image(tight, "_tight")
            tight_result = predict_with_probs(tmp_path)
            print(f"  Crop 50%: {tight_result['categoria']} ({tight_result['confianza']:.3f}) - probs: {tight_result['probs']}")
            results.append({
                "imagen": filename,
                "clase_real": true_class,
                "variante": "crop_50",
                "prediccion": tight_result["categoria"],
                "confianza": tight_result["confianza"],
                "probs": tight_result["probs"]
            })
            os.unlink(tmp_path)

    return results

if __name__ == "__main__":
    import cv2
    import tempfile
    
    print("=== INICIANDO PRUEBAS DE DEPENDENCIA VISUAL V8 ===")
    print(f"Modelo activo: {_model_path or 'resolviendo...'}")
    
    results = run_all_tests()
    
    # Save results
    with open("visual_dependency_results.json", "w") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    
    print(f"\n=== RESULTADOS GUARDADOS EN visual_dependency_results.json ===")
    print(f"Total pruebas: {len(results)}")
    
    # Summary
    changes = 0
    for r in results:
        if r["variante"] != "original":
            orig = next((o for o in results if o["imagen"] == r["imagen"] and o["variante"] == "original"), None)
            if orig and orig["prediccion"] != r["prediccion"]:
                changes += 1
                print(f"  CAMBIO DE CLASE: {r['imagen']} {orig['prediccion']} -> {r['prediccion']} ({r['variante']})")
    
    print(f"\nTotal cambios de clase: {changes}")