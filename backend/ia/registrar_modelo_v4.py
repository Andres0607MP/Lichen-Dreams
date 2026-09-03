"""Registra el modelo v4 (3 clases) en BD como INACTIVO.

v4 no mejoro el F1 macro respecto a v3 (resultado honesto del entrenamiento),
por lo que NO se activa: v3 permanece como modelo activo y v4 queda registrado
para comparacion/respaldo. No crea migraciones; no borra modelos.
"""
import json
import sys
from datetime import datetime, UTC
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MODEL_DIR = PROJECT_ROOT / "ia" / "modelos"
REPORTS_DIR = PROJECT_ROOT / "ia" / "entrenamiento" / "reportes"
DATASET_DIR = PROJECT_ROOT / "ia" / "datasets"
KERAS = MODEL_DIR / "lichen_model_v4.keras"

from config.db import SessionLocal
from models.core import Dataset, ModeloDataset, ModeloIA


def main():
    if not KERAS.exists():
        print(f"ERROR: no existe {KERAS}")
        sys.exit(1)

    metrics = {}
    mf = REPORTS_DIR / "metrics_v4.json"
    if mf.exists():
        try:
            metrics = json.loads(mf.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"Aviso metrics: {e}")

    acc = float(metrics.get("accuracy") or 0.0)
    f1 = float(metrics.get("f1_macro") or 0.0)

    with SessionLocal() as db:
        dataset = (
            db.query(Dataset)
            .filter(Dataset.nombre_dataset == "liquenes_3clases_v4")
            .first()
        )
        if not dataset:
            dataset = Dataset(
                nombre_dataset="liquenes_3clases_v4",
                descripcion="500+500+1159 (3 clases) - variante v4",
                cantidad_imagenes=2159,
                ruta_archivo=str(DATASET_DIR),
                tipo_datos="imagenes",
                fuente_dataset="dataset interno liquenes 3 clases",
                estado_dataset="inactivo",
            )
            db.add(dataset)
            db.commit()
            db.refresh(dataset)

        modelo = ModeloIA(
            nombre_modelo="clasificador ambiental 3 clases (v4)",
            version="v4.0",
            tipo_modelo="cnn-residual",
            descripcion="Residual conv 32/64/128/256 + GAP, 3 clases. v4 NO mejoro v3.",
            precision_modelo=acc,
            dataset_utilizado=dataset.nombre_dataset,
            fecha_entrenamiento=datetime.now(UTC),
            estado_modelo="inactivo",
            observaciones=json.dumps(
                {
                    "f1_macro": f1,
                    "accuracy": acc,
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

        activo = (
            db.query(ModeloIA)
            .filter(ModeloIA.estado_modelo == "activo")
            .order_by(ModeloIA.id_modelo.desc())
            .first()
        )
        print(f"Modelo v4 registrado (INACTIVO):")
        print(f"  ID: {modelo.id_modelo} | version {modelo.version} | acc {acc:.4f} | f1 {f1:.4f}")
        print(f"  dataset asociado: {dataset.nombre_dataset} (id {dataset.id_dataset})")
        print(f"  ruta: {KERAS}")
        print(f"  Modelo activo actual: ID {activo.id_modelo if activo else None} "
              f"(v3 conservado como activo porque v4 no mejoro)")


if __name__ == "__main__":
    main()