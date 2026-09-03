"""Registro de V7 en MySQL (PREPARADO, NO se ejecuta en esta fase).

Despues de entrenar y validar V7 (macro F1 test y cm favorable), esta fase
POSTERIOR decidira si V7 reemplaza a V3. Este script deja lista la operacion.

Reglas:
- Requiere que lichen_model_v7.keras exista y que metrics_v7.json se haya
  generado.
- Estado: 'activo' solo si se aprueba explicitamente (--activate); por defecto
  registra como 'inactivo'.
- NO marca V3 como inactivo automaticamente; eso lo decide el flujo posterior
  de activacion comparando V3 vs V7.
- Usa resolver_modelo_activo para validar que el activo sigue siendo resolubile
  de forma segura.

Uso (FASE POSTERIOR):
    python ia/registrar_modelo_v7.py                     # inactivo, solo registro
    python ia/registrar_modelo_v7.py --activate          # activo (requiere aprobacion)
"""
import argparse
import json
import sys
from datetime import datetime, UTC
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MODEL_DIR = PROJECT_ROOT / "ia" / "modelos"
REPORTS_DIR = PROJECT_ROOT / "ia" / "entrenamiento" / "reportes"
DATASET_DIR = PROJECT_ROOT / "ia" / "datasets"
KERAS = MODEL_DIR / "lichen_model_v7.keras"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--activate", action="store_true",
                    help="registrar V7 como activo (solo tras aprobacion explicita)")
    args = ap.parse_args()

    if not KERAS.exists():
        print(f"ERROR: no existe {KERAS}. Entrena V7 primero.")
        sys.exit(1)

    metrics = {}
    mf = REPORTS_DIR / "metrics_v7.json"
    if mf.exists():
        try:
            metrics = json.loads(mf.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"Aviso metrics: {e}")

    acc = float(metrics.get("accuracy") or 0.0)
    f1 = float(metrics.get("f1_macro") or 0.0)

    if args.activate:
        from ia.resolver_modelo_activo import resolver_modelo_activo, ActiveModelError
        try:
            actual = resolver_modelo_activo()
        except ActiveModelError as e:
            print(f"ERROR: el modelo activo no es resolubile de forma segura: {e}")
            sys.exit(1)
        print(f"Aprobacion recibida. Modelo activo actual: {actual}")

    from config.db import SessionLocal
    from models.core import Dataset, ModeloDataset, ModeloIA

    with SessionLocal() as db:
        dataset = (
            db.query(Dataset)
            .filter(Dataset.nombre_dataset == "liquenes_3clases_v7")
            .first()
        )
        if not dataset:
            dataset = Dataset(
                nombre_dataset="liquenes_3clases_v7",
                descripcion="500+500+1159 (3 clases) - split leakage-safe seed 42 "
                            "(lcp/lcp_aug solo train, test solo originales)",
                cantidad_imagenes=2159,
                ruta_archivo=str(DATASET_DIR),
                tipo_datos="imagenes",
                fuente_dataset="dataset interno liquenes 3 clases",
                estado_dataset="activo" if args.activate else "inactivo",
            )
            db.add(dataset)
            db.commit()
            db.refresh(dataset)

        modelo = ModeloIA(
            nombre_modelo="clasificador ambiental 3 clases (v7)",
            version="v7.0",
            tipo_modelo="efficientnetb1",
            descripcion="Transfer learning 2 fases, split leakage-free seed 42. "
                        "Registrado como " + ("activo" if args.activate else "inactivo (pendiente aprobacion)") + ".",
            precision_modelo=acc,
            dataset_utilizado=dataset.nombre_dataset,
            fecha_entrenamiento=datetime.now(UTC),
            estado_modelo="activo" if args.activate else "inactivo",
            observaciones=json.dumps(
                {
                    "f1_macro": f1,
                    "accuracy": acc,
                    "balanced_accuracy": metrics.get("balanced_accuracy"),
                    "clases": {"0": "liquen saludable", "1": "liquen contaminado", "2": "desconocido"},
                    "archivo": str(KERAS),
                },
                ensure_ascii=False,
            ),
        )
        db.add(modelo)
        db.commit()
        db.refresh(modelo)
        db.add(ModeloDataset(id_modelo=modelo.id_modelo, id_dataset=dataset.id_dataset))
        db.commit()

        print(f"Modelo v7 registrado ({modelo.estado_modelo})")
        print(f"  ID: {modelo.id_modelo} | version {modelo.version} | acc {acc:.4f} | f1_macro {f1:.4f}")
        print(f"  dataset asociado: {dataset.nombre_dataset} (id {dataset.id_dataset})")
        print(f"  ruta: {KERAS}")


if __name__ == "__main__":
    main()