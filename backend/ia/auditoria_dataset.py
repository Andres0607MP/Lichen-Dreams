"""AUDITORIA ANALITICA (solo lectura) del dataset de liquenes y de las causas
del colapso de los modelos V3/V4/V5.

No entrena, no modifica imagenes, no cambia el modelo activo.
Genera estadisticas de clases, split por familia, features visuales y
diversidad dHash.
"""
import sys
from collections import defaultdict
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATASET_DIR = PROJECT_ROOT / "ia" / "datasets"
EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

CLASSES = {0: "liquenes_saludables", 1: "liquenes_contaminados", 2: "liquenes_desconocidos"}


def _dhash(path: Path) -> int:
    try:
        img = Image.open(path).convert("L").resize((9, 8), Image.BILINEAR)
    except Exception:
        return -1
    px = np.asarray(img, dtype=np.int16)
    diff = (px[:, 0:8] < px[:, 1:9]).astype(np.uint8)
    h = 0
    for bit in diff.flatten():
        h = (h << 1) | int(bit)
    return h


def _hamming(a: int, b: int) -> int:
    return bin(a ^ b).count("1")


def list_class(label: int):
    if label == 2:
        top = DATASET_DIR / CLASSES[2]
        return [p for sub in sorted(top.iterdir()) if sub.is_dir()
                for p in sub.iterdir() if p.is_file() and p.suffix.lower() in EXT]
    top = DATASET_DIR / CLASSES[label]
    return [p for p in top.iterdir() if p.is_file() and p.suffix.lower() in EXT]


def stats_feature(paths, sample=None):
    """mean RGB, gray mean/std, saturación, y contraste (std gray) en 96px."""
    if sample:
        rng = np.random.default_rng(0)
        idx = rng.choice(len(paths), size=min(len(paths), sample), replace=False)
        paths = [paths[i] for i in idx]
    out = []
    for p in paths:
        try:
            img = Image.open(p).convert("RGB").resize((96, 96), Image.BILINEAR)
        except Exception:
            continue
        a = np.asarray(img, dtype=np.float32)
        gray = a.mean(axis=2)
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        mx = a.max(axis=2); mn = a.min(axis=2)
        sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-5), 0.0)
        out.append((r.mean(), g.mean(), b.mean(), gray.mean(), gray.std(), sat.mean()))
    arr = np.array(out) if out else np.zeros((0, 6))
    if len(arr) == 0:
        return None
    return arr


def pct(arr, q=(25, 50, 75)):
    return [round(float(np.percentile(arr, x)), 2) for x in q]


def families_for(paths, labels):
    fam = [-1] * len(paths)
    fam_rep = defaultdict(list)
    families = []
    for i, p in enumerate(paths):
        h = _dhash(p)
        matched = None
        for (rep_h, fid) in fam_rep.get(labels[i], []):
            if h >= 0 and _hamming(h, rep_h) <= 1:
                matched = fid
                break
        if matched is None:
            fid = len(families)
            families.append(labels[i])
            fam_rep[labels[i]].append((h, fid))
            fam[i] = fid
        else:
            fam[i] = matched
    return fam, families


def main():
    print("========== AUDITORIA DEL DATASET (2159 imagenes) ==========")

    # 1) Conteos y composicion contaminados
    paths = {lbl: list_class(lbl) for lbl in CLASSES}
    for lbl, name in CLASSES.items():
        files = [f for f in list_class(lbl)]  # includes direct/recursive
        print(f"{name}: {len(files)}")
    cont = paths[1]
    lcp = [p for p in cont if p.name.startswith("lcp_") and "aug" not in p.name]
    aug = [p for p in cont if p.name.startswith("lcp_aug_")]
    lc = [p for p in cont if p.name.startswith("lc_") and "aug" not in p.name]
    print(f"  contaminados: lcp={len(lcp)} lcp_aug={len(aug)} lc={len(lc)} total={len(cont)}")

    # 2) Diversidad dHash por clase
    print("\n--- Diversidad visual (dHash 8x8) ---")
    for lbl, name in CLASSES.items():
        hashes = [h for h in (_dhash(p) for p in paths[lbl]) if h >= 0]
        uniq = len(set(hashes))
        print(f"{name}: unicos={uniq} de {len(hashes)}  (diversidad={uniq/len(hashes):.2f})")

    # 2b) Diversidad interna de las aumentadas vs lc
    aug_hash = [h for h in (_dhash(p) for p in aug) if h >= 0]
    lc_hash = [h for h in (_dhash(p) for p in lc) if h >= 0]
    print(f"  lcp_aug (160): unicos={len(set(aug_hash))} | lc (326): unicos={len(set(lc_hash))}")
    lcp_hash = [(_dhash(p), p) for p in lcp]
    # Distancia minima de cada aug a sus 14 padres lcp
    min_d = []
    for h in aug_hash:
        best = min(_hamming(h, ph) for ph, _ in lcp_hash)
        min_d.append(best)
    if min_d:
        import numpy as _np
        print(f"  lcp_aug -> distancia Hamming minima a los {len(lcp)} lcp: "
              f"media={float(_np.mean(min_d)):.2f}  <=1 (={{int(sum(1 for d in min_d if d <= 1))}})")

    # 3) Features visuales por clase y por subgrupo
    print("\n--- Features visuales (96px; medias [r,g,b, gray, std, sat]) ---")
    for lbl, name in CLASSES.items():
        st = stats_feature(paths[lbl], sample=800)
        if st is not None:
            print(f"{name} (n={len(st)}):")
            print(f"  R  p25/50/75 = {pct(st[:,0])}")
            print(f"  G  p25/50/75 = {pct(st[:,1])}")
            print(f"  B  p25/50/75 = {pct(st[:,2])}")
            print(f"  Gray p25/50/75 = {pct(st[:,3])}")
            print(f"  Contraste(std) p25/50/75 = {pct(st[:,4])}")
            print(f"  Sat p25/50/75 = {pct(st[:,5])}")
    for name, grp in [("lc_(326)", lc), ("lcp_(14)", lcp), ("lcp_aug_(160)", aug)]:
        st = stats_feature(grp)
        if st is not None:
            print(f"{name}: gray p50={np.percentile(st[:,3], 50):.1f} sat p50={np.percentile(st[:,5],50):.2f}")

    # 4) Split por familia (mismo algoritmo V4/V5): distribucion por clase
    print("\n--- Split por familia (dHash, Hamming<=1 ; 70/15/15) ---")
    all_paths = []
    all_labels = []
    for lbl in CLASSES:
        pl = list_class(lbl)
        all_paths += pl
        all_labels += [lbl] * len(pl)
    fam, families = families_for(all_paths, all_labels)
    rng = np.random.default_rng(42)
    fam_ids = sorted(set(fam))
    rng.shuffle(fam_ids)
    n_train = int(len(fam_ids) * 0.70)
    n_val = int(len(fam_ids) * 0.15)
    splits = {"train": set(fam_ids[:n_train]), "val": set(fam_ids[n_train:n_train + n_val]),
              "test": set(fam_ids[n_train + n_val:])}
    for sp_name, ids in splits.items():
        cnt = defaultdict(int)
        for i, fid in enumerate(fam):
            if fid in ids:
                cnt[all_labels[i]] += 1
        print(f"{sp_name}: saludable={cnt[0]} contaminado={cnt[1]} desconocido={cnt[2]} total={sum(cnt.values())}")

    # 5) Desconocidos: distribucion por subcarpeta (para ver la diversidad)
    print("\n--- Desconocidos: subcarpetas ---")
    unknown = DATASET_DIR / "liquenes_desconocidos"
    subs = sorted(d.name for d in unknown.iterdir() if d.is_dir())
    print(f"subcarpetas: {len(subs)}; tamano min/max: ")

    print("\n========== FIN AUDITORIA ==========")


if __name__ == "__main__":
    main()