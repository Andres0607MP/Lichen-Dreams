# ayudaDespliege.md — Despliegue de Lichen Dreams

> **Última verificación: 8 de septiembre de 2026.**
> Precios, planes gratuitos (free tiers), límites y políticas de los
> servicios externos cambian con frecuencia. Verifica siempre las páginas
> oficiales (sección «Fuentes oficiales»). Cuando una cifra no pudo
> confirmarse hoy, se indica «Verificar precio actual en la página oficial».

---

## Qué se despliega

| Componente | Tecnología | Artefacto en el repo |
| --- | --- | --- |
| Backend | FastAPI (Python 3.12) | carpeta `backend/` |
| Base de datos | MySQL | esquema `lichen_dreams`, migraciones Alembic |
| IA | TensorFlow/Keras — modelo activo **V8** | `backend/ia/modelos/lichen_model_v8.keras` (~31 MB) |
| Frontend | Flutter (Android) | APK/AAB con `--dart-define=API_BASE_URL=...` |
| Storage | filesystem del backend | `backend/uploads/` (análisis, perfiles, artículos) |
| Externos | Google Sign-In + Google Maps | cuenta en Google Cloud Console |

Condiciones que marcan el despliegue:

1. El modelo activo se resuelve desde la BD (`modelos_ia` con
   `estado='activo'`). Sin migraciones aplicadas no hay modelo resuelto.
2. La primera inferencia carga TensorFlow (el runtime suma memoria a los
   ~31 MB del archivo). Se recomienda disponer de **1 GB de RAM o más** para
   margen; no se midió en este entorno un umbral exacto de OOM.
3. Las imágenes se guardan en el filesystem del servidor. Muchos hosts usan
   filesystem efímero (se pierde al redeployear).
4. La app es Android-first (Google Maps y Google Sign-In móvil).

---

## 🚀 Despliegue rápido recomendado

Receta resumida (cada paso enlaza a su sección):

1. [Crear cuenta en el proveedor (Render + Aiven)](#4-estrategia-c--recomendada)
2. [Crear MySQL en Aiven](#8-base-de-datos-mysql-y-migraciones)
3. [Desplegar el backend (Render)](#7-desplegar-el-backend-render)
4. [Configurar variables](#6-variables-de-entorno)
5. [Ejecutar migraciones contra producción](#8-base-de-datos-mysql-y-migraciones)
6. [Verificar la API](#7-desplegar-el-backend-render)
7. [Configurar Google OAuth](#11-google-sign-in-en-producción)
8. [Configurar Google Maps](#12-google-maps-en-producción)
9. [Obtener la URL HTTPS](#10-https-dominio-y-dns)
10. [Ajustar `API_BASE_URL` para el build](#13-api_base_url-y-backend_url)
11. [Generar el APK](#15-frontend-flutter--apk-de-producción)
12. [Probar la aplicación](#16-publicación-de-la-app)
13. [Publicar el APK](#21-publicación-del-apk)

---

## 1. Arquitectura

```text
Usuario (APK Android)
   │
   ├── Google Sign-In (OAuth, Google Cloud)
   ├── Google Maps (Maps SDK for Android + API key)
   ▼  HTTPS (TLS automático del host)
Backend FastAPI (uvicorn)
   ├── JWT (JWT_SECRET)
   ├── MySQL (Alembic)
   ├── IA: lichen_model_v8.keras (TensorFlow, CPU)
   └── uploads/ (disco persistente o almacenamiento objeto)
```

---

## 2. Estrategia A — Costo $0 (demostración)

| Necesidad | Servicio | Estado real hoy |
| --- | --- | --- |
| Backend | **Render — Free Web Service** | $0; 512 MB RAM, 0.1 CPU; TLS automático; se duerme por inactividad; 5 GB/mes Hobby |
| Base de datos | **Aiven MySQL — plan Free** | $0; 1 vCPU, 1 GB RAM, 1 GB de almacenamiento; región fija (DigitalOcean/UpCloud); sin connection pooling |
| Storage | Render Persistent Disk | no es gratis (US$0.25/GB/mes); alternativa sin costo: R2 u otro host |
| Dominio/HTTPS | URL `.onrender.com` | TLS automático sin costo |
| Frontend | GitHub Releases (APK) | $0 |
| Monitoreo | Render logs + UptimeRobot (free) | $0 |

**Advertencias honestas:**

- **La IA no está garantizada en 512 MB de RAM.** El plan gratuito puede
  servir para demostrar el backend, el login, la BD y la interfaz, pero la
  primera predicción de TensorFlow puede agotar la memoria. *Esta arquitectura
  puede servir para una demostración parcial, pero no garantiza la inferencia
  de IA.* Si necesitas IA estable a $0, evalúa una VM de Oracle Cloud Always
  Free (verificar disponibilidad y requisito de tarjeta) con MySQL propio.
- Render Free **se duerme por inactividad** (cold start en el primer request).
- Aiven Free puede **apagarse por inactividad prolongada** según su política de
  uso aceptable.
- Sin disco ni almacenamiento objeto, las **imágenes subidas se pierden al
  redeployear**.

---

## 3. Estrategia B — Económica

Arquitectura concreta:

- **Backend:** Render Starter ($7/mes, 512 MB) — o Render Standard ($25/mes,
  2 GB) si quieres margen real para TensorFlow.
- **Base de datos:** Aiven MySQL Developer ($5/mes, 8 GB).
- **Storage:** Render Persistent Disk pequeño ($0.25/GB/mes).
- **Monitoreo:** logs de Render + UptimeRobot free.
- **Costo orientativo: ~$12–20/mes** (verifica precios; por consumo se sumará
  el disco).

---

## 4. Estrategia C — Recomendada

```text
Backend    → Render Web Service — Standard (2 GB RAM, 1 CPU) ≈ $25/mes
DB         → Aiven MySQL (Developer $5 o Hobbyist $19, 8 GB)
Storage    → Render Persistent Disk (US$0.25/GB/mes) montado en backend/uploads
Monitoring → Render logs + UptimeRobot free (+ Sentry opcional)
Frontend   → APK/AAB firmado (GitHub Releases de entrada; Google Play opcional)
```

**Por qué:** es la combinación más simple para este proyecto: Render despliega
FastAPI desde Git con TLS y rollback; Aiven da **MySQL real** (sin cambiar el
motor del código), y el disco persistente evita la pérdida de `uploads/` sin
cambiar código. Con 2 GB de RAM, TensorFlow tiene margen para la primera
carga del modelo.

---

## 5. Opción profesional (posterior)

- Backend en AWS/GCP/Azure (Cloud Run o VM) o un VPS con systemd + Caddy.
- MySQL gestionado del proveedor (RDS/Cloud SQL MySQL, misma compatibilidad).
- Storage S3-compatible (requiere un cambio de código acotado, ver §17).
- CI/CD con GitHub Actions (tests + build APK + deploy).
- Kubernetes: **solo si el tráfico lo justifica**; para este proyecto no aporta
  ahora.

---

## 6. Variables de entorno

Fuente de verdad: `.env.example` → copia a `backend/.env` en local; en el host
se ponen como variables del servicio.

| Variable | Componente | Obligatoria | Ejemplo | Dónde obtenerla |
| --- | --- | --- | --- | --- |
| `DB_HOST` | backend | Sí | `mysql-...aivencloud.com` | Consola del proveedor MySQL |
| `DB_PORT` | backend | Sí | `3306` (o el del proveedor) | Consola del proveedor |
| `DB_USER` | backend | Sí | `avnadmin` | Consola del proveedor |
| `DB_PASSWORD` | backend | Sí | `****` | Consola del proveedor |
| `DB_NAME` | backend | Sí | `defaultdb` | Consola del proveedor |
| `DATABASE_URL` | backend (opcional) | No | `mysql+pymysql://u:p@host:3306/db` | Construida con lo anterior |
| `JWT_SECRET` | backend | Sí (cámbialo) | frase aleatoria larga | La generas tú |
| `JWT_ALGORITHM` | backend | No | `HS256` | Valor real del repo |
| `JWT_EXPIRE_HOURS` | backend | No | `24` | Valor real del repo |
| `API_HOST` / `API_PORT` | backend | No (usa `$PORT` del host) | `0.0.0.0` / `8000` | — |
| `BACKEND_URL` | backend | Sí | `https://tu-app.onrender.com` | La URL final |
| `GOOGLE_CLIENT_ID` | backend | Sí para Google | `xxxx.apps.googleusercontent.com` | Google Cloud Console |
| `GOOGLE_MAPS_API_KEY` | backend | Sí para Maps | `AIza...` | Google Cloud Console |
| `SMTP_HOST/PORT/USER/PASSWORD/FROM/TLS` | backend | No | `smtp.gmail.com`… | Tu proveedor SMTP |
| `API_BASE_URL` | frontend | Sí (solo build) | `https://tu-api.com` | Se pasa con `--dart-define` |

### `BACKEND_URL` vs `API_BASE_URL`

| Variable | Quién la usa | Propósito |
| --- | --- | --- |
| `BACKEND_URL` | Backend | URL pública/configuración del servidor (imágenes y enlaces) |
| `API_BASE_URL` | Flutter | URL a la que se conecta la aplicación (se fija en el build) |

Esto coincide con el código real: el backend lee su `.env`/variables de
entorno; Flutter **no lee `.env` en runtime**, recibe la URL por
`--dart-define`.

---

## 7. Desplegar el backend (Render, paso a paso)

1. Sube el repo a GitHub y conecta Render (New → Web Service → repo, rama
   `develop`).
2. Root directory: `backend`.
3. Build command: `pip install -r requirements.txt`
4. Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
5. Python version: **3.12**.
6. Añade todas las variables del §6 (Render inyecta `PORT` automáticamente).
7. Pre-Deploy Command (si el plan lo permite): `alembic upgrade head` — y
   marca esta migración como explícita (ver §8).

Verificación:

```bash
curl https://TU-APP.onrender.com/
curl https://TU-APP.onrender.com/api/test
```

Endpoint de health reales del proyecto:

- `GET /` → público.
- `GET /api/test` → público.
- `GET /ia/health`, `GET /ia/metrics`, `GET /ia/events`, `GET /ia/diagnostics`
  → **requieren token JWT de un usuario administrador** (no son públicos).
- No existe un `/health` en el código: no uses esa ruta.

---

## 8. Base de datos MySQL y migraciones

```bash
cd backend
alembic upgrade head
alembic current
```

- `alembic.ini` está en `backend/`; migraciones en `backend/alembic/versions/`
  (incluyen `register_modelo_v8` y `activate_modelo_v8`).
- En el host: configura `DB_*`/`DATABASE_URL` y ejecuta la migración contra la
  **base de datos de producción** — nunca contra tu BD local.
- Advertencia: **no ejecutes migraciones de producción contra la base de
  datos equivocada**; verifica el contenido de `DATABASE_URL`/`DB_*` antes de
  ejecutar `alembic upgrade head`.

Verificar que quedó el modelo activo:

```sql
SELECT id_modelo, version, estado_modelo, observaciones
FROM lichen_dreams.modelos_ia;
-- se espera version='v8.0' estado='activo'
```

Flow inequívoco:

```text
Crear DB → configurar DB_* en el host → alembic upgrade head
→ alembic current → verificar tablas → verificar modelo V8
```

Si la migración falla: revisa credenciales/SSL del proveedor y que la BD
exista.

---

## 9. IA en producción

- Modelo activo: **V8.0** · `backend/ia/modelos/lichen_model_v8.keras` ·
  3 clases (saludable, contaminado, desconocido).
- Dependencias: TensorFlow/Keras en `requirements.txt`. Funciona en CPU, sin
  GPU.
- **Memoria:** el archivo pesa ~31 MB; el runtime de TensorFlow agrega
  memoria. Se recomienda **≥ 1 GB de RAM** para disponer de margen (no se
  midió un umbral exacto de OOM en este entorno). En 512 MB la primera
  predicción puede fallar por memoria.
- Comportamiento de «desconocido»: el sistema informa al usuario y **no
  persiste** el análisis (fuera de historial/mapa/panel); la inferencia sí
  queda en el monitoreo de IA.
- Si el hosting no soporta la IA, sube el plan a ≥ 1–2 GB de RAM o mueve la
  inferencia a un servicio dedicado (fuera del alcance actual, no
  implementado).

---

## 10. HTTPS, dominio y DNS

- HTTPS inmediato: URL gratuita `.onrender.com` (TLS automático).
- Dominio propio barato (~US$1–12/año en un registrar) + **Cloudflare** (plan
  Free) con proxy:
  - CNAME: `api` → `tu-backend.onrender.com` (proxied).
  - Render: Settings → Custom domains → `api.tudominio.com` (emite su
    certificado).
- URL final: `https://api.tudominio.com` → actualiza `BACKEND_URL` y el
  `--dart-define` del build.

---

## 11. Google Sign-In en producción

Mecanismo real del proyecto: el backend valida el **ID token** de Google con
`google-auth` en `/auth/google` (`verify_google_id_token`) y usa
`GOOGLE_CLIENT_ID` (Client ID Web); el frontend usa el plugin
`google_sign_in`.

Configuración:

1. Google Cloud Console → proyecto.
2. **OAuth consent screen** (Externo para producción).
3. **Web Client ID** → `GOOGLE_CLIENT_ID` del backend.
4. **Android Client ID**: en credenciales Android registra el **package name**
   real (según `frontend/android/app/build.gradle.kts`) y los **SHA‑1 y SHA‑256**
   de la firma:
   - debug: de la firma de depuración usada por Android Studio;
   - release: del keystore de release (`keytool -list -v -keystore key.jks`).
5. El CI de `google_sign_in` (Android) usa la config de Google Services; si el
   proyecto usa `google-services.json`, **no debe subirse a Git** (verifica si
   tu setup actual lo incluye; en el repo no se versiona `.env` ni
   `google-services.json`).
6. Si `GOOGLE_CLIENT_ID` queda vacío, Google Sign-In no estará disponible; el
   login local sigue funcionando.

---

## 12. Google Maps en producción

Integración real: la API key del frontend Android está en
`frontend/android/app/src/main/AndroidManifest.xml`; el backend expone su
`GOOGLE_MAPS_API_KEY` (usada sobre todo para el target web y configuración).

1. Google Cloud Console → habilita **Maps SDK for Android** (y Dynamic Maps si
   usas el target web).
2. Crea una **API key** con restricción **Android**: package name + SHA-1 y
   SHA-256 reales (debug y release); en web, restricción por dominio.
3. En producción, reemplaza la key del `AndroidManifest.xml` por la clave
   restringida (no dejes la de desarrollo hardcodeada).
4. **Billing:** Google Maps Platform requiere **facturación activada** (no
   existe ya un «$200 libres» fijo): Google ofrece hoy un **crédito de prueba
   de ~US$300 para clientes nuevos** en la cuenta de facturación y modalidad
   pay-as-you-go por consumo (y planes de suscripción desde ~US$100/mes).
   Verificar los créditos actuales y las tarifas por SKU en la página oficial.
5. Sin clave restringida correcta, el mapa no carga en el dispositivo.

---

## 13. `API_BASE_URL` y `BACKEND_URL`

### `API_BASE_URL` según el escenario

| Escenario | Valor usado |
| --- | --- |
| Emulador Android, backend local | `http://10.0.2.2:8000` |
| Dispositivo físico Android, backend local | `http://IP_DEL_PC:8000` (IP local del PC) |
| Backend desplegado | `https://tu-backend.onrender.com` (o tu dominio) |

Se pasa al frontend solo en el build:

```bash
flutter build apk --dart-define=API_BASE_URL=https://tu-backend.onrender.com
```

No confundir con el `.env` del backend.

---

## 14. Estrategias resumidas

Ver §2, §3, §4 y la tabla de costos (§22). Para una demostración educativa la
ruta práctica es: **Aiven MySQL Free + Render Free + GitHub Releases**, con la
advertencia de que la IA no está garantizada en 512 MB.

---

## 15. Frontend Flutter — APK de producción

```bash
cd frontend
flutter pub get

# Emulador:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
# Físico (IP local del PC):
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
adb reverse tcp:8000 tcp:8000   # opcional, USB

# Release apuntando a producción:
flutter build apk --dart-define=API_BASE_URL=https://tu-backend.onrender.com
flutter build appbundle --dart-define=API_BASE_URL=https://tu-backend.onrender.com
```

- Firma: crea un keystore (`keytool -genkey -v -keystore key.jks ...`),
  configura `frontend/android/key.properties` y el bloque `signingConfigs` del
  `build.gradle`. No subas `key.jks` ni `key.properties` a Git.
- Artefactos:
  - `frontend/build/app/outputs/flutter-apk/app-release.apk`
  - `frontend/build/app/outputs/bundle/release/app-release.aab`

---

## 16. Publicación de la app (sin pagar inicialmente)

| Canal | Costo inicial | Ventajas | Desventajas |
| --- | --- | --- | --- |
| **GitHub Releases** (APK) | $0 | Inmediato, enlace directo, ideal para evaluación | Se instala con “orígenes desconocidos” |
| **Firebase App Distribution** | $0 (plan Spark; verificar) | Entrega a testers por correo | No es distribución pública final |
| **Google Play** | Registro único (≈US$25, verificar) | Distribución real y actualizaciones | Pago, revisión y políticas |

Para la evaluación académica: GitHub Releases (y App Distribution si se
desea).

---

## 17. Storage (uploads)

Actualmente el proyecto guarda los archivos en `backend/uploads/`. El
despliegue necesita filesystem persistente o almacenamiento externo.

- **Solución inmediata:** disco persistente del proveedor montado en el path
  de `uploads/` (ej. Render Persistent Disk + bind o symlink en `backend/uploads`).
  Sin cambios de código.
- **Solución futura:** almacenamiento objeto S3-compatible (Cloudflare R2,
  AWS S3, GCS, Backblaze). Requiere **adaptar el código actual**
  (`backend/services/upload_service.py` y las rutas `/imagenes`) para subir y
  servir desde el bucket; documentado aquí sin implementar.

Opción $0 relevante: **Cloudflare R2** (hoy: 10 GB de almacenamiento, 1 M de
operaciones clase A y 10 M de clase B al mes, egress gratis; luego ~US$0.015
por GB-mes). Verificar cifras en la web oficial. R2 también requiere el cambio
de código de uploads.

---

## 18. Seguridad

Recomendaciones estándar marcadas para producción (comprobadas en el repo solo
donde se indica):

- [ ] `backend/.env` fuera de Git (comprobado: `.gitignore` ignora `.env`).
- [ ] `JWT_SECRET` cambiado por uno aleatorio largo.
- [ ] HTTPS activado.
- [ ] CORS: el código actual usa
  `allow_origin_regex=https?://(localhost|127.0.0.1|10.0.2.2)(:\d+)?`
  (no es `*`). Para el target web con dominio, amplía el regex en
  `backend/main.py` con tu dominio.
- [ ] `GOOGLE_CLIENT_ID` / `GOOGLE_MAPS_API_KEY` reales y restringidas.
- [ ] `key.jks`, `key.properties`, `google-services.json` fuera de Git.
- [ ] uvicorn sin `--reload` en producción.
- [ ] BD con firewall/IP allowlist y usuario con permisos mínimos.
- [ ] Backups (ver §19).
- [ ] Revisar logs para no exponer secretos.

Estado real: BUG-001 (control de acceso a imágenes) está corregido y
validado en el repo.

---

## 19. Backup

- **Base de datos (MySQL):**

```bash
mysqldump -h HOST -P PORT -u USER -p lichen_dreams > respaldo.sql
mysql -h HOST -u USER -p lichen_dreams < respaldo.sql   # restaurar
```

  La política de backups automáticos depende del proveedor (Aiven Free tiene
  capacidades limitadas; verifica en su consola).
- **uploads/:** respaldo según el proveedor (descarga del disco persistente o
  copia del bucket). No existe backup automático propio del proyecto.

---

## 20. Actualizaciones y rollback

```text
git push (rama desplegada)
   ↓ auto-deploy del host
   ↓ (opcional) pre-deploy: alembic upgrade head
   ↓ verificar: /api/test y un análisis real
```

Rollback: la plataforma elegida ofrece historial de despliegues; **verificar
las opciones de rollback del plan actual** (en Render, el plan define cuántos
builds se conservan; debes cambiarlo en su panel si aplica). No hagas
`git reset --hard`.

---

## 21. Publicación del APK

```text
flutter build apk --release --dart-define=API_BASE_URL=...
   → app-release.apk
   → GitHub Release (subir el .apk)
   → compartir el enlace
```

Segunda opción (no es requisito): Google Play (registro único, verificar en la
página oficial).

---

## 22. Monitoreo

- Render: logs del servicio (7 días en Hobby), health checks del plan, métricas
  de servicio. Indicadores útiles reales: `/` y `/api/test`; `GET /ia/health`,
  `/ia/metrics`, `/ia/diagnostics` y `/ia/events` para el Monitor IA (admin).
- **UptimeRobot** (free tier: número de monitores y frecuencia de chequeo —
  verificar en su web): monitoriza `/`.
- Opcionales (verificar free tiers actuales): Sentry (errores), Better Stack
  (logs). Recomendado concreto: **Render logs + UptimeRobot**.

---

## 23. Problemas frecuentes

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| Backend no inicia | variables faltantes o `PORT` | revisa logs, define `PORT`/`DB_*`/`JWT_SECRET` |
| No conecta a MySQL | host/puerto o firewall | datos exactos de la consola; abre acceso |
| Migraciones fallan | credenciales/SSL | verifica `DATABASE_URL`/`DB_*`; que la BD exista |
| 401 en `/ia/*` | sin token o no admin | usa un usuario con rol admin y JWT válido |
| Google Login falla | SHA/package o Client ID distinto | registra paquete + hash reales; mismo Client ID |
| Mapa en blanco | key sin restricción o billing | Maps SDK Android, restricción por paquete+SHA, billing |
| APK no conecta | `API_BASE_URL` equivocada | usa IP local / dominio real; `adb reverse` si aplica |
| Imágenes se pierden | filesystem efímero | disco persistente o storage objeto |
| Primera predicción lenta/errónea | cold start y RAM baja | sube a ≥ 1–2 GB |
| CORS en web | el regex no incluye tu dominio | amplía `allow_origin_regex` en `main.py` |
| «Modelo activo no encontrado» | migraciones no aplicadas | `alembic upgrade head` en producción |

---

## 24. Checklist final de producción

```text
[ ] Backend desplegado con HTTPS
[ ] MySQL creado y accesible desde el backend
[ ] Alembic ejecutado en producción (modelo v8.0 activo)
[ ] Variables configuradas (JWT_SECRET cambiado; GOOGLE_* reales)
[ ] CORS afinado para el dominio web (si usas web)
[ ] /api/test y /ia/health responden (admin para /ia/*)
[ ] Un análisis real: clasificación, historial y mapa OK
[ ] Registro, login, recuperación y perfil OK
[ ] Google Sign-In y Google Maps validados en un dispositivo
[ ] Uploads persistentes (disco o storage)
[ ] Backups configurados (mysqldump / política del proveedor)
[ ] Monitoreo configurado (logs + UptimeRobot + opcional Sentry)
[ ] APK de release firmado con API_BASE_URL de producción
```

---

## 25. Tabla de costos

| Componente | Opción $0 | Opción recomendada | Observación |
| --- | --- | --- | --- |
| Backend | Render Free (512 MB) | Render Standard (2 GB) ≈ $25/mes | Free: duerme y riesgo OOM con TF; costo mensual |
| Base de datos | Aiven MySQL Free (1 GB) | Aiven MySQL Developer $5 o Hobbyist $19 | Free sin límite de tiempo pero puede apagarse por inactividad |
| Storage | Cloudflare R2 (10 GB) o efímero | Render Persistent Disk $0.25/GB | R2 sin costo inicial; egress libre |
| Dominio/HTTPS | URL `.onrender.com` | Cloudflare Free + tu dominio | — |
| Monitoreo | UptimeRobot free + logs Render | igual o + Sentry | — |
| Frontend | GitHub Releases (APK) | igual | Google Play: costo único (verificar) |
| Google Maps | crédito de prueba (≈$300, verificar) | pay-as-you-go o suscripción | requiere billing; consumo condicionado |

Costos: **mensuales** (backend, DB, disco), **únicos** (dominio, registro de
Play), **condicionados al consumo** (Maps, storage extra). No hay cifras no
verificadas: lo marcado «verificar» debe confirmarse en la página oficial.

---

## 26. Comparativa de proveedores (solo opciones útiles)

| Proveedor | Backend | MySQL | HTTPS | Free tier real | Facilidad | Recomendación |
| --- | --- | --- | --- | --- | --- | --- |
| Render | Sí | No | Sí | Free 512 MB (duerme) | Alta | backend (recomendado) |
| Aiven | No | **Sí** | Sí | Free MySQL 1 GB | Media-Alta | base de datos |
| Railway | Sí | Sí | Sí | cambia; verificar | Alta | alternativa backend+DB |
| Fly.io | Sí | No | Sí | cambia; verificar | Media | alternativa con Dockerfile |
| Cloudflare R2 | No | No | Sí | 10 GB + egress libre (verificado hoy) | Media | storage (requiere cambio de código) |
| Koyeb | Sí | No | Sí | verificar | Media | alternativa backend económico |

---

## Fuentes oficiales

- Render: <https://render.com/pricing> · <https://render.com/docs/free>
- Aiven MySQL: <https://aiven.io/pricing/mysql> · <https://aiven.io/free-tier>
- Flutter (deployment/Android): <https://docs.flutter.dev/deployment/android>
- Google Cloud / OAuth: <https://developers.google.com/identity/sign-in/android>
- Google Maps: <https://mapsplatform.google.com/pricing/> ·
  <https://developers.google.com/maps/documentation/android-sdk>
- Cloudflare R2: <https://developers.cloudflare.com/r2/pricing/>
- Distribución: <https://docs.github.com/en/releases> ·
  <https://firebase.google.com/docs/app-distribution>
- Monitoreo: <https://uptimerobot.com> · <https://sentry.io> ·
  <https://betterstack.com>
- Oracle Cloud (Always Free): <https://www.oracle.com/cloud/free/>
- Google Play Console: <https://play.google.com/console>

> Nota final: los datos de Render y Aiven, y el free tier de Cloudflare R2, se
> verificaron hoy en las páginas oficiales. Google Maps cambió su modelo a
> suscripciones (con crédito de prueba de ~US$300 para clientes nuevos); las
> cifras de Oracle, Firebase, UptimeRobot, Sentry y Google Play deben
> confirmarse en sus páginas oficiales antes de decidir el plan definitivo.