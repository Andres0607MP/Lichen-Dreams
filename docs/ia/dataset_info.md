# Organización del Dataset IA

## Estructura de Carpetas

```
backend/ia/
├── datasets/
│   ├── liquenes_saludables/
│   ├── liquenes_contaminados/
│   └── liquenes_desconocidos/
├── modelos/
├── entrenamiento/
```

## Fuentes Utilizadas
- https://github.com/elisefeld/lichen_classifier
- https://github.com/ciaranframe/arctic-lichen

## Cantidad de Imágenes
- liquenes_saludables: 5
- liquenes_contaminados: 2
- liquenes_desconocidos: 6

## Formato de Imágenes
- JPG, PNG

## Observaciones
- Las carpetas están organizadas y contienen imágenes de ejemplo clasificadas por categoría.
- Los nombres siguen la convención liquen_001.jpg, liquen_002.png, etc.
- El script leer_imagen.py permite probar la lectura de imágenes con OpenCV.
- Se recomienda no subir grandes volúmenes de imágenes al repositorio, solo ejemplos representativos.
