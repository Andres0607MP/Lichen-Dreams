import cv2
import numpy as np
from pathlib import Path
import csv

contaminado_dir = Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_contaminados")

# Check the lcp_* files relationship
all_lcp = list(contaminado_dir.glob("lcp_*.jpg"))
lcp_orig = [f for f in all_lcp if not f.name.startswith("lcp_aug_")]
lcp_aug = [f for f in all_lcp if f.name.startswith("lcp_aug_")]

print(f"Total lcp_* (incl augmented): {len(all_lcp)}")
print(f"lcp_* originales (no aug): {len(lcp_orig)}")
print(f"lcp_aug_*: {len(lcp_aug)}")

# Check the manifest
manifest_path = r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\entrenamiento\dataset_v7_manifest.csv"
with open(manifest_path, encoding="utf-8") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

# Check lcp_family
lcp_family = [r for r in rows if r["group_id"] == "lcp_family"]
print(f"\nlcp_family entries: {len(lcp_family)}")

# Check original lcp_* (non-augmented) in manifest
lcp_orig_manifest = [r for r in rows if r["filename"].startswith("lcp_") and r["is_augmented"] == "false"]
print(f"lcp_* non-augmented in manifest: {len(lcp_orig_manifest)}")
for r in lcp_orig_manifest[:20]:
    print(f"  {r['filename']}: split={r['split']}, class={r['class_name']}")

# Check if the 14 lcp_* are all in train
lcp_orig_train = [r for r in rows if r["filename"].startswith("lcp_") and r["is_augmented"] == "false" and r["split"] == "train"]
print(f"lcp_* non-augmented in train: {len(lcp_orig_train)}")

# Check lcp_aug_* in manifest
lcp_aug_manifest = [r for r in rows if r["filename"].startswith("lcp_aug_")]
print(f"\nlcp_aug_* in manifest: {len(lcp_aug_manifest)}")
for r in lcp_aug_manifest[:5]:
    print(f"  {r['filename']}: split={r['split']}, is_aug={r['is_augmented']}")

# Check all lcp_aug are in train
lcp_aug_not_train = [r for r in lcp_aug_manifest if r["split"] != "train"]
if lcp_aug_not_train:
    print(f"lcp_aug NOT in train: {len(lcp_aug_not_train)}")
else:
    print("All lcp_aug_* are in train - OK")

# Check test has no augmented
test_aug = [r["filename"] for r in rows if r["split"] == "test" and r["is_augmented"] == "true"]
if test_aug:
    print(f"AUGMENTADAS EN TEST: {test_aug[:5]}")
else:
    print("No hay aumentadas en test - OK")

# Check val has no augmented
val_aug = [r["filename"] for r in rows if r["split"] == "val" and r["is_augmented"] == "true"]
if val_aug:
    print(f"AUGMENTADAS EN VAL: {val_aug[:5]}")
else:
    print("No hay aumentadas en val - OK")

# Check if any lcp_* original appears in val or test
lcp_orig_val_test = [r for r in rows if r["filename"].startswith("lcp_") and not r["filename"].startswith("lcp_aug_") and r["split"] != "train"]
if lcp_orig_val_test:
    print(f"lcp_* originales en val/test: {len(lcp_orig_val_test)}")
    for r in lcp_orig_val_test[:5]:
        print(f"  {r['filename']}: split={r['split']}")
else:
    print("Todos los lcp_* originales estan en train - OK")