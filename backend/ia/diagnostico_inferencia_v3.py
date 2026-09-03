"""Herramienta de diagnostico de inferencia V3 (solo lectura).

Muestra el modelo resuelto, preprocessing, probabilidades crudas y si hay
rejection/threshold. NO modifica imagenes ni el modelo.

Uso:
    python ia/diagnostico_inferencia_v3.py <ruta/imagen.jpg>
"""
import argparse
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


def main():
    ap = argparse.ArgumentParser(description="Diagnostico de inferencia V3")
    ap.add_argument("imagen", help="ruta a una imagen (jpg/png)")
    args = ap.parse_args()

    img_path = Path(args.imagen)
    if not img_path.is_file():
        print(f"ERROR: imagen no existe: {img_path}")
        sys.exit(1)

    # --- 1. modelo resuelto (estricto) ---
    print("=== MODELO ===")
    try:
        from ia.resolver_modelo_activo import resolver_modelo_activo, ActiveModelError
        path = resolver_modelo_activo()
        print(f"  resolver_modelo_activo -> {path}")
        if path.name != "lichen_model_v3.keras":
            print(f"  [ALERTA] el activo resuelto NO es v3: {path.name}")
    except ActiveModelError as e:
        print(f"  [ERROR] resolución estricta falló: {e}")
        print("  (si el classifier cayó a otro .keras, ese es el bug de fallback)")
        path = None

    # --- 2. preprocessing ---
    print("\n=== PREPROCESSING ===")
    from ia.modelos.lichen_classifier import _preprocess_image
    tensor = _preprocess_image(str(img_path))
    import numpy as np
    print(f"  tamaño original       : {img_path.stat().st_size} bytes")
    print(f"  shape final           : {tensor.shape}")
    print(f"  dtype                 : {tensor.dtype}")
    print(f"  min / max             : {float(tensor.min()):.4f} / {float(tensor.max()):.4f}")
    print(f"  rango esperado V3     : [0,1] (entrenado con /255, sin Rescaling en el modelo)")

    # --- 3. probabilidades crudas ---
    print("\n=== PROBABILIDADES CRUDAS ===")
    try:
        import tensorflow as tf
        from ia.modelos.lichen_classifier import _load_model, MODEL_PATH, CLASS_NAMES

        print(f"  modelo cargado (MODEL_PATH): {MODEL_PATH}")
        model = _load_model()
        probs = model.predict(tensor, verbose=0)[0]
        for i, name in enumerate(CLASS_NAMES):
            print(f"  {i} {name:24s}: {float(probs[i]):.4f}")
        arg = int(np.argmax(probs))
        print(f"  argmax  -> {CLASS_NAMES[arg]} (indice {arg})")
        print(f"  confianza argmax: {float(probs[arg]):.4f}")
        print(f"  suma probs: {float(probs.sum()):.4f}")

        # umbral efectivo: margen entre top-1 y top-2
        sorted_p = sorted(probs, reverse=True)
        print(f"  margen top1-top2: {float(sorted_p[0]-sorted_p[1]):.4f}")
    except FileNotFoundError as e:
        print(f"  [ERROR] {e}")
        sys.exit(1)

    # --- 4. rejection / threshold ---
    print("\n=== REJECTION / THRESHOLD ===")
    mf = PROJECT_ROOT / "ia" / "entrenamiento" / "reportes" / "metrics_v3.json"
    tiene_threshold = False
    if mf.exists():
        m = json.loads(mf.read_text(encoding="utf-8"))
        print(f"  metrics_v3.json existe (f1_macro={m.get('f1_macro')})")
        print(f"  campos con 'threshold': {[k for k in m if 'thres' in k.lower()] or 'NINGUNO'}")
    else:
        print("  metrics_v3.json NO existe")
    print("  threshold en classifier: NO existe (argmax directo)")


if __name__ == "__main__":
    main()