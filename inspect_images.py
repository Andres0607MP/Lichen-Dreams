import cv2
import numpy as np
from pathlib import Path

saludable_dir = Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_saludables")
contaminado_dir = Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_contaminados")

saludable_files = list(saludable_dir.glob("*.jpg")) + list(saludable_dir.glob("*.jpeg"))
contaminado_files = list(contaminado_dir.glob("*.jpg")) + list(contaminado_dir.glob("*.jpeg"))

contaminado_orig = [f for f in contaminado_files if not f.name.startswith("lcp_aug_")]
contaminado_aug = [f for f in contaminado_files if f.name.startswith("lcp_aug_")]
lcp_orig = [f for f in contaminado_files if f.name.startswith("lcp_") and not f.name.startswith("lcp_aug_")]

print(f"Total saludables: {len(saludable_files)}")
print(f"Total contaminados: {len(contaminado_files)}")
print(f"  Originales: {len(contaminado_orig)}")
print(f"  Augmented: {len(contaminado_aug)}")
print(f"  lcp_* originales: {len([f for f in contaminado_files if f.name.startswith('lcp_') and not f.name.startswith('lcp_aug_')])}")

def check(f):
    img = cv2.imread(str(f))
    if img is None: 
        return None
    h, w = img.shape[:2]
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    mean_rgb = np.mean(img, axis=(0,1))
    mean_hsv = np.mean(hsv, axis=(0,1))
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 50, 150)
    edge_density = np.sum(edges > 0) / (gray.shape[0] * gray.shape[1])
    return {
        'name': f.name,
        'size': f"{img.shape[1]}x{img.shape[0]}",
        'rgb': tuple(map(int, mean_rgb[::-1])),
        'hsv': tuple(map(int, mean_hsv)),
        'edges': edge_density,
        'aspect': w/h
    }

print("\n=== SALUDABLES (sample 10) ===")
for f in list(Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_saludables").glob("*.jpg"))[:10]:
    info = check(f)
    if info:
        print(f"  {info['name']}: {info['size']}, RGB={info['rgb']}, HSV={info['hsv']}, edges={info['edges']:.4f}, AR={info['aspect']:.2f}")

print("\n=== CONTAMINADOS ORIGINALES (no aug) - sample 10 ===")
contaminado_orig = [f for f in list(Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_contaminados").glob("*.jpg")) + list(Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_contaminados").glob("*.jpeg")) if not f.name.startswith("lcp_aug_")]
for f in contaminado_dir.glob("*.jpg"):
    if not f.name.startswith("lcp_aug_") and not f.name.startswith("lcp_aug_"):
        info = check(f)
        if info:
            print(f"  {info['name']}: {info['size']}, RGB={info['rgb']}, HSV={info['hsv']}, edges={info['edges']:.4f}, AR={info['aspect']:.2f}")
            # only print first 10
            break

# Let's do this more carefully
print("\n=== CONTAMINADOS ORIGINALES (no aug) - sample 10 ===")
count = 0
for f in contaminado_dir.glob("*.jpg"):
    if not f.name.startswith("lcp_aug_"):
        info = check(f)
        if info:
            print(f"  {info['name']}: {info['size']}, RGB={info['rgb']}, HSV={info['hsv']}, edges={info['edges']:.4f}, AR={info['aspect']:.2f}")
            count += 1
            if count >= 10:
                break

print("\n=== AUGMENTADAS (lcp_aug_*) - sample 10 ===")
count = 0
for f in contaminado_dir.glob("lcp_aug_*.jpg"):
    info = check(f)
    if info:
        print(f"  {info['name']}: {info['size']}, RGB={info['rgb']}, HSV={info['hsv']}, edges={info['edges']:.4f}, AR={info['aspect']:.2f}")
        count += 1
        if count >= 10:
            break

print("\n=== LCP ORIGINALES (no aug) - sample 10 ===")
count = 0
for f in contaminado_dir.glob("lcp_*.jpg"):
    if not f.name.startswith("lcp_aug_"):
        info = check(f)
        if info:
            print(f"  {info['name']}: {info['size']}, RGB={info['rgb']}, HSV={info['hsv']}, edges={info['edges']:.4f}, AR={info['aspect']:.2f}")
            count += 1
            if count >= 10:
                break

# Also check resolution distributions more precisely
print("\n=== RESOLUTION DISTRIBUTIONS ===")
sizes_saludable = []
sizes_contam_orig = []
sizes_contam_aug = []

for f in list(Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_saludables").glob("*.jpg")):
    img = cv2.imread(str(f))
    if img is not None:
        sizes_saludable.append((img.shape[1], img.shape[0]))

for f in list(Path(r"C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend\ia\datasets\liquenes_contaminados").glob("*.jpg")):
    if not f.name.startswith("lcp_aug_"):
        img = cv2.imread(str(f))
        if img is not None:
            sizes_contam_orig.append((img.shape[1], img.shape[0]))
    else:
        img = cv2.imread(str(f))
        if img is not None:
            sizes_contam_aug.append((img.shape[1], img.shape[0]))

def stats(sizes, name):
    if sizes:
        ws = [s[0] for s in sizes]
        hs = [s[1] for s in sizes]
        ars = [w/h for w,h in sizes]
        print(f"\n{name}: n={len(sizes)}")
        print(f"  Width: min={min(ws)}, max={max(ws)}, mean={np.mean(ws):.0f}")
        print(f"  Height: min={min(hs)}, max={max(hs)}, mean={np.mean(hs):.0f}")
        print(f"  Aspect Ratio: min={min(ars):.2f}, max={max(ars):.2f}, mean={np.mean(ars):.2f}")

stats(sizes_saludable, "SALUDABLES")
stats(sizes_contam_orig, "CONTAMINADOS ORIGINALES")
stats(sizes_contam_aug, "CONTAMINADOS AUGMENTADOS")