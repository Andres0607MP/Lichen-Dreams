"""Registra el modelo v5 (MobileNetV2, 3 clases) como INACTIVO.

v5 no mejoro a v3 (F1 macro 0.2374 < 0.2406; predice casi todo como
'desconocido'), por lo tanto NO reemplaza al modelo activo (v3).

No crea migraciones ni borra modelos.
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
KERAS = MODEL_DIR / "lichen_model_v5.keras"

from config.db import SessionLocal
from models.core import Dataset, ModeloDataset, ModeloIA


def main():
    if not KERAS.exists():
        print(f"ERROR: no existe {KERAS}")
        sys.exit(1)

    metrics = {}
    mf = REPORTS_DIR / "metrics_v5.json"
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
            .filter(Dataset.nombre_dataset == "liquenes_3clases_v5")
            .first()
        )
        if not dataset:
            dataset = Dataset(
                nombre_dataset="liquenes_3clases_v5",
                descripcion="500+500+1159 (3 clases) - MobileNetV2 transfer learning",
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
            nombre_modelo="clasificador ambiental 3 clases (v5)",
            version="v5.0",
            tipo_modelo="mobilenetv2",
            descripcion="Transfer Learning MobileNetV2 (2 fases). v5 NO supero a v3.",
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
        print(f"Modelo v5 registrado (INACTIVO):")
        print(f"  ID: {modelo.id_modelo} | version {modelo.version} | acc {acc:.4f} | f1_macro {f1:.4f}")
        print(f"  dataset asociado: {dataset.nombre_dataset} (id {dataset.id_dataset})")
        print(f"  ruta: {KERAS}")
        print(f"  Modelo activo actual: ID {activo.id_modelo if activo else None} (v3 conservado, v5 no reemplaza)")


if __name__ == "__main__":
    main()