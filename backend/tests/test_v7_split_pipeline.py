"""Tests de la preparacion definitiva del pipeline V7.

Valida el split leakage-safe (manifest), las reglas lcp/lcp_aug, el mapping de
clases y la reproducibilidad. NO entrena nada. NO modifica el dataset.
"""
import csv
from collections import Counter
from pathlib import Path
import random
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ia.entrenamiento import create_split_v7 as sp

MANIFEST = Path(__file__).resolve().parents[1] / "ia" / "entrenamiento" / "dataset_v7_manifest.csv"


def _rows():
    with open(MANIFEST, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def test_manifest_existe():
    assert MANIFEST.exists(), "genera el manifest con create_split_v7.py"


def test_conteos_500_500_1159():
    rows = _rows()
    by_class = Counter(r["class_name"] for r in rows)
    assert by_class["saludable"] == 500
    assert by_class["contaminado"] == 500
    assert by_class["desconocido"] == 1159
    assert len(rows) == 2159


def test_clases_0_1_2():
    rows = _rows()
    assert {int(r["class_id"]) for r in rows} == {0, 1, 2}
    for r in rows:
        assert int(r["class_id"]) == sp.CLASS_ID[r["class_name"]]
        assert r["class_name"] in ("saludable", "contaminado", "desconocido")


def test_sin_duplicados():
    rows = _rows()
    nombres = [r["filename"] for r in rows]
    assert len(nombres) == len(set(nombres))


def test_archivos_existen():
    rows = _rows()
    faltan = [r["filename"] for r in rows if not Path(r["filepath"]).is_file()]
    assert not faltan, f"faltan {len(faltan)}"


def test_todo_en_exactamente_un_split():
    rows = _rows()
    assert all(r["split"] in ("train", "val", "test") for r in rows)
    # cada archivo aparece una sola vez -> exactamente un split


def test_sin_leakage_por_familia():
    rows = _rows()
    fam = {}
    for r in rows:
        fam.setdefault(r["group_id"], set()).add(r["split"])
    leaked = {k: sorted(v) for k, v in fam.items() if len(v) > 1}
    assert not leaked, leaked


def test_lcp_familia_solo_train():
    rows = _rows()
    fam = [r for r in rows if r["group_id"] == "lcp_family"]
    assert fam
    assert all(r["split"] == "train" for r in fam)
    assert sum(1 for r in fam if r["is_augmented"] == "true") == 160
    assert sum(1 for r in fam if r["is_augmented"] == "false") == 14


def test_lcp_aug_solo_train_nunca_val_test():
    rows = _rows()
    aug = [r for r in rows if r["filename"].startswith("lcp_aug")]
    assert len(aug) == 160
    assert all(r["split"] == "train" for r in aug)


def test_test_sin_aumentadas_y_sin_lcp():
    rows = _rows()
    te = [r for r in rows if r["split"] == "test"]
    assert not any(r["filename"].startswith(("lcp_aug", "lcp_")) for r in te)
    assert not any(r["is_augmented"] == "true" for r in te)


def test_contaminados_test_usan_lc_originales():
    rows = _rows()
    te_cont = [r for r in rows if r["split"] == "test" and r["class_name"] == "contaminado"]
    assert all(r["filename"].startswith("lc_") for r in te_cont)
    assert te_cont  # al menos alguna imagen


def test_split_reproducible():
    m1 = sp.build_manifest(seed=42)
    m2 = sp.build_manifest(seed=42)
    assert m1 == m2
    m3 = sp.build_manifest(seed=7)
    assert m1 != m3


def test_validacion_manifest_pasa():
    rows = _rows()
    arr = [[r["filename"], r["filepath"], r["class_id"], r["class_name"],
            r["split"], r["group_id"], r["is_augmented"], r["source_original"]]
           for r in rows]
    assert sp.validate_manifest(arr) == []


def test_mapping_clases_estable():
    assert sp.CLASS_ID == {"saludable": 0, "contaminado": 1, "desconocido": 2}
    assert sp.CLASS_NAME == {0: "saludable", 1: "contaminado", 2: "desconocido"}


def test_augmentation_solo_train_por_construccion():
    # el loader V7 entrena solo con filas split=train
    rows = _rows()
    tr = [r for r in rows if r["split"] == "train"]
    va = [r for r in rows if r["split"] == "val"]
    te = [r for r in rows if r["split"] == "test"]
    assert not any(r["is_augmented"] == "true" for r in va + te)
    assert any(r["is_augmented"] == "true" for r in tr)


def test_manifest_compatible_con_entrenamiento():
    from ia.entrenamiento import train_model_v7 as t7

    rows = t7.load_manifest(MANIFEST)
    assert len(rows) == 2159
    tr = t7.split_rows(rows, "train")
    va = t7.split_rows(rows, "val")
    te = t7.split_rows(rows, "test")
    assert tr and va and te
    # val y test no deben contener aumentadas
    assert not any(r["is_augmented"] == "true" for r in va + te)