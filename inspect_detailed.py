import cv2
import numpy as np
from pathlib import Path
import csv

saludable_dir = Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_saludables")
contaminado_dir = Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_contaminados")

saludable_files = list(saludable_dir.glob("*.jpg")) + list(saludable_dir.glob("*.jpeg"))
contaminado_files = list(contaminado_dir.glob("*.jpg")) + list(contaminado_dir.glob("*.jpeg"))

print(f"Saludables: {len(saludable_files)} archivos")
print(f"Contaminados: {len(contaminado_files)} archivos")

def analyze_class(files, name):
    widths = []
    heights = []
    aspect_ratios = []
    mean_r = []
    mean_g = []
    mean_b = []
    areas = []
    
    for f in files:
        try:
            img = cv2.imread(str(f))
            if img is not None:
                h, w, c = img.shape
                widths.append(w)
                heights.append(h)
                aspect_ratios.append(w/h)
                mean_color = np.mean(img, axis=(0,1))
                mean_b.append(mean_color[0])
                mean_g.append(mean_color[1])
                mean_r.append(mean_color[2])
                areas.append(w*h)
        except:
            pass
    
    if widths:
        print(f"\n=== {name} STATS ({len(widths)} imagenes) ===")
        print(f"  Width: min={min(widths)}, max={max(widths)}, mean={np.mean(widths):.0f}, std={np.std(widths):.0f}")
        print(f"  Height: min={min(heights)}, max={max(heights)}, mean={np.mean(heights):.0f}, std={np.std(heights):.0f}")
        print(f"  Aspect Ratio: min={min(aspect_ratios):.2f}, max={max(aspect_ratios):.2f}, mean={np.mean(aspect_ratios):.2f}, std={np.std(aspect_ratios):.2f}")
        print(f"  Mean R: {np.mean(mean_r):.1f}, G: {np.mean(mean_g):.1f}, B: {np.mean(mean_b):.1f}")
        print(f"  Area: min={min(areas)}, max={max(areas)}, mean={np.mean(areas):.0f}")

analyze_class(saludable_files, "SALUDABLES")
analyze_class(contaminado_files, "CONTAMINADOS")

# Augmented check
aug_files = list(Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_contaminados").glob("lcp_aug_*"))
orig_files = [f for f in contaminado_files if not f.name.startswith("lcp_aug_")]
print(f"\nContaminados originales: {len(orig_files)}")
print(f"Contaminados augmentados: {len([f for f in contaminado_files if f.name.startswith('lcp_aug_')])}")

# Leakage check
import csv
manifest_path = r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\entrenamiento\dataset_v7_manifest.csv"
with open(manifest_path, encoding="utf-8") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

source_by_split = {}
for r in rows:
    src = r["source_original"]
    split = r["split"]
    if src not in source_by_split:
        source_by_split[src] = set()
    source_by_split[src].add(split)

leakage = {src: splits for src, splits in source_by_split.items() if len(splits) > 1}
print(f"\n=== LEAKAGE CHECK ===")
if leakage:
    for src, splits in list(leakage.items())[:10]:
        print(f"  LEAKAGE: {src} en {splits}")
else:
    print("No leakage found by source_original")

# Check lcp_aug only in train
for r in rows:
    if r["is_augmented"] == "true" and r["split"] != "train":
        print(f"AUG EN SPLIT INCORRECTO: {r['filename']} en {r['split']}")

# Check test has no augmented
test_aug = [r["filename"] for r in rows if r["split"] == "test" and r["is_augmented"] == "true"]
if test_aug:
    print(f"AUGMENTADAS EN TEST: {test_aug[:5]}")
else:
    print("No hay aumentadas en test - OK")

print("\n=== VERIFICACIÓN DE LEAKAGE COMPLETADA ===")