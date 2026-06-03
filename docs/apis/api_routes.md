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

Notas y siguientes pasos

- Las rutas devuelven datos simulados (mocks). Para integrarlas con la base de datos y la IA se deben implementar los controladores reales en `backend/routes/*` y las dependencias de `backend/config`.
