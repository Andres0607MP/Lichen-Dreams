# Validación funcional del módulo IA

## 1. Objetivo

Comprobar que el flujo completo de inferencia del módulo IA funciona correctamente con un modelo entrenado y dejar evidencia documentada de la validación. Esto incluye verificar que el entrenamiento genera el modelo, que el clasificador puede cargarlo y ejecutar predicciones, y que la salida respeta el contrato definido.

## 2. Dependencias utilizadas

- **TensorFlow/Keras** → Carga y ejecución del modelo. Proporciona las operaciones de entrenamiento (capas, compilación, fit) y de inferencia (load_model, predict).
- **OpenCV (cv2)** → Lectura y procesamiento de imágenes. Se encarga de leer archivos de imagen, convertir espacios de color (BGR a RGB, escala de grises a BGR), redimensionar a 224×224 y normalizar píxeles al rango [0, 1].
- **NumPy** → Manejo de tensores. Convierte listas de imágenes a arrays NumPy, expande dimensiones para el batch y extrae el índice de la clase predicha mediante argmax.
- **Pillow** → Soporte de imágenes. Dependencia del proyecto declarada en `requirements.txt`; no utilizada directamente por el módulo de entrenamiento ni inferencia (que usan OpenCV para el procesamiento de imágenes).

## 3. Entrenamiento del modelo

- **Comando ejecutado:** `py -3.12 backend/ia/entrenamiento/train_model.py`
  - Se utilizó Python 3.12 en lugar de Python 3.14 porque TensorFlow 2.21.0 no admite Python 3.14.
- **Dataset utilizado:** `backend/ia/datasets/`
- **Cantidad de imágenes:** 13 imágenes en total
  - `liquenes_saludables`: 5 imágenes (liquen_001.png a liquen_005.png)
  - `liquenes_contaminados`: 2 imágenes (liquen_001.png, liquen_002.png)
  - `liquenes_desconocidos`: 6 imágenes (liquen_001.jpg a liquen_006.png)
- **Categorías entrenadas:** 3
  - `liquenes_saludables` → clase 0
  - `liquenes_contaminados` → clase 1
  - `liquenes_desconocidos` → clase 2
- **Arquitectura utilizada:** Red neuronal convolucional (CNN) secuencial
  - Capa de entrada: 224×224×3
  - Conv2D(32, 3×3) + BatchNormalization + MaxPooling2D + Dropout(0.25)
  - Conv2D(64, 3×3) + BatchNormalization + MaxPooling2D + Dropout(0.25)
  - Conv2D(128, 3×3) + BatchNormalization + MaxPooling2D + Dropout(0.25)
  - Flatten → Dense(128, relu) + Dropout(0.5) → Dense(3, softmax)
  - Total de parámetros: 12,939,715 (~49.36 MB)
  - Optimizador: Adam (learning_rate=0.001)
  - Función de pérdida: sparse_categorical_crossentropy
  - Métrica: accuracy
  - Epochs: 10, Batch size: 4, Validation split: 0.2
- **Ubicación del modelo generado:** `backend/ia/modelos/lichen_model.keras`

## 4. Validación del clasificador

### Cómo se cargó el modelo

El modelo se carga mediante el mecanismo de **lazy loading** implementado en `backend/ia/modelos/lichen_classifier.py`. La función `_load_model()` verifica si la variable global `_model` es `None`; si lo es, carga el modelo desde disco usando `tf.keras.models.load_model()` y lo almacena en caché. En llamadas posteriores, devuelve la misma instancia sin recargar.

### Cómo funciona predict()

La función `predict(image_path: str) -> dict` realiza los siguientes pasos:

1. Llama a `_load_model()` para obtener el modelo (con lazy loading).
2. Llama a `_preprocess_image(image_path)` que:
   - Lee la imagen con OpenCV (`cv2.imread` con `IMREAD_UNCHANGED`).
   - Convierte el espacio de color según los canales (grayscale → BGR, RGBA → RGB, BGR → RGB).
   - Redimensiona a 224×224.
   - Normaliza los píxeles a [0, 1] como `float32`.
   - Añade una dimensión de batch con `np.expand_dims`.
3. Ejecuta `model.predict(tensor, verbose=0)` para obtener las probabilidades de cada clase.
4. Selecciona la clase con mayor probabilidad mediante `np.argmax`.
5. Construye y devuelve el diccionario de resultado.

### Cómo se procesa la imagen

La imagen se lee desde la ruta proporcionada, se convierte a RGB (3 canales), se redimensiona a 224×224 píxeles, se normaliza dividiendo por 255.0, y se expande a forma `(1, 224, 224, 3)` para alimentar el modelo como un batch de una sola imagen.

### Qué salida entrega

La función `predict()` devuelve un diccionario con las siguientes claves:

| Clave | Tipo | Descripción |
|-------|------|-------------|
| `categoria` | `str` | Nombre de la categoría predicha (ej: "liquen saludable") |
| `confianza` | `float` | Probabilidad de la clase predicha (0.0 a 1.0) |
| `nombre_especie` | `None` | Siempre `None` en la versión actual |
| `nivel_contaminacion` | `str` | Nivel de contaminación derivado de la categoría ("baja", "alta", "desconocida") |
| `calidad_aire` | `str` | Calidad del aire derivada de la categoría ("buena", "mala", "desconocida") |

## 5. Resultado de prueba real

### Imagen utilizada

`backend/ia/datasets/liquenes_saludables/liquen_001.png`

### Resultado obtenido

```json
{
    "categoria": "liquen saludable",
    "confianza": 1.0,
    "nombre_especie": null,
    "nivel_contaminacion": "baja",
    "calidad_aire": "buena"
}
```

### Confianza

1.0 (100%)

### Interpretación del resultado

El modelo clasificó la imagen como "liquen saludable" con confianza máxima. Esto es consistente con el hecho de que la imagen pertenece a la categoría `liquenes_saludables` en el dataset. Se realizaron pruebas adicionales con imágenes de las tres categorías; el modelo predijo todas las imágenes como "liquen saludable" con confianza del 100%, lo cual indica sobreajuste (overfitting) debido al tamaño reducido del dataset (13 imágenes). A pesar de esto, el flujo de inferencia funciona correctamente y el contrato de salida se respeta en todos los casos.

### Tiempo de inferencia

- Primera inferencia (con carga del modelo): ~5.4 segundos
- Inferencias subsiguientes (modelo en caché): ~0.08–0.25 segundos

## 6. Cumplimiento de requisitos

| Requisito | Estado | Evidencia |
|-----------|--------|-----------|
| Modelo entrenado | ✅ | `train_model.py` ejecutado correctamente, 10 epochs completados |
| Archivo .keras generado | ✅ | `backend/ia/modelos/lichen_model.keras` (155 MB) |
| predict() funcional | ✅ | Prueba realizada con 6 imágenes del dataset, todas devolvieron resultado válido |
| Preprocesamiento correcto | ✅ | Imágenes leídas, redimensionadas a 224×224, normalizadas y expandidas a batch |
| Contrato de salida respetado | ✅ | Todas las claves del diccionario presentes con tipos correctos (str, float, None, str, str) |

## 7. Riesgos o limitaciones

- **Tamaño del dataset:** Solo 13 imágenes (5 saludables, 2 contaminados, 6 desconocidos). Es un dataset extremadamente pequeño para entrenar una CNN de ~13M de parámetros, lo que provoca sobreajuste.
- **Posibles problemas de generalización:** El modelo predice todas las imágenes como "liquen saludable" con 100% de confianza, incluyendo imágenes de las categorías contaminada y desconocida. Esto indica que el modelo no ha aprendido a distinguir entre las tres clases de forma significativa. Se requiere un dataset mucho más amplio y equilibrado para obtener un modelo funcional en producción.
- **Dependencias necesarias:**
  - Python 3.12 (TensorFlow no admite Python 3.14)
  - TensorFlow 2.21.0
  - OpenCV 5.0.0.93
  - NumPy 2.5.1
  - Pillow 12.3.0 (declarado en requirements.txt; instalado para Python 3.14, no para Python 3.12 que se usa para entrenamiento/inferencia)
- **GPU:** La validación se ejecutó utilizando CPU. No se configuró aceleración GPU en este entorno.