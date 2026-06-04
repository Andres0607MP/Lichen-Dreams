# Conexión Frontend ↔ Backend

## Objetivo
Validar la comunicación inicial entre Flutter y FastAPI.

## Base URL
- Emulador Android: `http://10.0.2.2:8000`
- Override por `--dart-define=API_BASE_URL=...`

## Archivos creados
- `frontend/lib/config/app_config.dart`
- `frontend/lib/services/api_service.dart`

## Endpoint de prueba
- `GET /api/test`
- fallback: `GET /`

## Uso
- `ApiService.testConnection()`
- Mostrar la respuesta en pantalla para confirmar conectividad
