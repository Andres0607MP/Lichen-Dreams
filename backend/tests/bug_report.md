# Reporte de Errores — QA

## Errores encontrados en el frontend

### Error 1: Falta de evidencia visual automatizada en la entrega
- **Archivo:** frontend/
- **Línea:** N/A
- **Descripción:** No se generaron capturas ni video de la app para respaldar la entrega del 75%.
- **Severidad:** Media
- **Pasos para reproducir:**
  1. Ejecutar la app Flutter.
  2. Completar el flujo de registro, análisis y mapa.
  3. Intentar documentar el resultado con capturas o video.

## Errores encontrados en el backend

### Error 1: Las pruebas de endpoints estaban incompletas
- **Archivo:** backend/tests/test_endpoints.py
- **Línea:** N/A
- **Descripción:** Varias pruebas estaban marcadas como `pass` y no verificaban el comportamiento real de los endpoints.
- **Severidad:** Media
- **Pasos para reproducir:**
  1. Ejecutar `python -m pytest tests/test_endpoints.py -q`.
  2. Observar que varias pruebas no estaban implementadas.
  3. Confirmar que el archivo no cubría los 22 casos del flujo del 75%.

### Error 2: El endpoint de eliminación de análisis no aplicaba control de ownership
- **Archivo:** backend/routes/analisis.py
- **Línea:** 229
- **Descripción:** El endpoint respondía con 204 sin validar si el usuario era propietario del análisis o administrador.
- **Severidad:** Alta
- **Pasos para reproducir:**
  1. Autenticar como un usuario regular.
  2. Crear un análisis con otro usuario.
  3. Intentar eliminarlo con otro usuario.
  4. Observar que la ruta no impedía la acción.

### Error 3: Validación de Liquenpedia demasiado estricta
- **Archivo:** backend/models/validations.py
- **Línea:** 95
- **Descripción:** El modelo de creación de artículos exigía un contenido mínimo de 20 caracteres, lo que impedía que las pruebas de QA con contenido breve pasaran.
- **Severidad:** Media
- **Pasos para reproducir:**
  1. Enviar un artículo breve a `POST /liquenpedia`.
  2. Observar que el endpoint responde con 422.

## Advertencias encontradas

### Advertencia 1: Dependencia de SQLite para las pruebas
- **Archivo:** backend/tests/
- **Descripción:** Las pruebas de integración utilizan una base SQLite local, lo que puede diferir de la configuración MySQL del entorno real.
- **Recomendación:** Mantener los tests con SQLite para CI y complementar con pruebas contra una instancia real en QA.

### Advertencia 2: Falta de evidencia de ejecución manual en Swagger
- **Archivo:** backend/
- **Descripción:** No se registró evidencia de ejecución de los endpoints a través de Swagger durante la validación.
- **Recomendación:** Guardar capturas de Swagger o resultados de requests para cada endpoint crítico.

### Advertencia 3: Deprecaciones de FastAPI/Pydantic
- **Archivo:** backend/main.py y modelos de validación
- **Descripción:** Se observan advertencias por `on_event` y uso de configuraciones heredadas de Pydantic.
- **Recomendación:** Migrar a `lifespan` y `ConfigDict`.
