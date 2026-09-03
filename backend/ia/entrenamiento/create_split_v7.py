"""Creacion del split reproducible y leakage-safe para V7.

Reglas:
- seed fija 42 (documentada en README_V7.md).
- Estratificado por clase; conteos globales 500/500/1159 (total 2159).
- Agrupacion por FAMILIA: todas las imagenes derivadas de un mismo original
  permanecen en el MISMO split. La familia `lcp_*` + sus `lcp_aug_*` van
  COMPLETAS a TRAIN (el mapeo lcp_aug -> lcp padre no fue registrado al
  generarse, por lo que la unica garantia fuerte es agrupar la familia entera).
- NUNCA: original en train y derivado en val/test.
- LOS `lcp_aug_*` SOLO pueden estar en TRAIN.
- TEST usa SOLO originales reales (sin aumentadas).
- Desconocidos: la familia = subcarpeta tematica (cada subcarpeta entera va a
  un unico split), para no repartir categorias visuales entre splits.

Salida: dataset_v7_manifest.csv + validaciones integradas.

Uso:
    python ia/entrenamiento/create_split_v7.py            # genera + valida
    python ia/entrenamiento/create_split_v7.py --seed 42  # semilla distinta
"""
import argparse
import csv
import random
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
DATASET_DIR = PROJECT_ROOT / "ia" / "datasets"
OUT_DIR = Path(__file__).resolve().parent
MANIFEST = OUT_DIR / "dataset_v7_manifest.csv"

SEED_DEFAULT = 42
EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tiff", ".tif"}

CLASS_NAME = {0: "saludable", 1: "contaminado", 2: "desconocido"}
CLASS_ID = {v: k for k, v in CLASS_NAME.items()}

RAIN = 0.70
RV = 0.15


def list_imgs(folder):
    return sorted(
        (p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in EXT),
        key=lambda p: p.name,
    )


def split_percent(files, rng, p_tr=RAIN, p_va=RV):
    """Divide una lista (sin familias) en train/val/test por porcentajes."""
    files = list(files)
    rng.shuffle(files)
    n = len(files)
    n_tr = int(round(n * p_tr))
    n_va = int(round(n * p_va))
    n_te = n - n_tr - n_va
    return files[:n_tr], files[n_tr:n_tr + n_va], files[n_tr + n_va:]


def group_unknown(subdirs, rng):
    """Divide por subcarpeta entera (familia = categoria)."""
    subdirs = list(subdirs)
    rng.shuffle(subdirs)
    n = len(subdirs)
    n_tr = int(round(n * RAIN))
    n_va = int(round(n * RV))
    return subdirs[:n_tr], subdirs[n_tr:n_tr + n_va], subdirs[n_tr + n_va:]


def build_manifest(seed=SEED_DEFAULT):
    rng = random.Random(seed)
    rows = []

    # --- Saludables (0): sin familias ---
    sal_all = list_imgs(DATASET_DIR / "liquenes_saludables")
    sal_tr, sal_va, sal_te = split_percent(sal_all, rng)
    sal_splits = [("train", sal_tr), ("val", sal_va), ("test", sal_te)]
    for split, files in sal_splits:
        for p in files:
            gid = p.stem
            rows.append([p.name, str(p), 0, CLASS_NAME[0], split, gid, "false", p.name])

    # --- Contaminados (1): lc_* (originales independientes) + familia lcp ---
    cont_dir = DATASET_DIR / "liquenes_contaminados"
    lc = [p for p in list_imgs(cont_dir) if p.name.startswith("lc_") and "aug" not in p.name]
    lcp = [p for p in list_imgs(cont_dir) if p.name.startswith("lcp_") and "aug" not in p.name]
    lcp_aug = [p for p in list_imgs(cont_dir) if p.name.startswith("lcp_aug")]

    lc_tr, lc_va, lc_te = split_percent(lc, rng)
    for split, files in [("train", lc_tr), ("val", lc_va), ("test", lc_te)]:
        for p in files:
            rows.append([p.name, str(p), 1, CLASS_NAME[1], split, p.stem, "false", p.name])

    # Familia lcp entera -> TRAIN (incluye sus aumentadas)
    for p in lcp + lcp_aug:
        is_aug = p.name.startswith("lcp_aug")
        src = p.name if not is_aug else "lcp_*"
        rows.append([p.name, str(p), 1, CLASS_NAME[1], "train", "lcp_family", str(is_aug).lower(), src])

    # --- Desconocidos (2): familia = subcarpeta ---
    desc_root = DATASET_DIR / "liquenes_desconocidos"
    subs = sorted((s for s in desc_root.iterdir() if s.is_dir()), key=lambda s: s.name)
    sub_tr, sub_va, sub_te = group_unknown(subs, rng)
    for split, sublist in [("train", sub_tr), ("val", sub_va), ("test", sub_te)]:
        for s in sublist:
            for p in list_imgs(s):
                rows.append([p.name, str(p), 2, CLASS_NAME[2], split, s.name, "false", p.name])

    rows.sort(key=lambda r: (CLASS_ID[r[3]], r[0]))
    return rows


def validate_manifest(rows):
    """Devuelve lista de errores (vacia = OK). Normaliza class_id a int."""
    normalizadas = []
    for r in rows:
        cid = r[2]
        if isinstance(cid, str) and cid.isdigit():
            cid = int(cid)
        normalizadas.append([r[0], r[1], cid, r[3], r[4], r[5], r[6], r[7]])
    return _validate_rows(normalizadas)


def _validate_rows(rows):
    errs = []
    by_class = {}
    for r in rows:
        by_class[r[3]] = by_class.get(r[3], 0) + 1
    if by_class.get("saludable") != 500:
        errs.append(f"saludable={by_class.get('saludable')} (esperado 500)")
    if by_class.get("contaminado") != 500:
        errs.append(f"contaminado={by_class.get('contaminado')} (esperado 500)")
    if by_class.get("desconocido") != 1159:
        errs.append(f"desconocido={by_class.get('desconocido')} (esperado 1159)")
    if len(rows) != 2159:
        errs.append(f"total={len(rows)} (esperado 2159)")

    # integridad
    nombres = [r[0] for r in rows]
    dups = sorted({n for n in nombres if nombres.count(n) > 1})
    if dups:
        errs.append(f"archivos duplicados: {dups[:10]}")
    faltan = [r[1] for r in rows if not Path(r[1]).is_file()]
    if faltan:
        errs.append(f"archivos inexistentes ({len(faltan)}): {faltan[:5]}")
    clases_ok = {r[2] for r in rows} == {0, 1, 2}
    if not clases_ok:
        errs.append(f"class_id invalidos: {sorted({r[2] for r in rows})}")
    splits = {r[4] for r in rows}
    if not splits <= {"train", "val", "test"}:
        errs.append(f"splits invalidos: {splits}")

    # leakage por familia: un group_id en UN solo split
    fam_split = {}
    for r in rows:
        fam_split.setdefault(r[5], set()).add(r[4])
    leaked = {k: sorted(v) for k, v in fam_split.items() if len(v) > 1}
    if leaked:
        errs.append(f"leakage por familia ({len(leaked)}): {dict(list(leaked.items())[:8])}")

    # lcp/lcp_aug: familia lcp_family debe estar SOLO en train y todo junto
    fam_rows = [r for r in rows if r[5] == "lcp_family"]
    if not fam_rows:
        errs.append("no existe la familia lcp_family")
    else:
        fam_splits = {r[4] for r in fam_rows}
        if fam_splits != {"train"}:
            errs.append(f"familia lcp no esta solo en train: {fam_splits}")
        augs = [r for r in fam_rows if r[6] == "true"]
        if augs and any(r[4] != "train" for r in augs):
            errs.append("lcp_aug fuera de train")
        # no puede existir lcp_aug en otra familia
        aug_otra = [r[0] for r in rows if r[0].startswith("lcp_aug") and r[5] != "lcp_family"]
        if aug_otra:
            errs.append(f"lcp_aug con familia distinta: {aug_otra[:5]}")

    # test sin aumentadas
    test_aug = [r[0] for r in rows if r[4] == "test" and r[0].startswith("lcp_aug")]
    if test_aug:
        errs.append(f"test contiene aumentadas: {test_aug[:5]}")

    # sin lcp en test/val
    lcp_val_test = [r[0] for r in rows if r[5] == "lcp_family" and r[4] != "train" and not r[0].startswith("lcp_aug")]
    if lcp_val_test:
        errs.append(f"lcp_* en val/test: {lcp_val_test[:5]}")

    return errs


def write_manifest(rows):
    with open(MANIFEST, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["filename", "filepath", "class_id", "class_name",
                    "split", "group_id", "is_augmented", "source_original"])
        w.writerows(rows)


def summary(rows):
    from collections import Counter
    print(f"Total: {len(rows)}")
    by_cls = Counter(r[3] for r in rows)
    by_split = Counter(r[4] for r in rows)
    for c in ("saludable", "contaminado", "desconocido"):
        print(f"  clase {c}: {by_cls[c]}")
    for s in ("train", "val", "test"):
        per = Counter(r[3] for r in rows if r[4] == s)
        print(f"  split {s}: total={by_split[s]} sal={per['saludable']} cont={per['contaminado']} desc={per['desconocido']}")
    aug = sum(1 for r in rows if r[6] == "true")
    lcp_in_train = sum(1 for r in rows if r[5] == "lcp_family" and r[6] == "false")
    print(f"  lcp_aug total: {aug} (todos train) | lcp_* en train: {lcp_in_train}")


def main():
    ap = argparse.ArgumentParser(description="Genera y valida el split V7 (leakage-safe)")
    ap.add_argument("--seed", type=int, default=SEED_DEFAULT, help=f"semilla (default {SEED_DEFAULT})")
    ap.add_argument("--check", action="store_true", help="solo valida el manifest existente")
    args = ap.parse_args()

    if args.check:
        if not MANIFEST.exists():
            print(f"ERROR: no existe {MANIFEST}")
            sys.exit(1)
        with open(MANIFEST, encoding="utf-8", newline="") as f:
            rows = list(csv.reader(f))[1:]
        errs = validate_manifest(rows)
    else:
        rows = build_manifest(seed=args.seed)
        errs = validate_manifest(rows)
        if errs:
            print("Split NO APROBADO por validaciones. No se escribe el manifest.")
            for e in errs:
                print(f"  [X] {e}")
            sys.exit(1)
        write_manifest(rows)
        print(f"Manifest escrito: {MANIFEST}")

    if errs:
        print(f"VALIDEZ: {len(errs)} errores")
        for e in errs:
            print(f"  [X] {e}")
        sys.exit(1)

    print("VALIDEZ: OK (0 errores)")
    summary(rows)


if __name__ == "__main__":
    main()