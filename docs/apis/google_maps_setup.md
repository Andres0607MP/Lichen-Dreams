# Configuración Inicial de Google Maps API

## Objetivo
Preparar la integración inicial de Google Maps API para futuras funciones de geolocalización.

## Variables de entorno
- `GOOGLE_MAPS_API_KEY`

## Archivos creados o usados
- `backend/config/settings.py`
- `backend/routes/maps_route.py`
- `.env.example`

## Endpoint de prueba
- `GET /api/maps/test`

## Respuesta esperada
```json
{
  "latitud": 4.711,
  "longitud": -74.0721,
  "estado": "Google Maps API configurada",
  "api_key_configurada": true
}
```

## Notas
- La API key no se expone en la respuesta.
- Este endpoint sirve como validación técnica inicial de la configuración.
