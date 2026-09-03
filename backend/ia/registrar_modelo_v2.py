"""Registra el modelo v2 entrenado en la base de datos (MySQL).

Usa los modelos ORM existentes (ModelosIA, Datasets, ModeloDataset).
No borra modelos anteriores (queda como respaldo). No modifica el schema.
No imprime credenciales.
"""
import json
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MODEL_DIR = PROJECT_ROOT / "ia" / "modelos"
REPORTS_DIR = PROJECT_ROOT / "ia" / "entrenamiento" / "reportes"
DATASET_DIR = PROJECT_ROOT / "ia" / "datasets"
KERAS = MODEL_DIR / "lichen_model_v2.keras"

from config.db import SessionLocal
from models.core import Dataset, ModeloDataset, ModeloIA


def main():
    if not KERAS.exists():
        print(f"ERROR: no existe el modelo {KERAS}")
        sys.exit(1)

    metrics = {}
    metrics_file = REPORTS_DIR / "metrics_v2.json"
    if metrics_file.exists():
        try:
            metrics = json.loads(metrics_file.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"Aviso: no se pudo leer metrics: {e}")

    acc = float(metrics.get("accuracy") or 0.0)
    f1 = float(metrics.get("f1") or 0.0)

    with SessionLocal() as db:
        # Dataset (get-or-create)
        dataset = (
            db.query(Dataset)
            .filter(Dataset.nombre_dataset == "liquenes_saludables_contaminados_v2")
            .first()
        )
        if not dataset:
            dataset = Dataset(
                nombre_dataset="liquenes_saludables_contaminados_v2",
                descripcion="500 saludables + 500 contaminados (incluye aumentadas), 224x224",
                cantidad_imagenes=1000,
                ruta_archivo=str(DATASET_DIR),
                tipo_datos="imagenes",
                fuente_dataset="dataset interno liquenes",
                estado_dataset="activo",
            )
            db.add(dataset)
            db.commit()
            db.refresh(dataset)

        # ModeloIA nuevo (version identificable; el anterior queda como respaldo)
        modelo = ModeloIA(
            nombre_modelo="clasificador ambiental binario",
            version="v2.0",
            tipo_modelo="cnn",
            descripcion="CNN 2 clases (liquen saludable=0, liquen contaminado=1). "
                        "Dataset 500+500. Preprocesado 224x224 RGB /255.",
            precision_modelo=acc,
            dataset_utilizado=dataset.nombre_dataset,
            fecha_entrenamiento=datetime.utcnow(),
            estado_modelo="activo",
            observaciones=json.dumps(
                {
                    "f1": f1,
                    "accuracy": acc,
                    "clases": {"0": "liquen saludable", "1": "liquen contaminado"},
                    "archivo": str(KERAS),
                },
                ensure_ascii=False,
            ),
        )
        db.add(modelo)
        db.commit()
        db.refresh(modelo)

        # Asociacion modelo-dataset
        db.add(ModeloDataset(id_modelo=modelo.id_modelo, id_dataset=dataset.id_dataset))
        db.commit()

        prev = db.query(ModeloIA).filter(ModeloIA.id_modelo == modelo.id_modelo).first()
        print(f"Modelo registrado:")
        print(f"  ID: {modelo.id_modelo}")
        print(f"  version: {modelo.version}")
        print(f"  dataset asociado: {dataset.nombre_dataset} (id {dataset.id_dataset})")
        print(f"  ruta: {KERAS}")
        print(f"  estado: {modelo.estado_modelo}")
        print(f"  metrics: acc={acc:.4f} f1={f1:.4f}")
        print("  Modelo anterior conservado como respaldo (no se elimina).")


if __name__ == "__main__":
    main()