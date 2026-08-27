import os
import shutil
from pathlib import Path

import cv2
import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
DATASET_DIR = PROJECT_ROOT / "ia" / "datasets"
MODEL_DIR = PROJECT_ROOT / "ia" / "modelos"
MODEL_FILENAME = "lichen_model.keras"
MODEL_PATH = MODEL_DIR / MODEL_FILENAME
REPORTS_DIR = PROJECT_ROOT / "ia" / "reports"
INPUT_SIZE = (224, 224)
NUM_CLASSES = 3
BATCH_SIZE = 8
EPOCHS = 40
LEARNING_RATE = 0.001

LABEL_MAP = {
    "liquenes_saludables": 0,
    "liquenes_contaminados": 1,
    "liquenes_desconocidos": 2,
}

CLASS_NAMES = ["liquen saludable", "liquen contaminado", "liquen desconocido"]

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


def get_data_augmentation():
    data_augmentation = tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal"),
        tf.keras.layers.RandomRotation(0.1),
        tf.keras.layers.RandomZoom(0.1),
        tf.keras.layers.RandomContrast(0.1),
    ])
    return data_augmentation


def plot_training_history(history):
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))

    ax1.plot(history.history['loss'], label='Train Loss')
    ax1.plot(history.history['val_loss'], label='Val Loss')
    ax1.set_title('Loss')
    ax1.set_xlabel('Epoch')
    ax1.set_ylabel('Loss')
    ax1.legend()

    ax2.plot(history.history['accuracy'], label='Train Accuracy')
    ax2.plot(history.history['val_accuracy'], label='Val Accuracy')
    ax2.set_title('Accuracy')
    ax2.set_xlabel('Epoch')
    ax2.set_ylabel('Accuracy')
    ax2.legend()

    plt.tight_layout()
    plt.savefig(REPORTS_DIR / 'training_history.png', dpi=150)
    plt.close()
    print(f"Gráfica de entrenamiento guardada en: {REPORTS_DIR / 'training_history.png'}")


def plot_confusion_matrix(y_true, y_pred):
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    cm = confusion_matrix(y_true, y_pred)

    fig, ax = plt.subplots(figsize=(8, 6))
    im = ax.imshow(cm, interpolation='nearest', cmap=plt.cm.Blues)
    ax.figure.colorbar(im, ax=ax)

    ax.set(xticks=np.arange(cm.shape[1]),
           yticks=np.arange(cm.shape[0]),
           xticklabels=CLASS_NAMES,
           yticklabels=CLASS_NAMES,
           ylabel='Etiqueta real',
           xlabel='Etiqueta predicha',
           title='Matriz de confusión')

    plt.setp(ax.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")

    thresh = cm.max() / 2.
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            ax.text(j, i, format(cm[i, j], 'd'),
                    ha="center", va="center",
                    color="white" if cm[i, j] > thresh else "black")

    plt.tight_layout()
    plt.savefig(REPORTS_DIR / 'confusion_matrix.png', dpi=150)
    plt.close()
    print(f"Matriz de confusión guardada en: {REPORTS_DIR / 'confusion_matrix.png'}")


def train():
    print("Cargando dataset...")
    x, y = load_dataset()
    print(f"Total de imágenes: {len(x)}")
    print(f"Clases: {LABEL_MAP}")

    for class_name, label in LABEL_MAP.items():
        count = np.sum(y == label)
        print(f"  {class_name}: {count} imágenes")

    print("\nDividiendo dataset (80% train, 20% val)...")
    x_train, x_val, y_train, y_val = train_test_split(
        x, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"Train: {len(x_train)} imágenes")
    print(f"Val: {len(x_val)} imágenes")

    print("\nConstruyendo modelo...")
    model = build_model()
    model.summary()

    data_augmentation = get_data_augmentation()

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    best_model_path = str(MODEL_DIR / "best_model.keras")
    final_model_path = str(MODEL_PATH)

    class SafeModelCheckpoint(tf.keras.callbacks.Callback):
        def __init__(self, filepath, monitor='val_accuracy', mode='max', verbose=1):
            super().__init__()
            self.filepath = filepath
            self.monitor = monitor
            self.mode = mode
            self.verbose = verbose
            self.best_value = -float('inf') if mode == 'max' else float('inf')
            self.best_epoch = 0

        def on_epoch_end(self, epoch, logs=None):
            logs = logs or {}
            current = logs.get(self.monitor)
            if current is None:
                return

            improved = (self.mode == 'max' and current > self.best_value) or \
                       (self.mode == 'min' and current < self.best_value)

            if improved:
                if self.verbose:
                    print(f"\n  {self.monitor} mejoró: {self.best_value:.4f} -> {current:.4f}. Guardando modelo...")
                self.best_value = current
                self.best_epoch = epoch + 1
                try:
                    self.model.save(self.filepath)
                except Exception as e:
                    print(f"  Error guardando modelo: {e}")

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=7,
            restore_best_weights=True,
            verbose=1
        ),
        SafeModelCheckpoint(
            filepath=best_model_path,
            monitor='val_accuracy',
            mode='max',
            verbose=1
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=3,
            min_lr=1e-6,
            verbose=1
        ),
    ]

    print("\nEntrenando modelo...")
    train_dataset = tf.data.Dataset.from_tensor_slices((x_train, y_train))
    train_dataset = train_dataset.shuffle(buffer_size=len(x_train))
    train_dataset = train_dataset.batch(BATCH_SIZE)
    train_dataset = train_dataset.map(
        lambda x, y: (data_augmentation(x, training=True), y),
        num_parallel_calls=tf.data.AUTOTUNE
    )
    train_dataset = train_dataset.prefetch(tf.data.AUTOTUNE)

    val_dataset = tf.data.Dataset.from_tensor_slices((x_val, y_val))
    val_dataset = val_dataset.batch(BATCH_SIZE)
    val_dataset = val_dataset.prefetch(tf.data.AUTOTUNE)

    history = model.fit(
        train_dataset,
        validation_data=val_dataset,
        epochs=EPOCHS,
        callbacks=callbacks,
        verbose=1,
    )

    print("\nGuardando modelo final...")
    model.save(final_model_path)
    print(f"Modelo final guardado en: {final_model_path}")

    if os.path.exists(best_model_path):
        shutil.copy2(best_model_path, final_model_path)
        print(f"Mejor modelo copiado a: {final_model_path}")
        os.remove(best_model_path)

    plot_training_history(history)

    print("\nEvaluando en conjunto de validación...")
    y_pred_proba = model.predict(x_val, batch_size=BATCH_SIZE)
    y_pred = np.argmax(y_pred_proba, axis=1)

    print("\n" + "="*60)
    print("REPORTE DE CLASIFICACIÓN")
    print("="*60)
    print(classification_report(y_val, y_pred, target_names=CLASS_NAMES, digits=4))

    print("\nMatriz de confusión:")
    cm = confusion_matrix(y_val, y_pred)
    print(cm)

    plot_confusion_matrix(y_val, y_pred)

    val_loss, val_acc = model.evaluate(val_dataset, verbose=0)
    print(f"\nResultado final:")
    print(f"  Val Loss: {val_loss:.4f}")
    print(f"  Val Accuracy: {val_acc:.4f}")

    return model, history, x_val


if __name__ == "__main__":
    model, history, x_val = train()

    print("\n" + "="*60)
    print("VERIFICACIÓN DEL MODELO")
    print("="*60)

    print("\nCargando modelo guardado para verificación...")
    loaded_model = tf.keras.models.load_model(str(MODEL_PATH))
    print(f"Modelo cargado exitosamente desde: {MODEL_PATH}")

    print("\nPrueba de inferencia con imágenes del dataset...")
    test_images = [x_val[0], x_val[len(x_val)//2], x_val[-1]]
    test_images_np = np.array(test_images)
    predictions = loaded_model.predict(test_images_np, verbose=0)

    for i, pred in enumerate(predictions):
        class_idx = np.argmax(pred)
        confidence = pred[class_idx]
        print(f"  Imagen {i+1}: {CLASS_NAMES[class_idx]} (confianza: {confidence:.4f})")

    print("\n¡Entrenamiento completado exitosamente!")