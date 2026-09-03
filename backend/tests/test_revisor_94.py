"""Tests minimos del revisor visual de 94 etiquetas criticas.

Valida: 94 registros, rutas existentes, CSV de salida, decisiones vacias y
que el dataset no se modifica. No toca imagenes ni carpetas.
"""
from pathlib import Path
import csv
import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ia.auditoria_2026 import revisor_94 as rv

DATASETS = rv.DATASETS
AUDIT = rv.AUDIT


def test_94_registros_validos():
    rows = rv.cargar_criticas()
    assert len(rows) == 94


def test_sin_duplicados():
    rows = rv.cargar_criticas()
    nombres = [r["archivo"] for r in rows]
    assert len(nombres) == len(set(nombres))


def test_rutas_imagenes_existen():
    rows = rv.cargar_criticas()
    for r in rows:
        assert r["_ruta"].is_file(), f"falta {r['_ruta']}"


def test_categorias_esperadas():
    rows = rv.cargar_criticas()
    cats = {}
    for r in rows:
        key = (r["clase_actual"], r["categoria"])
        cats[key] = cats.get(key, 0) + 1
    assert cats[("saludable", "-")] == 49
    assert cats[("contaminado", "lc")] == 40
    assert cats[("contaminado", "lcp")] == 1
    assert cats[("contaminado", "lcp_aug")] == 4


def test_orden_prioridades():
    rows = rv.cargar_criticas()
    tiers = ["1", "2", "3", "4"]
    actual = [str(r["_prioridad_n"]) for r in rows]
    ord_tiers = [t for t in tiers for _ in range(actual.count(t))]
    assert actual == ord_tiers


def test_resultados_inicialmente_vacios(tmp_path):
    rows = rv.cargar_criticas()
    out = tmp_path / "resultados.csv"
    rv.RESULTADOS = out
    rv.escribir_resultados(rows, {})
    with open(out, encoding="utf-8", newline="") as f:
        data = list(csv.DictReader(f))
    assert len(data) == 94
    for row in data:
        assert row["decision_humana"] == ""
        assert row["observaciones"] == ""
        assert row["revisado"] == ""


def test_resultados_conserva_info_original(tmp_path):
    rows = rv.cargar_criticas()
    out = tmp_path / "resultados.csv"
    rv.RESULTADOS = out
    estado = {rows[0]["archivo"]: ("mantener", "ok visual")}
    rv.escribir_resultados(rows, estado)
    with open(out, encoding="utf-8", newline="") as f:
        data = list(csv.DictReader(f))
    primero = next(row for row in data if row["archivo"] == rows[0]["archivo"])
    assert primero["decision_humana"] == "mantener"
    assert primero["observaciones"] == "ok visual"
    assert primero["revisado"] == "si"
    assert primero["sugerencia_estadistica"] == rows[0]["sugerencia_estadistica"]


def test_dataset_no_modificado():
    """Las carpetas del dataset conservan sus conteos exactos."""
    salvadas = [rv.CLASE_FOLDER["saludable"], rv.CLASE_FOLDER["contaminado"]]
    desc = rv.CLASE_FOLDER["desconocido"]
    n_sal = sum(1 for p in salvadas[0].iterdir() if p.is_file())
    n_con = sum(1 for p in salvadas[1].iterdir() if p.is_file())
    n_desc = sum(1 for p in desc.rglob("*") if p.is_file())
    assert n_sal == 500
    assert n_con == 500
    assert n_desc == 1159


def test_validacion_detecta_cantidad_incorrecta():
    rows = rv.cargar_criticas()
    errores = rv.validar_criticas(rows[:50])
    assert any("Se esperaban 94 filas" in e for e in errores)


def test_validacion_detecta_archivo_inexistente(tmp_path):
    rows = [
        {"archivo": "no_existe_xyz.jpg", "clase_actual": "saludable",
         "categoria": "-", "motivo_auditoria": "", "sugerencia_estadistica": "",
         "confianza_estadistica": "", "prioridad": "CRITICO"}
    ] * 94
    errores = rv.validar_criticas(rows)
    assert any("Imagen no existe" in e for e in errores)