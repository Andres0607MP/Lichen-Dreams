import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ia.modelos.lichen_classifier import predict, MODEL_PATH

DATASET = Path(__file__).resolve().parent / "datasets"

def first_files(folder, n):
    fs = [p for p in folder.iterdir()
          if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".bmp", ".webp"}]
    return sorted(fs)[:n]

print(f"MODELO ACTIVO CARGADO: {MODEL_PATH.name}")
print("=== 3 CLASES (entrenadas) ===")
for label, folder in [("liquen saludable", DATASET / "liquenes_saludables"),
                      ("liquen contaminado", DATASET / "liquenes_contaminados")]:
    for p in first_files(folder, 3):
        r = predict(str(p))
        print(f"{p.name} | esperado={label} | predicho={r['categoria']} | conf={r['confianza']:.3f}")

print("\n=== DESCONOCIDOS (ahora clase entrenada, 5 subcarpetas) ===")
for sub in ["agua", "pasto_hierba", "animales", "objetos", "vehiculos"]:
    folder = DATASET / "liquenes_desconocidos" / sub
    if not folder.is_dir():
        continue
    for p in first_files(folder, 2):
        r = predict(str(p))
        print(f"{sub}/{p.name} | esperado=desconocido | predicho={r['categoria']} | conf={r['confianza']:.3f}")