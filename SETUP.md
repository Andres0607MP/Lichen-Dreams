# Lichen Dreams — Guía de instalación y configuración desde cero

Documento práctico para clonar, configurar y ejecutar **Lichen Dreams
“Lee el aire, entiende tu entorno”** en un equipo nuevo.

Estructura general del sistema:

- **Frontend:** Flutter / Dart (aplicación móvil Android; objetivo principal).
- **Backend:** Python 3.12 · FastAPI · SQLAlchemy · Alembic.
- **Base de datos:** MySQL (por defecto `lichen_dreams`, puerto 3306).
- **IA:** TensorFlow/Keras — modelo activo **V8** (3 clases:
  liquen saludable, liquen contaminado, liquen desconocido).
- **Servicios externos:** Google Sign-In (OAuth) y Google Maps.

---

## 1. Requisitos previos

- **Git** (para clonar).
- **Python 3.12** (el proyecto se ha trabajado con 3.12).
- **Flutter** (SDK actual de la versión usada por el proyecto; incluye Dart).
- Solo si vas a compilar/ejecutar la app móvil:
  - **Android Studio** (SDK + emulador) o un dispositivo Android con modo
    depuración.
  - **JDK 17** (versión compatible con el Gradle/AGP del proyecto).
- **MySQL Server 8+** local (el proyecto no incluye Docker Compose actualmente).
- (Opcional) **Chrome** para ejecutar el target web de Flutter en desarrollo.

> Nota: el repositorio no contiene archivos `docker*` ni workflows de
> CI/CD en este momento.

## 2. Clonar el repositorio

```bash
git clone https://github.com/Andres0607MP/Lichen-Dreams.git
cd Lichen-Dreams
git checkout develop
```

## 3. Crear el archivo de entorno del backend

El backend carga automáticamente un archivo `.env` desde la carpeta
`backend/` (o desde la raíz si ejecutas desde ahí, según python-dotenv).

```bash
cp .env.example backend/.env
```

Luego edita `backend/.env` y cambia al menos los valores de:

| Variable | Qué poner |
| -------- | --------- |
| `JWT_SECRET` | una frase secreta larga y aleatoria |
| `DB_USER` / `DB_PASSWORD` / `DB_HOST` / `DB_PORT` / `DB_NAME` | credenciales de tu MySQL y nombre de la base de datos |
| `BACKEND_URL` | la URL pública del backend (ej. `http://127.0.0.1:8000` en local) |
| `GOOGLE_CLIENT_ID` | ID de cliente OAuth de Google (ver sección 11) |
| `GOOGLE_MAPS_API_KEY` | clave de API de Google Maps (ver sección 11) |

Valores opcionales: `SMTP_*` (solo si se desea enviar correos de recuperación)
y `DATABASE_URL` (para apuntar el backend a otra base de datos; si se define,
`config/database.py` la prioriza).

> **Seguridad:** `backend/.env` NO debe subirse al repositorio (está en
> `.gitignore`). Tampoco compartas valores reales.

## 4. Base de datos MySQL

1. Inicia MySQL (en Windows: servicio `MySQL80`; en Linux: `sudo systemctl
   start mysql`).
2. Crea la base de datos (ajusta credenciales a tu `.env`):

```sql
CREATE DATABASE IF NOT EXISTS lichen_dreams
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

3. Verifica la conexión desde el backend:

```bash
cd backend
python -c "from config import database; print(database.DATABASE_URL.split('://')[0] if hasattr(database,'DATABASE_URL') else 'ok')"
```

## 5. Backend — instalación y ejecución

```bash
cd backend
python -m venv .venv
# Windows PowerShell:
.\.venv\Scripts\activate
# macOS / Linux:
# source .venv/bin/activate

pip install -r requirements.txt
```

Aplicar migraciones (Alembic):

```bash
alembic upgrade head
```

Levantar el servidor:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

- Local: `http://127.0.0.1:8000`
- Documentación interactiva: `http://127.0.0.1:8000/docs`
- Health del proyecto: `http://127.0.0.1:8000/` y `http://127.0.0.1:8000/api/test`

### Tener en cuenta

- La primera ejecución carga el modelo de IA activo (V8) al realizar la
  primera predicción; la carga puede tardar unos segundos.
- Si no existe un registro de modelo activo en la BD, la inferencia fallará
  explícitamente (política anti-fallback) para proteger la trazabilidad.

## 6. IA

- Modelo activo: **V8.0** — `backend/ia/modelos/lichen_model_v8.keras`.
- Clases: `liquen saludable`, `liquen contaminado`, `liquen desconocido`.
- Preprocesamiento real: redimensión a 224×224, RGB y normalización (valor
  del código en `ia/modelos/lichen_classifier.py`).
- El modelo activo se resuelve desde la tabla `modelos_ia`
  (estado = `activo`) mediante `ia/resolver_modelo_activo.py`.
- **No se necesita entrenar nada para ejecutar el sistema.** El dataset se
  ignora en Git (`backend/ia/datasets/`) y se usa la inferencia del modelo
  ya entrenado.
- Comportamiento “desconocido”: si la IA clasifica la imagen como
  `liquen desconocido`, el sistema informa al usuario y **no persiste** el
  análisis (no aparece en historial, mapa ni panel). La trazabilidad de
  inferencia queda en el monitoreo de IA.

## 7. Frontend Flutter — instalación

```bash
cd frontend
flutter pub get
flutter doctor   # verifica el estado del entorno Android
```

### Conexión con el backend

La URL del backend se define en tiempo de compilación/ejecución con
`--dart-define=API_BASE_URL=...`:

- **Emulador Android** (backend en la misma PC):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

- **Dispositivo físico Android**: obtén la IP local de tu PC
  (`ipconfig` en Windows / `ip a` en Linux) y usa la red Wi‑Fi:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.X.X:8000
```

Si usas un dispositivo físico conectado por USB, también sirve:

```bash
adb reverse tcp:8000 tcp:8000
```

- **Web (solo desarrollo):**

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

> Nota: el backend debe escuchar en `0.0.0.0` (`--host 0.0.0.0`) para que
> un dispositivo físico o un emulador lo alcancen.

APK de entrega:

```bash
flutter build apk --dart-define=API_BASE_URL=http://TU_IP:8000
```

## 8. Autenticación

- Registro e inicio de sesión con correo/contraseña.
- Recuperación de contraseña mediante código de recuperación (y código por
  correo si se configura SMTP).
- Inicio de sesión/registro con **Google** (`/auth/google` valida el ID token
  con `GOOGLE_CLIENT_ID`). Las cuentas de Google no tienen contraseña local:
  la recuperación de contraseña las rechaza (comportamiento actual).
- Sesiones con JWT (`JWT_SECRET`, `JWT_ALGORITHM`, `JWT_EXPIRE_HOURS` en el
  `.env`).

## 9. Comandos útiles

```bash
# Backend
cd backend
alembic upgrade head        # migraciones
python -m pytest tests/     # pruebas del backend
uvicorn main:app --reload --port 8000

# Frontend
cd frontend
flutter pub get
flutter test                # pruebas de Flutter
flutter analyze             # análisis estático
flutter build apk --dart-define=API_BASE_URL=...
```

## 10. APIs externas y credenciales

El proyecto solo usa las APIs de **Google**:

### 10.1 Google Sign-In (OAuth)

1. Crea un proyecto en **Google Cloud Console**.
2. Configura la pantalla de consentimiento y crea una credencial
   **ID de cliente OAuth (Web)**.
3. Copia el **Client ID** en `GOOGLE_CLIENT_ID` de `backend/.env`.
4. En Android, registra el empaquetado de la aplicación y los hashes
   **SHA‑1 / SHA‑256** de la firma de depuración y de entrega (consulta la
   pantalla de credenciales de Android en Google Cloud). El `google-services.json`
   de Android, cuando exista, no debe subirse al repositorio.
5. Si `GOOGLE_CLIENT_ID` queda vacío, **el inicio de sesión con Google no
   estará disponible**; el resto de la autenticación (local) sigue funcionando.

### 10.2 Google Maps

1. Habilita **Maps SDK for Android** en el mismo proyecto de Google Cloud.
2. Crea una **API key** y ponla en `GOOGLE_MAPS_API_KEY` (backend).
3. La clave de Maps del frontend Android está configurada en
   `frontend/android/app/src/main/AndroidManifest.xml`; para producción se
   debe reemplazar por una clave real restringida por paquete y SHA.
4. Sin clave, el mapa no puede renderizarse en un dispositivo con Google
   Maps; el resto de la aplicación funciona.

> Costes/limitaciones: ambas APIs de Google tienen cuotas gratuitas y cuotas
> de pago; revisa la documentación oficial de Google Cloud para límites.

## 11. Checklist de instalación desde cero

```text
[ ] Cloné el repositorio (rama develop)
[ ] Instalé Python 3.12, Flutter, JDK 17 y MySQL
[ ] Creé backend/.env (cp .env.example backend/.env)
[ ] Configuré DB_USER/DB_PASSWORD/DB_NAME y JWT_SECRET
[ ] Creé la base de datos MySQL (lichen_dreams)
[ ] Instalé dependencias del backend (pip install -r requirements.txt)
[ ] Ejecuté migraciones (alembic upgrade head)
[ ] Levanté el backend (uvicorn main:app --reload --port 8000)
[ ] Verifiqué http://127.0.0.1:8000/docs
[ ] Configuré Flutter (flutter pub get, flutter doctor)
[ ] Levanté la app (emulador 10.0.2.2 o dispositivo físico con la IP del PC)
[ ] Probé registro e inicio de sesión
[ ] Probé la conexión frontend → backend con un análisis de imagen
```

---

## Verificación de estado

- `python -m pytest tests/` (backend)
- `flutter test` y `flutter analyze` (frontend)

La documentación de detalle de arquitectura vive en `docs/`; la documentación
de pruebas del Sprint 5 se encuentra en `docs/sprint5/`.