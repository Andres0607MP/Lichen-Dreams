# REVISOR 94 — Curación manual de etiquetas críticas

Herramienta **local** para revisar visualmente, una por una, las 94 imágenes
críticas detectadas en la auditoría estadística de etiquetas del dataset de
Lichen Dreams.

**No es un clasificador.** La decisión final es humana. La herramienta solo
muestra la imagen y guarda lo que la persona decida.

---

## ¿Qué hace?

- Lee `revision_94_criticas.csv` (94 imágenes críticas).
- Sirve las imágenes originales **en modo solo lectura** desde el dataset.
- Muestra, para cada imagen, la clase actual, la sugerencia estadística por
  separado, el motivo, la prioridad y la confianza.
- Permite elegir una decisión humana y escribir observaciones.
- Guarda **inmediatamente** cada decisión en `revision_94_resultados.csv`.
- No modifica ni una sola imagen ni ninguna carpeta del dataset.

## Orden de revisión (prioridad)

| Grupo | Contenido | Imágenes |
|---|---|---|
| P1 | `liquenes_saludables` sospechosos de contaminados | 49 |
| P2 | `lc_*` sospechosos de saludables | 40 |
| P3 | `lcp_*` sospechosa | 1 |
| P4 | `lcp_aug_*` (variantes aumentadas) | 4 |

Las `lcp_aug_*` están marcadas en la interfaz como
**AUMENTADA — NO REPRESENTA NUEVA DIVERSIDAD BIOLÓGICA**. Cualquier decisión
sobre ellas debe basarse en su imagen fuente/original, y no suman como
ejemplos biológicos independientes.

## Cómo ejecutarla

Desde `backend/`:

```bash
python ia/auditoria_2026/revisor_94.py
```

Opciones:

```bash
python ia/auditoria_2026/revisor_94.py --check          # valida estructura y sale
python ia/auditoria_2026/revisor_94.py --port 8700      # puerto distinto
python ia/auditoria_2026/revisor_94.py --no-browser     # sin abrir navegador
```

Funciona en Windows y Linux con **solo la biblioteca estándar de Python**
(sin dependencias adicionales). Requiere Python 3.8+.

Al arrancar:
1. Valida que haya exactamente 94 filas, sin duplicados y con todas las
   imágenes existentes.
2. Levanta un servidor local en `http://127.0.0.1:8765`.
3. Abre el navegador automáticamente.

## Navegación

- Botones `« ‹ › »` o flechas del teclado (←/→) para moverse.
- Rejilla superior con el número de cada imagen: 1 clic para saltar.
- El recuadro se pinta verde cuando esa imagen ya tiene decisión.

## Decisiones humanas

Opciones posibles (exactamente estas):

- `mantener` — la etiqueta actual es correcta.
- `cambiar_a_saludable` — la imagen parece un liquen sano.
- `cambiar_a_contaminado` — la imagen parece un liquen deteriorado.
- `cambiar_a_desconocido` — la imagen no parece un liquen.
- `dudoso` — no se puede decidir con confianza.

El campo `observaciones` guarda el motivo escrito a mano.

## Definiciones del proyecto (para decidir)

### Saludaable (clase 0)
Liquen sano/vivo. Puede tener variedad de colores: verde, verde azulado,
aguamarina, verde grisáceo, gris u otros colores naturales.
**NO** usar `poco verde = contaminado` ni `gris = contaminado`. Lo importante
es que el liquen parezca sano y no presente deterioro evidente.

### Contaminado (clase 1)
Evidencia visual de afectación del **propio liquen**: manchas cafés/marrones,
zonas podridas, aspecto seco, deterioro, pérdida importante del aspecto
saludable, cambios de textura asociados al deterioro.
**MUY IMPORTANTE:** el color café del **fondo** (corteza, madera, tierra,
piedras) NO cuenta. La pregunta central es:
**¿la mancha/deterioro pertenece al liquen o al sustrato?**

### Desconocido (clase 2)
Cuando no parece ser un liquen: objetos, animales, plantas sin liquen, madera
sin liquen, corteza sin liquen, suelo, piedra, edificios, etc.
Las subcategorías de la carpeta `liquenes_desconocidos` son solo organización
interna; **no** son clases nuevas. Para entrenamiento sigue siendo una sola
clase `desconocido`.

## Aviso importante

La `confianza_estadística` y la `sugerencia_estadística` son **orientación
automática** (HSV, textura, vecinos cercanos). Aunque una fila indique
`confianza 0.9`, la decisión NO debe preseleccionarse: la persona observa la
imagen y decide.

## Dónde se guardan las decisiones

`backend/ia/auditoria_2026/revision_94_resultados.csv`

Conserva toda la información original de `revision_94_criticas.csv` y añade:

- `decision_humana`
- `observaciones`
- `revisado` (`si` si hay decisión)
- `fecha_revision` (se usa para conservar la fecha de la última edición)

El archivo se reescribe con cada guardado. No se edita `revision_94_criticas.csv`.

## Seguridad del dataset

- Las imágenes se abren en modo lectura (`rb`).
- No existen botones para mover, borrar, renombrar ni modificar imágenes.
- El único archivo que la herramienta escribe es `revision_94_resultados.csv`,
  dentro de `backend/ia/auditoria_2026/`.
- `liquenes_saludables/`, `liquenes_contaminados/` y `liquenes_desconocidos/`
  quedan intactos.

## Después de la revisión

Cuando las 94 imágenes estén revisadas, `revision_94_resultados.csv` se usará
en una fase posterior para decidir qué imágenes se mueven entre clases y cómo
rebalancear el dataset. Esta herramienta no hace esa reasignación.