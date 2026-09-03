# PIPELINE V7 — Preparación definitiva del dataset y entrenamiento

Este documento describe el pipeline preparado para entrenar el **modelo V7** de
clasificación de líquenes de Lichen Dreams. **En esta fase NO se entrena nada**:
aquí se documenta y valida el split, el manifest, el pipeline reproducible y las
reglas de evaluación para que la siguiente orden sea simplemente **ENTRENAR V7**.

---

## 1. Dataset utilizado

```
backend/ia/datasets/
├── liquenes_saludables/       500 imágenes
├── liquenes_contaminados/     500 imágenes
│     ├── lc_*      326 originales
│     ├── lcp_*      14 prioritarios
│     └── lcp_aug_* 160 aumentadas (variantes de los 14 lcp_*)
└── liquenes_desconocidos/    1159 imágenes (30 subcategorías internas)
```

## 2. Clases

| class_id | class_name | Etiqueta visual |
|---|---|---|
| 0 | saludable | Liquen sano/vivo; variedad de colores (verde, verde azulado, aguamarina, gris verdoso, gris). |
| 1 | contaminado | Deterioro del PROPIO liquen: manchas cafés, zonas podridas, sequedad, pérdida del aspecto sano. El café del sustrato NO cuenta. |
| 2 | desconocido | Todo lo que no es claramente un liquen. Las subcarpetas internas siguen siendo UNA sola clase. |

**Regla semántica**: no usar `verde = saludable` ni `gris = contaminado`. La
decisión depende del aspecto general del liquen y de si el deterioro pertenece
al liquen o al fondo/sustrato.

## 3. Conteos

```
saludable     500
contaminado   500
desconocido  1159
total        2159
```

## 4. Regla de leakage

Ninguna imagen derivada de un mismo original puede estar en más de un split:

```
familia/original -> un solo split
```

Nunca `original -> train` con `augmented -> val/test`.

## 5. Regla lcp / lcp_aug

`lcp_aug_*` son variantes generadas a partir de los 14 `lcp_*`. Como el script
de aumentación no registró el padre exacto (`random.choice(lcp)` sin trazabilidad),
la garantía fuerte es agrupar **TODA la familia `lcp_*` + `lcp_aug_*` en TRAIN**:

- `group_id = "lcp_family"` para los 174 archivos de la familia.
- Los 160 `lcp_aug_*` SOLO en TRAIN.
- Nunca en validation, nunca en test.
- TEST de contaminados usa únicamente originales `lc_*`.

## 6. Train / validation / test (manifest)

| split | sal | cont | desc | total |
|---|---|---|---|---|
| train | 350 | 402 | 824 | 1576 |
| val | 75 | 49 | 166 | 290 |
| test | 75 | 49 | 169 | 293 |
| **Total** | 500 | 500 | 1159 | **2159** |

La proporción es **aprox. 70 / 15 / 15**: se prioriza la ausencia de leakage y
la representación de todas las clases por encima de porcentajes exactos.

Los desconocidos se dividen por **subcarpeta entera**: cada categoría temática
va a un único split, para no repartir categorías visuales entre splits.

## 7. Seed

Fija en el script y en todos los comandos:

```
seed = 42
```

Documentada además en el manifest (`dataset_v7_manifest.csv` es reproducible:
`build_manifest(42)` siempre produce el mismo resultado; test incluido).

## 8. Preprocesamiento

```
input shape : 224 x 224
color       : RGB
normalize   : /255.0 al leer; el backbone recibe [-1, 1] vía capa Rescaling
              DENTRO del modelo (idéntico a V6), de modo que la inferencia
              del backend (/255) coincide con el entrenamiento.
```

## 9. Augmentation (SOLO train)

- Batches equilibrados ~1/3 por clase (sampling en memoria, no toca el dataset).
- No se aplica augmentación geométrica agresiva al dataset físico.
- No se crean transformaciones que cambien la identidad del liquen (sin manchas
  marrones artificiales, sin distorsiones extremas).
- Val/test se sirven sin ninguna transformación.

## 10. Métricas

- **Principal**: `macro F1` (checkpoint por `val_macro_f1`, no accuracy).
- Acompañantes: `balanced accuracy`, `precision/recall macro`, recalls por
  clase, `confusion matrix`.
- Se registra por época: accuracy, loss, macro F1, balanced accuracy, recall
  saludable/contaminado/desconocido y la **distribución de predicciones** para
  detectar class collapse.

### Control de class collapse

El callback V7 registra y avisa si:
- una clase predomina > 90% de las predicciones de validation en épocas ≥ 4, o
- una clase tiene recall 0 y F1 0 en épocas ≥ 6.

Estas advertencias quedan en `training_history_v7.json` (`collapse_warn`).
El entrenamiento no se elige por accuracy.

## 11. Cómo generar el split

```bash
cd backend
python ia/entrenamiento/create_split_v7.py            # genera y valida el manifest
python ia/entrenamiento/create_split_v7.py --check    # solo valida el existente
python ia/entrenamiento/create_split_v7.py --seed 42  # semilla distinta (documentar)
```

Salida: `backend/ia/entrenamiento/dataset_v7_manifest.csv`
(columnas: filename, filepath, class_id, class_name, split, group_id,
is_augmented, source_original).

## 12. Cómo validar el split

```bash
python ia/entrenamiento/create_split_v7.py --check
python -m pytest tests/test_v7_split_pipeline.py -q
```

Validaciones automáticas (dentro de `create_split_v7.py` y el test):
- conteos 500 / 500 / 1159 / total 2159
- sin archivos duplicados, sin archivos inexistentes
- todas las imágenes pertenecen a una clase (0/1/2) y a exactamente un split
- `group_id ∩ split`: cada familia en un único split
- familia `lcp_family` completa en train
- `lcp_aug_*` solo en train
- test sin aumentadas y sin `lcp_*`

## 13. Cómo ejecutar el entrenamiento (FASE POSTERIOR)

```bash
cd backend
python ia/entrenamiento/train_model_v7.py
```

Parámetros configurables (todos con default):

```bash
python ia/entrenamiento/train_model_v7.py \
    --seed 42 \
    --manifest ia/entrenamiento/dataset_v7_manifest.csv \
    --epochs-phase1 10 \
    --epochs-phase2 12 \
    --batch 24 \
    --lr1 1e-3 \
    --lr2 1e-4 \
    --image-size 224 \
    --arch efficientnetb1 \
    --out-dir ia/entrenamiento/reportes
```

No hay rutas absolutas hardcodeadas. Arquitectura: transfer learning 2 fases
(backbone congelado → fine-tune últimas 40 capas), con fallback automático
EfficientNetB1 → B2 → MobileNetV3 → MobileNetV2 si faltan pesos.

## 14. Cómo evaluar V7

El pipeline genera automáticamente:

```
backend/ia/entrenamiento/reportes/
├── metrics_v7.json                (accuracy, macro F1, balanced acc, cm, por clase)
├── confusion_matrix_v7.png
├── classification_report_v7.json
├── training_history_v7.json       (por época, con collapse_warn)
├── comparison_v3_v7.json
```

`metrics_v7.json` incluye `accuracy`, `precision_macro`, `recall_macro`,
`f1_macro`, `balanced_accuracy`, `per_class` y `split`.

## 15. Cómo comparar V7 contra V3

`comparison_v3_v7.json` compara en: accuracy, macro F1, balanced accuracy y
recalls de cada clase. Los datos de V3 provienen de
`reportes/metrics_v3.json` (V3 actual: F1 macro ≈ 0.2406).

Para localizar modelos sin riesgo de fallback silencioso existe
`ia/resolver_modelo_activo.py` (resuelve SOLO lo registrado como activo en BD,
y lanza `ActiveModelError` si no puede).

## 16. Criterios para que V7 pueda reemplazar a V3

V7 **no se convierte automáticamente en activo**. Solo podrá proponerse si:

1. `f1_macro` de test supera claramente a V3 (0.2406), y
2. `balanced_accuracy` supera/mejora a la de V3, y
3. no presenta class collapse (distribución de predicciones repartida; recalls
   de todas las clases > 0), y
4. contrato del backend intacto (0/1/2, resolución dinámica del activo).

Tras aprobación se registra (pendiente migración de activación):

```bash
python ia/registrar_modelo_v7.py            # registra inactivo
python ia/registrar_modelo_v7.py --activate # activo tras aprobación explícita
```

## 17. Registro en MySQL

Preparado pero **NO ejecutado** en esta fase (V7 no está entrenado). El script
`ia/registrar_modelo_v7.py` valida con `resolver_modelo_activo` que el activo
sigue siendo resolubile antes de tocar nada, y por defecto registra en estado
`inactivo`.

## 18. Integración con backend

- Mapping mantenido: `0 = saludable, 1 = contaminado, 2 = desconocido`.
- El backend (via `ia/modelos/lichen_classifier.py`) sigue resolviendo el
  modelo activo dinámicamente desde la BD; **no se rompe esa resolución**.
- `ia/resolver_modelo_activo.py` es la referencia estricta para validar
  registros sin fallback silencioso (`ActiveModelError` si no hay activo válido).

## 19. No hacer nada más en esta fase

- No entrenar V7.
- No registrar modelos.
- No modificar el dataset (nada se movió/borró/renombró).
- V3 sigue activo; V6 sigue inactivo.