# Investigación Inicial de IA y CNN para Lichen Dreams

## Tecnologías Investigadas

### TensorFlow
**¿Qué es?**  
TensorFlow es una biblioteca de código abierto desarrollada por Google para el aprendizaje automático y el desarrollo de redes neuronales profundas. Permite construir, entrenar y desplegar modelos de machine learning de manera eficiente.

**¿Para qué sirve?**  
Se utiliza para tareas de clasificación, regresión, procesamiento de imágenes, procesamiento de lenguaje natural, reconocimiento de voz, entre otros. Es ampliamente usado en proyectos de visión artificial y deep learning.

**Ventajas y desventajas**  
Ventajas:
- Gran comunidad y documentación.
- Soporte para CPU, GPU y TPU.
- Escalabilidad y facilidad de producción.
- Integración con otras herramientas (Keras, TFLite, TensorBoard).
Desventajas:
- Curva de aprendizaje inicial moderada.
- Puede ser complejo para proyectos pequeños.

**Uso en visión artificial**  
TensorFlow es ideal para tareas de visión artificial como clasificación de imágenes, detección de objetos y segmentación. Permite entrenar modelos CNN y exportarlos a dispositivos móviles.

**Compatibilidad con Python**  
TensorFlow es compatible principalmente con Python, aunque existen APIs para otros lenguajes. La mayoría de los recursos y ejemplos están en Python.

### Keras
**¿Qué es?**  
Keras es una biblioteca de alto nivel para construir y entrenar redes neuronales de manera sencilla e intuitiva. Inicialmente era independiente, pero ahora está integrada oficialmente en TensorFlow.

**Relación con TensorFlow**  
Keras es la API oficial de alto nivel de TensorFlow. Permite definir modelos de deep learning con pocas líneas de código y abstrae detalles complejos del backend.

**Facilidad de uso**  
Keras destaca por su simplicidad, legibilidad y modularidad. Es ideal para prototipado rápido y proyectos educativos.

**Ejemplo de importación**
```python
from tensorflow import keras
```

### OpenCV
**Procesamiento y lectura de imágenes**  
OpenCV (Open Source Computer Vision Library) es una biblioteca de visión artificial muy utilizada para procesamiento de imágenes, análisis de video y manipulación de datos visuales.

Permite leer, modificar, analizar y guardar imágenes y videos en múltiples formatos. Es útil para preprocesar datos antes de alimentar modelos de IA.

**Ejemplo de uso**
```python
import cv2

imagen = cv2.imread("liquen.jpg")
print(imagen.shape)
```

### Modelos CNN
**Conceptos básicos**  
Las redes neuronales convolucionales (CNN) son un tipo de red especializada en el procesamiento de datos con estructura de grilla, como imágenes. Utilizan capas convolucionales para extraer características espaciales y patrones visuales.

Componentes principales:
- Capas convolucionales
- Capas de activación (ReLU)
- Capas de pooling
- Capas completamente conectadas

**Ejemplos de arquitecturas populares:**
- **MobileNet:** Ligera y eficiente, ideal para dispositivos móviles.
- **ResNet:** Introduce conexiones residuales, permitiendo redes muy profundas.
- **EfficientNet:** Optimiza el rendimiento y la eficiencia de parámetros.

## Datasets Encontrados

### Ejemplo 1: Lichen Species Image Dataset (Kaggle)
- **Enlace:** https://www.kaggle.com/datasets/andrewmvd/lichen-species-images
- **Tamaño:** ~1,000 imágenes
- **Licencia:** Creative Commons
- **Observaciones:** Imágenes clasificadas por especie de líquenes. Útil para entrenamiento y pruebas.

### Ejemplo 2: Lichen Bioindicator Dataset
- **Enlace:** https://data.mendeley.com/datasets/7y2k4b6b8c/1
- **Tamaño:** ~500 imágenes
- **Licencia:** Open Data
- **Observaciones:** Imágenes de líquenes en diferentes ambientes, útil para clasificación y análisis ambiental.

### Ejemplo 3: PlantCLEF 2022 (incluye líquenes)
- **Enlace:** https://www.imageclef.org/lifeclef/2022/plant
- **Tamaño:** >100,000 imágenes (varias especies)
- **Licencia:** Requiere registro, uso académico
- **Observaciones:** Gran variedad de especies, incluye líquenes y plantas relacionadas.

## Conclusiones

**Posibles usos en el proyecto:**
- Utilizar TensorFlow y Keras para construir y entrenar modelos CNN que permitan clasificar imágenes de líquenes.
- Emplear OpenCV para el preprocesamiento y análisis de imágenes antes de alimentar los modelos.
- Aprovechar datasets públicos para entrenamiento inicial y pruebas, adaptando la estructura a las necesidades del proyecto.

**Recomendaciones:**
- Priorizar el uso de TensorFlow + Keras por su integración y facilidad de despliegue.
- Realizar pruebas con modelos ligeros (MobileNet) para prototipos rápidos y migrar a arquitecturas más complejas si es necesario.
- Verificar la calidad y diversidad de los datasets antes de entrenar modelos definitivos.
- Documentar el proceso de preprocesamiento y entrenamiento para futuras iteraciones.

