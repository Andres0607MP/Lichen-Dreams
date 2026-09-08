"""Pruebas del modelo de IA - Sprint 5 (Lichen Dreams).

Ejecuta el clasificador real (modelo activo en BD) sobre:
1. Imagen de liquen saludable.
2. Imagen de liquen contaminado.
3. Imagen de liquen desconocido (carpetas: agua, animales, arena, etc).
4. Imagen que NO corresponde a un liquen (generada sinteticamente).
5. Manejo de errores: archivo inexistente y archivo corrupto.

Genera evidencia JSON en docs/sprint5/evidencias/ia/.
"""
import json
import os
import sys
import time
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[3] / "backend"
sys.path.insert(0, str(BACKEND))

ROOT_EVID = Path(__file__).resolve().parents[1] / "evidencias" / "ia"
ROOT_EVID.mkdir(parents=True, exist_ok=True)

SALUDABLE = BACKEND / "ia" / "datasets" / "liquenes_saludables"
CONTAMINADO = BACKEND / "ia" / "datasets" / "liquenes_contaminados"
DESCONOCIDO = BACKEND / "ia" / "datasets" / "liquenes_desconocidos"


def collect(folder, limit):
    items = sorted(
        p
        for p in folder.rglob("*")
        if p.is_file() and p.suffix.lower() in (".jpg", ".jpeg", ".png")
    )
    step = max(1, len(items) // limit) if items else 1
    out = []
    for i in range(0, min(len(items), len(items)), step):
        out.append(items[i])
        if len(out) >= limit:
            break
    return out


def main():
    report = {
        "prueba": "Pruebas del modelo de IA - Sprint 5",
        "fecha": time.strftime("%Y-%m-%d %H:%M:%S"),
        "modelo_cargando_reales": {},
    }

    from ia.modelos.lichen_classifier import (
        predict,
        CLASS_NAMES,
        INPUT_SIZE,
        _resolve_model_path,
    )

    report["activo_resuelto"] = {
        "path": str(_resolve_model_path()),
        "archivo_existe": _resolve_model_path().exists(),
        "input_size": list(INPUT_SIZE),
        "clases_modelo": CLASS_NAMES,
    }

    groups = {
        "saludable": collect(SALUDABLE, 3),
        "contaminado": collect(CONTAMINADO, 3),
        "desconocido": collect(DESCONOCIDO, 3),
    }

    results = []
    for name, images in groups.items():
        for img in images:
            t0 = time.time()
            try:
                pred = predict(str(img))
                results.append({
                    "caso": name,
                    "imagen": str(img.relative_to(BACKEND)),
                    "tiempo_s": round(time.time() - t0, 3),
                    "prediccion": pred,
                    "resultado": "OK",
                })
            except Exception as e:
                results.append({"caso": name, "imagen": str(img), "resultado": "ERROR", "error": repr(e)})

    no_liquen_path = ROOT_EVID / "imagen_no_liquen.png"
    if not no_liquen_path.exists():
        from PIL import Image
        import random
        img = Image.new("RGB", (400, 400), (90, 160, 210))
        rng = random.Random(42)
        px = img.load()
        for _ in range(600):
            x, y = rng.randint(0, 399), rng.randint(0, 399)
            px[x, y] = (rng.randint(0, 255), rng.randint(0, 255), rng.randint(0, 255))
        img.save(no_liquen_path)

    t0 = time.time()
    try:
        pred = predict(str(no_liquen_path))
        results.append({
            "caso": "no_liquen",
            "imagen": str(no_liquen_path),
            "tiempo_s": round(time.time() - t0, 3),
            "prediccion": pred,
            "resultado": "OK",
        })
    except Exception as e:
        results.append({"caso": "no_liquen", "imagen": str(no_liquen_path), "resultado": "ERROR", "error": repr(e)})

    missing = BACKEND / "ia" / "datasets" / "no_existe_esta_imagen.jpg"
    try:
        predict(str(missing))
        results.append({"caso": "archivo_inexistente", "resultado": "SIN_ERROR", "detalle": "No lanzó excepción"})
    except Exception as e:
        results.append({"caso": "archivo_inexistente", "resultado": "ERROR_ESPERADO", "error": f"{type(e).__name__}: {e}"})

    corrupt = ROOT_EVID / "imagen_corrupta.txt"
    corrupt.write_text("no soy una imagen", encoding="utf-8")
    try:
        predict(str(corrupt))
        results.append({"caso": "archivo_corrupto", "resultado": "SIN_ERROR", "detalle": "No lanzó excepción"})
    except Exception as e:
        results.append({"caso": "archivo_corrupto", "resultado": "ERROR_ESPERADO", "error": f"{type(e).__name__}: {e}"})

    report["casos"] = results

    out = ROOT_EVID / "resultados_ia.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()