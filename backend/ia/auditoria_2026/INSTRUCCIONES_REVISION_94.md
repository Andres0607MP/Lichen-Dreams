# INSTRUCCIONES DE REVISIÓN — 94 IMÁGENES CRÍTICAS

Acompaña a `revision_94_criticas.csv`. Objetivo: decidir **visualmente** si estas 94 imágenes tienen la etiqueta correcta. Las columnas `decision_humana` y `observaciones` están vacías a propósito; rellénalas manualmente.

## 1. Qué contiene la lista

| Prioridad | Clase actual | Sugerencia estadística | Cantidad |
|---|---|---|---|
| CRÍTICO | saludable | probablemente contaminado | 49 |
| ALTO | contaminado | sospechosamente saludable | 45 |

Dentro de cada prioridad las imágenes están ordenadas por confianza estadística (descendente) y luego por nombre de archivo. La confianza es evidencia automática (HSV, textura, vecinos cercanos), **no una decisión**.

Nota: 4 de las 45 de ALTO son `lcp_aug_*` (variantes aumentadas de los 14 `lcp_*`). Están al final porque su revisión es de menor urgencia: solo se usan en train y no aportan diversidad biológica nueva.

## 2. Cómo revisar cada imagen (regla visual y semántica)

NO uses la regla `verde = saludable, café = contaminado`. Usa estas preguntas.

### Imagen actualmente en `saludables` (49 CRÍTICO)

Abre la imagen. Pregúntate:

- **¿Visualmente parece un liquen?**
  - No parece ser un liquen (corteza pelada, suelo, objeto) → `decision_humana = desconocido`.
- **¿El liquen se ve sano/vivo/natural?**
  - Sí (verde, verde azulado, grisáceo, amarillento, incluso con variaciones de color, pero lúcido y sin deterioro claro) → `decision_humana = saludable`.
  - No: presenta manchas cafés/marrones, zonas podridas, sequedad o deterioro **dentro del liquen** → `decision_humana = contaminado`.
- **¿El marrón pertenece al liquen o al sustrato/fondo?**
  - El marrón es principalmente corteza, madera, tierra o piedras del fondo y el liquen en sí se ve sano → **mantener `saludable`**. El color del fondo NO es contaminación.
- **No estoy seguro** → `decision_humana = dudoso`.

### Imagen actualmente en `contaminados` (45 ALTO)

- **¿Visualmente parece un liquen?**
  - No parece ser un liquen → `decision_humana = desconocido`.
- **¿El liquen se ve realmente deteriorado/contaminado?**
  - Sí: manchas cafés, zonas podridas, aspecto seco, pérdida importante de coloración saludable, textura de deterioro visible en el liquen → **mantener `contaminado`**.
  - No: se ve como un liquen sano con coloración natural (verde, verde azulado, aguamarina) sin señales claras de deterioro → `decision_humana = saludable`.
- **¿El marrón pertenece al liquen o al fondo?**
  - El "café" es sustrato (corteza, tierra, madera, sombras) y el liquen se ve sano → considerar `saludable`. El marrón del fondo NO convierte el liquen en contaminado.
  - Solo si el deterioro está realmente sobre el liquen → mantener `contaminado`.
- **No estoy seguro** → `decision_humana = dudoso`.

## 3. Valores permitidos para `decision_humana`

- `saludable`
- `contaminado`
- `desconocido`
- `dudoso`

`observaciones` (opcional): texto libre, p. ej. "el marrón parece del liquen", "liquen gris sano sobre corteza", "parece foto oscura, revisar de nuevo".

## 4. Reglas firmes

- No cambiar la etiqueta del dataset con esta revisión; el CSV es solo el registro de decisión.
- La decisión es visual y del criterio de la definición del proyecto, no del umbral estadístico.
- Después de revisar, llevar las decisiones acordadas a una fase aparte de propuesta de cambios de etiquetas.