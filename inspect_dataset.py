import os
import cv2
import numpy as np
from pathlib import Path

# Directories
saludable_dir = Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_saludables")
contaminado_dir = Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_contaminados")

# Get sample images from each class
saludable_files = list(saludable_dir.glob("*.jpg")) + list(saludable_dir.glob("*.jpeg"))
contaminado_files = list(contaminado_dir.glob("*.jpg")) + list(contaminado_dir.glob("*.jpeg"))

print(f"Saludables: {len(saludable_files)} archivos")
print(f"Contaminados: {len(contaminado_files)} archivos")

# Inspect 10 samples from each class
for name, files in [("SALUDABLES", saludable_files[:10]), ("CONTAMINADOS", contaminado_files[:10])]:
    print(f"\n=== {name} (primeras 10) ===")
    for f in files:
        try:
            img = cv2.imread(str(f))
            if img is not None:
                h, w, c = img.shape
                # Calculate mean color
                mean_color = np.mean(img, axis=(0,1))
                # Calculate aspect ratio
                ar = w/h
                print(f"  {f.name}: {w}x{h} (AR={ar:.2f}), mean RGB={mean_color[::-1].astype(int)}")
            else:
                print(f"  {f.name}: ERROR - no se pudo leer")
        except Exception as e:
            print(f"  {f.name}: ERROR - {e}")

# Also check augmented images
aug_files = list(Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_contaminados").glob("lcp_aug_*"))
print(f"\n=== IMAGENES AUGMENTADAS (lcp_aug_*) ===")
print(f"Total: {len(aug_files)}")
for f in aug_files[:10]:
    try:
        img = cv2.imread(str(f))
        if img is not None:
            h, w, c = img.shape
            mean_color = np.mean(img, axis=(0,1))
            ar = w/h
            print(f"  {f.name}: {w}x{h} (AR={ar:.2f}), mean RGB={mean_color[::-1].astype(int)}")
    except Exception as e:
        print(f"  {f.name}: ERROR - {e}")

# Check for data leakage - check if any image appears in multiple splits
import csv
manifest_path = r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\entrenamiento\dataset_v7_manifest.csv"
with open(manifest_path, encoding="utf-8") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

# Check for duplicate filenames across splits
filenames = {}
for r in rows:
    fname = r["filename"]
    split = r["split"]
    if fname in filenames:
        if split != filenames[fname]:
            print(f"LEAKAGE: {fname} aparece en {filenames[fname]} y {split}")
    else:
        filenames[fname] = split

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