"""AUDITORIA DE SEÑAL LOCAL/TEXTURAL (solo lectura).

Compara caracteristicas locales/texturales entre:
  saludable vs contaminado (y vs desconocido, como referencia),
  con un analisis aparte EXCLUYENDO lcp_aug (contaminados originales lc+lcp).

No entrena, no modifica el dataset.
"""
import sys
from pathlib import Path

import cv2
import numpy as np

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATASET_DIR = PROJECT_ROOT / "ia" / "datasets"
EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
SIZE = 96  # resolucion interna para textura (4x mas rapido)


def list_flat(folder):
    return [p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in EXT]


def list_unknown():
    top = DATASET_DIR / "liquenes_desconocidos"
    out = []
    for sub in sorted(top.iterdir()):
        if sub.is_dir():
            out += [p for p in sub.iterdir() if p.is_file() and p.suffix.lower() in EXT]
    return out


def gray96(p):
    img = cv2.imread(str(p), cv2.IMREAD_GRAYSCALE)
    if img is None:
        return None
    img = cv2.resize(img, (SIZE, SIZE), interpolation=cv2.INTER_AREA)
    return img.astype(np.float32)


def lbp_hist(g, radius=1, n=8):
    # LBP manual 3x3 (8 vecinos)
    h = int(g.shape[0]); w = int(g.shape[1])
    code = np.zeros((h - 2, w - 2), dtype=np.uint8)
    c = g[1:h - 1, 1:w - 1]
    xo = [1, 1, 0, -1, -1, -1, 0, 1]
    yo = [0, 1, 1, 1, 0, -1, -1, -1]
    for k in range(8):
        ng = g[1 + yo[k]:h - 1 + yo[k], 1 + xo[k]:w - 1 + xo[k]]
        code |= ((ng >= c).astype(np.uint8) << k)
    hist = np.bincount(code.ravel(), minlength=256).astype(np.float64)
    hist /= hist.sum() + 1e-9
    return hist


def glcm_metrics(g, bins=8, d=1):
    lo, hi = g.min(), g.max()
    q = np.floor((g - lo) / (hi - lo + 1e-9) * (bins - 1)).astype(np.uint8)
    glcm = np.zeros((bins, bins), dtype=np.float64)
    for i in range(q.shape[0]):
        for j in range(q.shape[1] - d):
            a, b = int(q[i, j]), int(q[i, j + d])
            glcm[a, b] += 1
            glcm[b, a] += 1
    tot = glcm.sum()
    if tot <= 0:
        return 0.0, 0.0, 0.0, 0.0, 0.0
    p = glcm / tot
    ii = np.arange(bins)
    contrast = float((p * (ii[:, None] - ii[None, :]) ** 2).sum())
    homogeneity = float((p / (1 + (ii[:, None] - ii[None, :]) ** 2)).sum())
    energy = float((p ** 2).sum())
    entropy = float(-(p * np.log(p + 1e-12)).sum())
    px = p.sum(axis=0); py = p.sum(axis=1)
    ux, uy = float((px * ii).sum()), float((py * ii).sum())
    sx = float(np.sqrt((px * (ii - ux) ** 2).sum() + 1e-9))
    sy = float(np.sqrt((py * (ii - uy) ** 2).sum() + 1e-9))
    corr = float(((p * (ii[:, None] - ux) * (ii[None, :] - uy)).sum()) / (sx * sy + 1e-9))
    return contrast, homogeneity, energy, entropy, corr


def features(gray):
    hist = gray.ravel()
    mean_g = float(hist.mean())
    std_g = float(hist.std())
    # entropia de la distribucion de gris
    ng, _ = np.histogram(hist, bins=32, range=(0, 255))
    pr = ng / ng.sum()
    entropy_gray = float(-(pr * np.log(pr + 1e-12)).sum())
    # contraste local: std en bloques 8x8
    blocks = gray.reshape(SIZE // 8, 8, SIZE // 8, 8).transpose(0, 2, 1, 3)
    local_std = blocks.std(axis=(2, 3)).mean()
    # energia de alta frecuencia (laplaciano)
    lap = cv2.Laplacian(gray, cv2.CV_32F)
    hf_energy = float(np.abs(lap).mean())
    hf_std = float(np.abs(lap).std())
    # gradiente (Sobel) magnitudes
    sx = cv2.Sobel(gray, cv2.CV_32F, 1, 0)
    sy = cv2.Sobel(gray, cv2.CV_32F, 0, 1)
    mag = np.hypot(sx, sy)
    grad_mean = float(mag.mean())
    grad_stds = float(mag.std())
    # LBP
    hist = lbp_hist(gray)
    lbp_ent = float(-(hist * np.log(hist + 1e-12)).sum())
    lbp_uniform = float(np.sum(hist > 0))
    lbp_mean = float((np.arange(256) * hist).sum())
    # GLCM
    c, hom, en, ent, corr = glcm_metrics(gray)
    return {
        "gray_mean": mean_g, "gray_std": std_g,
        "entropy_gray": entropy_gray, "local_contrast": local_std,
        "hf_energy": hf_energy, "hf_std": hf_std,
        "grad_mean": grad_mean, "grad_std": grad_stds,
        "lbp_entropy": lbp_ent, "lbp_bins_active": lbp_uniform, "lbp_mean": lbp_mean,
        "glcm_contrast": c, "glcm_homogeneity": hom,
        "glcm_energy": en, "glcm_entropy": ent, "glcm_corr": corr,
    }


def collect(paths, sample=None, seed=0):
    rng = np.random.default_rng(seed)
    if sample and len(paths) > sample:
        idx = rng.choice(len(paths), size=sample, replace=False)
        paths = [paths[i] for i in idx]
    rows = []
    for p in paths:
        g = gray96(p)
        if g is None:
            continue
        rows.append(features(g))
    return rows


def table(rows, names):
    arr = np.array([[r[n] for n in names] for r in rows], dtype=np.float64)
    stats = {}
    for i, n in enumerate(names):
        col = arr[:, i]
        m, sd, md = float(col.mean()), float(col.std()), float(np.median(col))
        p25, p75 = float(np.percentile(col, 25)), float(np.percentile(col, 75))
        stats[n] = (m, sd, md, p25, p75)
    return stats


def cohen(a: dict, b: dict, names):
    out = {}
    for n in names:
        m1, s1, *_ = a[n]; m2, s2, *_ = b[n]
        sp = np.sqrt(((s1 ** 2) + (s2 ** 2)) / 2.0)
        out[n] = float((m1 - m2) / sp) if sp > 0 else 0.0
    return out


def line_stats(n, s):
    m, sd, md, p25, p75 = s
    return f"{n:18s} media={m:7.3f} sd={sd:6.3f} mediana={md:7.3f} p25={p25:7.3f} p75={p75:7.3f}"


def main():
    NAMES = ["gray_mean", "gray_std", "entropy_gray", "local_contrast", "hf_energy",
             "grad_mean", "lbp_entropy", "lbp_bins_active", "lbp_mean",
             "glcm_contrast", "glcm_homogeneity", "glcm_energy", "glcm_entropy", "glcm_corr"]

    sal_all = list_flat(DATASET_DIR / "liquenes_saludables")
    cont_all = list_flat(DATASET_DIR / "liquenes_contaminados")
    desc_all = list_unknown()

    # Muestreo aleatorio determinista
    rng = np.random.default_rng(7)
    sal = [sal_all[i] for i in rng.choice(len(sal_all), size=300, replace=False)]
    cont_sample = [cont_all[i] for i in rng.choice(len(cont_all), size=300, replace=False)]
    cont_orig = [p for p in cont_sample if not ("aug" in p.name)]
    desc_idx = rng.choice(len(desc_all), size=300, replace=False)
    desc = [desc_all[i] for i in desc_idx]

    print("=== AUDITORIA TEXTURA (muestra) ===")
    n_lc = sum(1 for p in cont_sample if p.name.startswith("lc_") and "aug" not in p.name)
    n_lcp = sum(1 for p in cont_sample if p.name.startswith("lcp_") and "aug" not in p.name)
    n_aug = sum(1 for p in cont_sample if "aug" in p.name)
    print(f"saludables n={len(sal)} | contaminados n={len(cont_sample)} "
          f"(lc={n_lc}, lcp={n_lcp}, lcp_aug={n_aug}) | desconocidos n={len(desc)}")
    print(f"contaminados ORIGINALES (lc+lcp) n={len(cont_orig)} (excluye lcp_aug)\n")

    rows_sal = collect(sal)
    rows_cont = collect(cont_sample)
    rows_cont_orig = collect(cont_orig)
    rows_desc = collect(desc)

    st_sal = table(rows_sal, NAMES)
    st_cont = table(rows_cont, NAMES)
    st_cont_orig = table(rows_cont_orig, NAMES)
    st_desc = table(rows_desc, NAMES)

    d_sal_cont = cohen(st_sal, st_cont, NAMES)
    d_sal_cont_orig = cohen(st_sal, st_cont_orig, NAMES)
    d_sal_desc = cohen(st_sal, st_desc, NAMES)
    d_cont_desc = cohen(st_cont, st_desc, NAMES)

    print("--- Estadisticas por clase ---")
    print("[saludables]")
    for n in NAMES:
        print(line_stats(n, st_sal[n]))
    print("[contaminados]")
    for n in NAMES:
        print(line_stats(n, st_cont[n]))
    print("[contaminados originales (lc+lcp)]")
    for n in NAMES:
        print(line_stats(n, st_cont_orig[n]))
    print("[desconocidos]")
    for n in NAMES:
        print(line_stats(n, st_desc[n]))

    print("\n--- Cohen's d (positivo = saludable mayor) ---")
    print(f"{'feature':20s} {'d sal/cont':>12s} {'d sal/cont(orig)':>16s} {'d sal/desc':>10s} {'d cont/desc':>10s}")
    for n in NAMES:
        print(f"{n:20s} {d_sal_cont[n]:12.3f} {d_sal_cont_orig[n]:16.3f} "
              f"{d_sal_desc[n]:10.3f} {d_cont_desc[n]:10.3f}")

    print("\n--- Resumen |Cohen's d| >= 0.2 (sal vs cont) ---")
    sig = [(n, abs(d_sal_cont[n])) for n in NAMES if abs(d_sal_cont[n]) >= 0.2]
    sig.sort(key=lambda x: -x[1])
    for n, v in sig:
        print(f"  {n}: |d|={v:.3f} (d={d_sal_cont[n]:+.3f})")
    if not sig:
        print("  ninguno")

    print("--- Resumen |Cohen's d| >= 0.2 (sal vs cont ORIGINALES lc+lcp) ---")
    sig2 = [(n, abs(d_sal_cont_orig[n])) for n in NAMES if abs(d_sal_cont_orig[n]) >= 0.2]
    sig2.sort(key=lambda x: -x[1])
    for n, v in sig2:
        print(f"  {n}: |d|={v:.3f}")
    if not sig2:
        print("  ninguno")


if __name__ == "__main__":
    main()