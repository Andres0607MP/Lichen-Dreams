# Mapeo de Endpoints — API Lichen Dreams

Resumen de rutas registradas en `backend`

Base URL: `/` (ver `backend/main.py`)

- GET `/` — Mensaje de servicio (salud de la API).
- GET `/token` — Genera token de ejemplo (dev).
- POST `/registro` — Hash de contraseña de ejemplo.

Routers registrados (prefijos)

- `/auth` (Auth)
  - POST `/auth/login` — RF: autenticación de usuarios (iniciar sesión).
  - POST `/auth/register` — RF: registrar usuario.
  - GET `/auth/me` — RF: obtener perfil del usuario autenticado.
  - POST `/auth/logout` — RF: cerrar sesión.

- `/users` (Users)
  - GET `/users` — Obtener lista de usuarios.
  - GET `/users/{user_id}` — Obtener usuario por ID.
  - PUT `/users/{user_id}` — Actualizar usuario.
  - DELETE `/users/{user_id}` — Eliminar usuario.

- `/analysis` (Analysis)
  - POST `/analysis/upload` — Subir imagen para análisis. (RF01)
  - POST `/analysis/detect-lichen` — Detectar si la imagen es un liquen. (RF02)
  - POST `/analysis/process` — Procesar imagen con IA. (RF03, RF10)
  - GET `/analysis/{analysis_id}/status` — Estado del análisis.
  - GET `/analysis/{analysis_id}/humidity` — Datos de humedad estimada. (RF05)
  - GET `/analysis/{analysis_id}/air-quality` — Calidad del aire estimada. (RF11)
  - GET `/analysis/{analysis_id}/recommendation` — Recomendación ecológica. (RF12)
  - GET `/analysis/results/{analysis_id}` — Resultados completos. (RF09)
  - GET `/analysis/{analysis_id}` — Obtener análisis por ID.
  - DELETE `/analysis/{analysis_id}` — Eliminar análisis.

- `/location` (Location)
  - POST `/location/save/{analysis_id}` — Guardar ubicación de un análisis. (RF07)
  - GET `/location/{location_id}` — Obtener ubicación por ID. (RF08)
  - GET `/location` — Listar todas las ubicaciones (para mostrar en mapa). (RF08)

- `/history` (History)
  - POST `/history/save` — Guardar análisis en historial del usuario. (RF13)
  - GET `/history` — Obtener historial del usuario autenticado. (RF14)
  - GET `/history/user/{user_id}` — Obtener historial de un usuario específico (admin). (RF14)
  - DELETE `/history/{history_id}` — Eliminar registro de historial.

- `/admin` (Admin)
  - GET `/admin/users` — Obtener todos los usuarios (admin). (RF15)
  - POST `/admin/users` — Crear usuario (admin). (RF15)
  - PUT `/admin/users/{user_id}` — Actualizar usuario (admin). (RF15)
  - DELETE `/admin/users/{user_id}` — Eliminar usuario (admin). (RF15)
  - GET `/admin/reports` — Listar informes (admin). (RF16)
  - POST `/admin/reports` — Generar informe (admin). (RF16)
  - GET `/admin/reports/{report_id}` — Obtener informe por ID (admin). (RF16)
  - DELETE `/admin/reports/{report_id}` — Eliminar informe (admin). (RF16)
  - GET `/admin/reports/{report_id}/download` — Descargar informe.

## Contrato API v1 (análisis e historial)

El contrato oficial para frontend y backend se define con los siguientes nombres de campos, en español, sin crear rutas paralelas ni modificar la estructura de la base de datos.

### Respuesta de análisis

- POST `/analysis/process`
- GET `/analysis/results/{analysis_id}`
- GET `/analysis/{analysis_id}`

```json
{
  "id": 1,
  "id_usuario": 1,
  "url_imagen": "https://example.com/image.jpg",
  "resultado": "liquen saludable",
  "estado": "completado",
  "humedad": 65.5,
  "calidad_del_aire": "moderada",
  "recomendacion": "Buena calidad de aire en la zona",
  "fecha_creacion": "2026-06-29T12:00:00"
}
```

Las respuestas de estado, humedad, calidad del aire y recomendación ahora incluyen también los campos base de la UI para evitar respuestas parciales.

### Estado del análisis

- GET `/analysis/{analysis_id}/status`

```json
{
  "id": 1,
  "estado": "completado",
  "progreso": 100
}
```

### Humedad

- GET `/analysis/{analysis_id}/humidity`

```json
{
  "id": 1,
  "humedad": 65.5,
  "fecha_creacion": "2026-06-29T12:00:00",
  "ubicacion": "Bosque tropical"
}
```

### Calidad del aire

- GET `/analysis/{analysis_id}/air-quality`

```json
{
  "id": 1,
  "calidad_del_aire": "moderada",
  "indice_calidad": 45.2,
  "contaminantes": {
    "PM2.5": 12.3,
    "PM10": 25.5,
    "NO2": 15.0
  },
  "fecha_creacion": "2026-06-29T12:00:00"
}
```

### Recomendación

- GET `/analysis/{analysis_id}/recommendation`

```json
{
  "id": 1,
  "recomendacion": "Aumentar cobertura vegetal en zona",
  "prioridad": "alta",
  "acciones": [
    "Plantar árboles nativos",
    "Reducir contaminación",
    "Proteger ecosistema"
  ]
}
```

### Historial

- POST `/history/save`
- GET `/history`
- GET `/history/user/{user_id}`

```json
{
  "id": 1,
  "id_usuario": 1,
  "id_analisis": 1,
  "url_imagen": "https://example.com/image.jpg",
  "resultado": "liquen saludable",
  "estado": "completado",
  "humedad": 65.5,
  "calidad_del_aire": "moderada",
  "recomendacion": "Buena calidad de aire en la zona",
  "ubicacion": "Bogotá, Colombia",
  "fecha_creacion": "2026-06-29T12:00:00"
}
```

Notas y siguientes pasos

- Las rutas existentes se mantienen intactas. El contrato v1 define únicamente los nombres de campo y el formato de respuesta esperados por frontend y backend.
- No se crean rutas paralelas como `/analysis2`, `/analysis_v2`, `/history_v2`, `/analysis-copy` ni `/history-copy`. Cualquier expansión futura de la API debe mantener el prefijo oficial `/analysis` o `/history` sin sufijos redundantes.

Decisión arquitectónica

- Rutas consolidadas: `/analysis/*` y `/history/*` permanecen como la única vía oficial para estos flujos.
- Rutas eliminadas: no se encontraron endpoints duplicados ni versiones paralelas activas en el backend actual; la protección implementada evita que aparezcan en el futuro.
- Integración IA/mock: la lógica mock actual se encapsuló en [backend/services/analysis_service.py](backend/services/analysis_service.py) para dejar el contrato REST estable y permitir reemplazar el proveedor en el futuro por IA real o base de datos sin cambiar los endpoints ni los nombres de campo.

