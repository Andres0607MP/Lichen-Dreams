# Backend — Lichen Dreams

Pequeñas instrucciones para inicializar el backend (FastAPI).

## Requisitos

- Python 3.8+
- `pip`

## Instalación (Linux / macOS / Git Bash)

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

## Instalación (Windows PowerShell)

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

## Variables de entorno

El archivo `.env.example` contiene todas las variables necesarias. Copiándolo a `.env` y completando los valores se configurará el backend.

Variables importantes:

- **DB_HOST**: Host de la base de datos MySQL (ej: `localhost`).
- **DB_PORT**: Puerto de MySQL (default `3306`).
- **DB_USER**: Usuario de MySQL.
- **DB_PASSWORD**: Contraseña de MySQL.
- **DB_NAME**: Nombre de la base de datos (ej: `lichen_dreams`).
- **JWT_SECRET**: Clave secreta para firmar tokens JWT.
- **GOOGLE_MAPS_API_KEY**: clave de la API de Google Maps (obtenida en Google Cloud Console).
- **GOOGLE_CLIENT_ID**: ID de cliente web de Google para el flujo de Sign-In (debe coincidir con el configurado en el frontend).
- **API_HOST**: host donde escucha el backend (default `127.0.0.1`).
- **API_PORT**: puerto donde escucha el backend (default `8000`).
- **BACKEND_URL**: URL completa del backend (usada por el frontend, ej: `http://127.0.0.1:8000`).
- **SMTP_*** (opcional): configuración para envío de correos (recuperación de contraseña, verificación).

## Base de datos y migraciones

El esquema de la base de datos se gestiona exclusivamente con **Alembic**. No se ejecuta `Base.metadata.create_all()` al arranque.

Para aplicar migraciones pendientes:

```bash
python -m alembic upgrade head
```

Para crear una nueva migración automática tras cambios en los modelos:

```bash
python -m alembic revision --autogenerate -m "descripción de cambios"
```

## Verificación

- Abrir `http://127.0.0.1:8000/docs` para comprobar la interfaz interactiva de Swagger UI.
- Endpoint raíz: `GET /` devuelve un mensaje de servicio y el host de la base de datos.
- Endpoint de configuración para el frontend: `GET /api/config` devuelve la clave de Google Maps (si está configurada) y la URL del backend.
- Endpoint de prueba de token: `GET /token` devuelve un JWT de ejemplo (útil para desarrollo).

## Pruebas

Ejecutar el conjunto de pruebas con:

```bash
pytest
```

## Notas

- No subir el archivo `.env` al repositorio.
- Al iniciar el backend, se insertan datos de demostración si no existen: rol admin, rol user, usuario admin (`admin@gmail.com` / `admin123`), un modelo IA y un dataset de demostración.
