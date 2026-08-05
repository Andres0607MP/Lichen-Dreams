import os
from pathlib import Path

import cv2
import numpy as np
import tensorflow as tf

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
DATASET_DIR = PROJECT_ROOT / "ia" / "datasets"
MODEL_DIR = PROJECT_ROOT / "ia" / "modelos"
MODEL_FILENAME = "lichen_model.keras"
MODEL_PATH = MODEL_DIR / MODEL_FILENAME
INPUT_SIZE = (224, 224)
NUM_CLASSES = 3
BATCH_SIZE = 4
EPOCHS = 10
LEARNING_RATE = 0.001

LABEL_MAP = {
    "liquenes_saludables": 0,
    "liquenes_contaminados": 1,
    "liquenes_desconocidos": 2,
}

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png"}


def load_dataset():
    images = []
    labels = []

    for subdir_name, label in LABEL_MAP.items():
        folder = DATASET_DIR / subdir_name
        if not folder.exists():
            print(f"Advertencia: carpeta no encontrada: {folder}")
            continue

        for filename in sorted(folder.iterdir()):
            if filename.suffix.lower() not in SUPPORTED_EXTENSIONS:
                continue

            img = cv2.imread(str(filename), cv2.IMREAD_UNCHANGED)
            if img is None:
                print(f"Advertencia: no se pudo leer {filename}")
                continue

            if img.ndim == 2:
                img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
            elif img.shape[2] == 4:
                img = cv2.cvtColor(img, cv2.COLOR_BGRA2RGB)
            elif img.shape[2] == 3:
                img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            else:
                print(f"Advertencia: canales no soportados en {filename}")
                continue

            img = cv2.resize(img, INPUT_SIZE)
            img = img.astype(np.float32) / 255.0
            images.append(img)
            labels.append(label)

    if len(images) == 0:
        raise RuntimeError("No se encontraron imágenes válidas en los datasets")

    x = np.array(images)
    y = np.array(labels)
    return x, y


def build_model():
    from tensorflow.keras import layers, models

    model = models.Sequential(
        [
            layers.Input(shape=(INPUT_SIZE[0], INPUT_SIZE[1], 3)),
            layers.Conv2D(32, (3, 3), activation="relu", padding="same"),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            layers.Dropout(0.25),
            layers.Conv2D(64, (3, 3), activation="relu", padding="same"),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            layers.Dropout(0.25),
            layers.Conv2D(128, (3, 3), activation="relu", padding="same"),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            layers.Dropout(0.25),
            layers.Flatten(),
            layers.Dense(128, activation="relu"),
            layers.Dropout(0.5),
            layers.Dense(NUM_CLASSES, activation="softmax"),
        ]
    )

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=LEARNING_RATE),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    return model


def train():
    print("Cargando dataset...")
    x, y = load_dataset()
    print(f"Total de imágenes: {len(x)}")
    print(f"Clases: {LABEL_MAP}")

    print("Construyendo modelo...")
    model = build_model()
    model.summary()

    print("Entrenando modelo...")
    history = model.fit(
        x,
        y,
        batch_size=BATCH_SIZE,
        epochs=EPOCHS,
        validation_split=0.2 if len(x) > 4 else 0.0,
        verbose=1,
    )

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    model.save(str(MODEL_PATH))
    print(f"Modelo guardado en: {MODEL_PATH}")

    train_loss = history.history["loss"][-1]
    train_acc = history.history["accuracy"][-1]
    print(f"Loss final: {train_loss:.4f}")
    print(f"Accuracy final: {train_acc:.4f}")


if __name__ == "__main__":
    train()