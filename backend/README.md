# Backend — Lichen Dreams

Pequeñas instrucciones para inicializar el backend (FastAPI).

## Requisitos

- **Python 3.12** (obligatorio)
- `pip`

> ⚠️ El backend debe ejecutarse con **Python 3.12**. No uses Python 3.13 o 3.14
> para crear el entorno virtual: **TensorFlow aún no admite Python 3.14** y
> `pip install -r requirements.txt` fallará con
> `Could not find a version that satisfies the requirement tensorflow`.
> Por eso las instrucciones crean el entorno con `python3.12` (Linux/macOS) o
> `py -3.12` (Windows), en lugar de un `python` genérico que podría apuntar a
> otra versión.

## Instalación (Linux / macOS / Git Bash)

```bash
python3.12 --version                 # debe mostrar Python 3.12.x
python3.12 -m venv .venv
source .venv/bin/activate
python --version                     # debe seguir mostrando Python 3.12.x
python -m pip install --upgrade pip
pip install -r requirements.txt
cp .env.example .env
python -m alembic upgrade head
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

Se usa `python3.12` de forma intencionada para garantizar que el entorno
virtual se cree con la versión correcta, aunque el sistema tenga instalada
otra versión (por ejemplo, Python 3.14).

## Instalación (Windows PowerShell)

```powershell
py -3.12 --version                   # debe mostrar Python 3.12.x
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python --version                     # debe seguir mostrando Python 3.12.x
python -m pip install --upgrade pip
pip install -r requirements.txt
copy .env.example .env
python -m alembic upgrade head
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

El launcher `py -3.12` permite elegir explícitamente Python 3.12 aunque en el
sistema esté instalada otra versión de Python (por ejemplo, Python 3.14).

> Dentro del entorno `.venv` activado, el comando `python` ya apunta al
> intérprete de Python 3.12 con el que se creó el entorno.

## Problemas frecuentes

### TensorFlow no se puede instalar

Si al instalar dependencias aparece:

```text
ERROR: Could not find a version that satisfies the requirement tensorflow
ERROR: No matching distribution found for tensorflow
```

comprueba la versión actual de Python dentro del entorno:

```bash
python --version
```

Si muestra **Python 3.14.x** (u otra versión distinta de 3.12), el entorno fue
creado con una versión incorrecta. Solución:

**Linux / macOS:**

```bash
deactivate
rm -rf .venv
python3.12 -m venv .venv
source .venv/bin/activate
python --version                     # debe mostrar Python 3.12.x
pip install -r requirements.txt
```

**Windows PowerShell:**

```powershell
deactivate
Remove-Item -Recurse -Force .venv
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python --version                     # debe mostrar Python 3.12.x
pip install -r requirements.txt
```

No soluciones este problema cambiando al azar la versión de TensorFlow del
`requirements.txt`: primero usa **Python 3.12** y conserva las dependencias
definidas en el proyecto.

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
