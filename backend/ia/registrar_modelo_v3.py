"""Registra el modelo v3 (3 clases) en la base de datos (MySQL).

Usa los modelos ORM existentes; no crea columnas ni migraciones.
No borra modelos anteriores (quedan como respaldo).
No imprime credenciales.
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
KERAS = MODEL_DIR / "lichen_model_v3.keras"

from config.db import SessionLocal
from models.core import Dataset, ModeloDataset, ModeloIA


def main():
    if not KERAS.exists():
        print(f"ERROR: no existe el modelo {KERAS}")
        sys.exit(1)

    metrics = {}
    metrics_file = REPORTS_DIR / "metrics_v3.json"
    if metrics_file.exists():
        try:
            metrics = json.loads(metrics_file.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"Aviso: no se pudo leer metrics: {e}")

    acc = float(metrics.get("accuracy") or 0.0)
    f1 = float(metrics.get("f1_macro") or 0.0)

    with SessionLocal() as db:
        dataset = (
            db.query(Dataset)
            .filter(Dataset.nombre_dataset == "liquenes_3clases_v3")
            .first()
        )
        if not dataset:
            dataset = Dataset(
                nombre_dataset="liquenes_3clases_v3",
                descripcion="500 saludables + 500 contaminados + 1159 desconocidos (3 clases)",
                cantidad_imagenes=2159,
                ruta_archivo=str(DATASET_DIR),
                tipo_datos="imagenes",
                fuente_dataset="dataset interno liquenes 3 clases",
                estado_dataset="activo",
            )
            db.add(dataset)
            db.commit()
            db.refresh(dataset)

        modelo = ModeloIA(
            nombre_modelo="clasificador ambiental 3 clases",
            version="v3.0",
            tipo_modelo="cnn",
            descripcion="CNN 3 clases: saludable=0, contaminado=1, desconocido=2. "
                        "Dataset 500+500+1159. Preprocesado 224x224 RGB /255.",
            precision_modelo=acc,
            dataset_utilizado=dataset.nombre_dataset,
            fecha_entrenamiento=datetime.now(UTC),
            estado_modelo="activo",
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

        print(f"Modelo registrado:")
        print(f"  ID: {modelo.id_modelo}")
        print(f"  version: {modelo.version}")
        print(f"  dataset asociado: {dataset.nombre_dataset} (id {dataset.id_dataset})")
        print(f"  ruta: {KERAS}")
        print(f"  estado: {modelo.estado_modelo}")
        print(f"  metrics: acc={acc:.4f} f1_macro={f1:.4f}")
        print("  Modelos anteriores conservados como respaldo.")


if __name__ == "__main__":
    main()