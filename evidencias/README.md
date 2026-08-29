# Evidencias QA — Lichen Dreams

Esta carpeta contiene las evidencias generadas durante la auditoría QA de la rama `qa`.

## Archivos incluidos

- `test-results.txt` — Resultado de `pytest backend/tests/test_endpoints.py -v`.
- `e2e_results.txt` — Resultado de `pytest backend/tests/test_e2e_flow.py -v`.
- `flutter-test-results.txt` — Resultado de `flutter test`. Actualmente contiene el error por asset faltante; debe regenerarse cuando se resuelva.
- `README.md` — Este archivo.

## Capturas pendientes

Las siguientes capturas deben generarse manualmente durante la ejecución de la app:

- `capturas/pantalla_login.png` — Pantalla de inicio de sesión.
- `capturas/pantalla_resultado.png` — Pantalla de resultado del análisis.
- `capturas/pantalla_mapa.png` — Mapa interactivo con puntos de análisis.
- `capturas/pantalla_historia.png` — Lista del historial de análisis.

## Flujo completo documentado

1. Registro de usuario.
2. Login.
3. Subida de imagen.
4. Procesamiento IA.
5. Resultado del análisis.
6. Guardado de ubicación.
7. Historial.
8. Mapa.

## Video/GIF pendiente

Se debe agregar un video o GIF corto (`flujo_completo.mp4` o `flujo_completo.gif`) mostrando el flujo completo de la aplicación.
