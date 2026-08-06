# Reporte de Errores — QA

## Estado actual de la rama qa

- **Pruebas de endpoints:** 22/22 pruebas pasando en `backend/tests/test_endpoints.py`.
- **Prueba E2E:** Flujo completo funcionando en `backend/tests/test_e2e_flow.py`.
- **Evidencias generadas:** Resultados de pruebas documentados en `evidencias/`.
- **Errores pendientes:** Se detallan en la sección inferior.

---

## Errores encontrados en el frontend

### Error 1: Asset faltante impide ejecutar `flutter test`
- **Archivo:** frontend/pubspec.yaml
- **Línea:** N/A
- **Descripción:** El asset `assets/background/fondo.png` está declarado en `pubspec.yaml` pero no existe en el repositorio. Esto impide ejecutar `flutter test` y generar `flutter-test-results.txt`.
- **Severidad:** Media
- **Pasos para reproducir:**
  1. Ejecutar `cd frontend && flutter test`.
  2. Observar el error: `No file or variants found for asset: assets/background/fondo.png`.
- **Recomendación:** Agregar el asset faltante o eliminar la referencia en `pubspec.yaml`.

---

## Errores encontrados en el backend

### Error 1: Ninguno actualmente
- Las pruebas de endpoints y el flujo E2E funcionan correctamente.
- El control de ownership en eliminación de análisis está implementado y validado.

---

## Advertencias encontradas

### Advertencia 1: Dependencia de SQLite para las pruebas
- **Archivo:** backend/tests/
- **Descripción:** Las pruebas de integración utilizan una base SQLite local, lo que puede diferir de la configuración MySQL del entorno real.
- **Recomendación:** Mantener los tests con SQLite para CI y complementar con pruebas contra una instancia real en QA.

### Advertencia 2: Deprecaciones de FastAPI/Pydantic
- **Archivo:** backend/main.py y modelos de validación
- **Descripción:** Se observan advertencias por `on_event` y uso de configuraciones heredadas de Pydantic (`class Config`).
- **Recomendación:** Migrar a `lifespan` y `ConfigDict` en una futura iteración.

---

## Problemas pendientes de otras áreas (no bloquean QA)

1. **Evidencias visuales pendientes:** Las capturas de pantalla y video/GIF del flujo completo deben ser generadas manualmente y agregadas en `evidencias/capturas/`.
2. **Resultados de Flutter tests pendientes:** `flutter test` no se pudo ejecutar por el asset faltante. Una vez resuelto, guardar la salida en `evidencias/flutter-test-results.txt`.
