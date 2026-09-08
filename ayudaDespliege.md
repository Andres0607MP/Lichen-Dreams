# ayudaDespliege.md — Despliegue de Lichen Dreams

> **Última verificación:** 08/09/2026
> Precios, planes gratuitos (free tiers), límites y políticas de los servicios
> externos cambian con frecuencia. Antes de comprometerte, verifica siempre en
> las páginas oficiales (sección “Fuentes oficiales”). Este documento es
> específico para el repositorio actual, no una guía genérica.

---

## 0. Qué se despliega

El sistema tiene estos componentes:

| Componente | Tecnología | Artefacto |
| --- | --- | --- |
| Backend | FastAPI (Python 3.12) | carpeta `backend/` |
| Base de datos | MySQL | esquema `lichen_dreams`, migraciones Alembic |
| IA | TensorFlow/Keras — modelo activo **V8** | `backend/ia/modelos/lichen_model_v8.keras` (~31 MB) |
| Frontend | Flutter (Android) | APK/AAB generado con `--dart-define=API_BASE_URL=...` |
| Storage | sistema de archivos del backend (`uploads/`) | imágenes de análisis, perfiles, artículos |
| Externos | Google Sign-In + Google Maps | cuentas en Google Cloud Console |

Puntos clave del proyecto que condicionan el despliegue:

1. El backend resuelve el modelo activo desde la BD (`modelos_ia` con
   `estado='activo'`). **Sin migraciones aplicadas no hay modelo resuelto.**
2. La primera inferencia carga TensorFlow: **necesita, en la práctica, más de
   512 MB de RAM** (el archivo pesa 31 MB, pero el runtime de TF suma; carga de
   modelo varios segundos). Esto limita los planes de RAM muy pequeña.
3. Las imágenes se guardan en el **filesystem del servidor** (`uploads/`). En
   muchos hosts el filesystem no es persistente o se pierde al redeployear.
4. La app es Android-first (Google Maps y Google Sign-In móvil).

---

## 1. Arquitectura recomendada

```text
Usuario (APK Android / web si se desea)
     │
     ├── Google Sign-In (OAuth, Google Cloud)
     ├── Google Maps (Maps SDK for Android + API key)
     │
     ▼  HTTPS (TLS automático del host)
     │
Backend FastAPI (uvicorn)  →  POST /ia/health, /api/test, etc.
     │
     ├── JWT (JWT_SECRET)
     ├── MySQL (Alembic migrations)
     ├── IA: lichen_model_v8.keras (TensorFlow, CPU)
     └── Archivos del proyecto → uploads/ (disco persistente o almacenamiento)
```

---

## 2. Opción de costo $0 (dígito inicial 0, con recordatorios honestos)

Combinación con la que se puede empezar sin pagar:

| Necesidad | Servicio | Qué da hoy |
| --- | --- | --- |
| Backend | **Render** — Free Web Service | $0; 512 MB RAM, 0.1 CPU; TLS automático; se duerme por inactividad (cold start); 5 GB/mes de ancho de banda (Hobby) |
| Base de datos | **Aiven MySQL — plan Free** | $0; 1 vCPU, 1 GB RAM, 1 GB de almacenamiento; región limitada (DigitalOcean/UpCloud); sin connection pooling |
| Almacenamiento | **Render Persistent Disk** | no es gratis (US$0.25/GB/mes) → la alternativa $0 real exige otro host o almacenamiento S3/R2 (revisar “Almacenamiento”) |
| Dominio/HTTPS | URL gratuita del host (`.onrender.com`) | TLS automático sin costo |
| Distribución Android | **GitHub Releases** (APK/AAB) | $0 |
| Monitoreo | Render logs + health checks (gratis) + **UptimeRobot** (free tier) | $0 |

**Advertencias honestas:**
- Render Free se **apaga tras inactividad** y el primer request demora (cold
  start). Para una demostración del instructor es aceptable; no es producción
  estable.
- **512 MB de RAM son insuficientes de margen** para TensorFlow: es probable
  que la primera predicción provoque OOM. Funcionará de forma intermitente.
  Con este plan, “IA funcionando” no está garantizado. Alternativa $0 para IA:
  compartir instancia de Oracle Cloud Always Free (validar disponibilidad y
  pedir tarjeta) con MySQL propio (MariaDB/MySQL) y disco de 200 GB.
- Aiven Free puede apagarse si el servicio queda **sin uso prolongado**, según
  la política de uso aceptable.
- Storage: si no usas disco persistente (pagado) ni almacenamiento objeto, las
  imágenes se pierden al volver a desplegar. La app “funciona” pero pierde
  fotos subidas.

---

## 3. Opción recomendada (equilibrio costo/estabilidad)

| Componente | Elección | Por qué |
| --- | --- | --- |
| Backend | **Render Web Service — Standard $25/mes** (2 GB RAM, 1 CPU) | RAM suficiente para TensorFlow; TLS; deploys desde Git; rollbacks |
| DB | **Aiven MySQL — Hobbyist $19/mes** (8 GB) o **Developer $5/mes** | MySQL real compatible con el código (sin cambios de motor) |
| Storage | **Render Persistent Disk** (US$0.25/GB) montado en `uploads/` | sin cambios de código (ver sección Almacenamiento) |
| Frontend | Google Play ($25 única, opcional) o GitHub Releases | — |
| Monitoreo | Render logs + UptimeRobot + (opcional) Sentry free | — |

Costo orientativo mínimo estable: **~US$30–45/mes** (backend + DB + disco).

---

## 4. Opción económica

- Backend: **Render Starter $7/mes** (512 MB) → arriesgado con TF; usar
  **Koyeb/Fly.io** solo si su free/eco tier actual cubre ≥1 GB (verifica en
  sus páginas; no cito cifras no verificadas).
- DB: **Aiven Developer MySQL $5/mes** (8 GB) o MySQL propio en VPS barato
  (Oracle/Vultr) con `mysqldump` manu.
- Storage: disco persistente pequeÃ±o (US$0.25/GB en Render) o nube objeto.
- Total típico económico: **~US$12–20/mes**.

---

## 5. Opción profesional (posterior)

- Backend en **AWS/GCP/Azure** (App Engine, Cloud Run, o VM con Docker) o un
  **VPS** (Ubuntu + systemd + Caddy/Nginx).
- MySQL gestionado del proveedor (RDS MySQL, Cloud SQL MySQL).
- Storage **S3-compatible** (R2, S3, GCS) para uploads (requiere un cambio de
  código acotado: ver “Almacenamiento”).
- CI/CD con GitHub Actions (build APK + test + deploy).
- Kubernetes: **solo si el tráfico lo justifica**; para este proyecto no
  aporta ahora.

---

## 6. Variables de entorno (tabla)

Fuente de verdad: `.env.example` (copia a `backend/.env` en local; en el host
se configuran como variables del servicio).

| Variable | Componente | Obligatoria | Ejemplo | Dónde obtenerla |
| --- | --- | --- | --- | --- |
| `DB_HOST` | backend | Sí | `mysql-...aivencloud.com` | Consola de tu MySQL |
| `DB_PORT` | backend | Sí | `3306` (o puerto del host) | Consola del proveedor |
| `DB_USER` | backend | Sí | `avnadmin` | Consola Aiven/MySQL |
| `DB_PASSWORD` | backend | Sí | `****` | Consola Aiven/MySQL |
| `DB_NAME` | backend | Sí | `defaultdb` | Consola Aiven/MySQL |
| `DATABASE_URL` | backend (opcional) | No | `mysql+pymysql://user:pass@host:3306/db` | Construida con los datos anteriores |
| `JWT_SECRET` | backend | Sí (cámbialo) | frase larga aleatoria | La generas tú |
| `JWT_ALGORITHM` | backend | No | `HS256` | Valor real del repo |
| `JWT_EXPIRE_HOURS` | backend | No | `24` | Valor real del repo |
| `API_HOST` / `API_PORT` | backend | No (usa `$PORT` del host) | `0.0.0.0` / `8000` | — |
| `BACKEND_URL` | backend | Sí | `https://lichendreams.onrender.com` | La URL pública final |
| `GOOGLE_CLIENT_ID` | backend | Sí para Google | `xxxx.apps.googleusercontent.com` | Google Cloud Console |
| `GOOGLE_MAPS_API_KEY` | backend | Sí para Maps | `AIza...` | Google Cloud Console |
| `SMTP_*` (5 vars) | backend | No (solo correo) | `smtp.gmail.com`… | Tu proveedor SMTP |
| `API_BASE_URL` | frontend | Sí en build | `https://tu-api.com` | Solo con `--dart-define` al compilar Flutter |

> Diferencia importante: el **backend** lee su `.env`/variables de entorno del
> servicio. El **frontend Flutter** NO lee `.env` en runtime: la URL se fija en
> el build con `--dart-define=API_BASE_URL=...`.

---

## 7. Desplegar el backend (Render, ejemplo concreto)

1. Sube este repositorio a GitHub y conecta Render (o usa Git Push).
2. **New → Web Service** → selecciona el repo (rama `develop`).
3. Root directory: `backend`.
4. Build: `pip install -r requirements.txt`
5. Start: `uvicorn main:app --host 0.0.0.0 --port $PORT`
6. Python version: 3.12.
7. Agrega todas las variables del §6 (Render genera `PORT` automáticamente).
8. **Pre-Deploy Command** (puede usarse): `alembic upgrade head`
   — en Render se configura en el servicio; si no lo soporta, ejecuta las
   migraciones una sola vez de forma manual (sección 8).
9. Health check (si se pide): ruta `/` o `/api/test` de tu backend.

Verificación:
```bash
curl https://TU-APP.onrender.com/api/test
curl https://TU-APP.onrender.com/ia/health   # requiere token admin (JWT)
```

> Las migraciones deben apuntar **siempre a la BD de producción**, nunca a tu
> BD local. Ejecútalas como paso explícito (pre-deploy o manual), no cada
> petición.

---

## 8. Base de datos MySQL y migraciones

```bash
# Local/CI para verificar migración
cd backend
alembic upgrade head
alembic current
```

- `alembic.ini` está en `backend/`; las migraciones en
  `backend/alembic/versions/` (incluyen `register_modelo_v8` y
  `activate_modelo_v8`).
- En el host: configura `DB_*`/`DATABASE_URL` y ejecuta
  `alembic upgrade head`. Si falla: revisa contraseña host/SSL
  (`mysql+pymysql` debe poder conectarse con SSL del proveedor) y que la BD
  exista.
- Comprobar el modelo activo tras migrar:

```sql
SELECT id_modelo, version, estado_modelo, observaciones
FROM lichen_dreams.modelos_ia;
-- se espera una fila version='v8.0' estado='activo'
```

Backup mínimo (manual):

```bash
mysqldump -h HOST -P PORT -u USER -p lichen_dreams > respaldo.sql
# Restaurar:  mysql -h HOST -u USER -p lichen_dreams < respaldo.sql
```

Verifica la política de backups de tu proveedor (Aiven Free tiene
capacidades limitadas; Render no gestiona MySQL).

---

## 9. IA en producción

- Modelo activo: **V8.0** · `backend/ia/modelos/lichen_model_v8.keras` ·
  3 clases (`liquen saludable`, `liquen contaminado`, `liquen desconocido`).
- Dependencias: TensorFlow/Keras en `requirements.txt`. No requiere GPU
  (usa CPU). RAM necesaria en la práctica: **apunta a ≥1 GB**; 512 MB es
  arriesgado (OOM en la primera predicción). Tiempo de carga del modelo en la
  primera inferencia: varios segundos.
- Comportamiento “desconocido”: no se persiste el análisis (mensaje al
  usuario); la inferencia sí queda en el monitoreo de IA.
- Si el hosting no soporta la IA, opciones: subir el plan a ≥1–2 GB de RAM, o
  mover la inferencia a un servicio dedicado (fuera de alcance actual, no
  implementado).

## 10. Almacenamiento de archivos (importante)

- El código guarda las imágenes en el filesystem en `backend/uploads/`
  (`uploads/articles`, `uploads/profiles/user_N`, `uploads/analyses/user_N`,
  etc.). En Render/Koyeb/Fly (filesystem efímero) esos archivos **se pierden
  al redeployear**.
- Opción sin cambio de código: montar un **Persistent Disk** del host en el
  mismo path (`upload-dir` → `backend/uploads`), o crear un symlink
  `backend/uploads` → disco montado.
- Opción a futuro (requiere cambio de código acotado en
  `backend/services/upload_service.py` + `/imagenes`): almacenamiento objeto
  S3-compatible (Cloudflare R2, AWS S3, GCS, Backblaze B2). Valida los free
  tiers actuales (por ejemplo, R2 tiene 10 GB gratuitos; confirma en su web).

## 11. HTTPS, dominio y DNS

- HTTPS inmediato: URL gratuita del host (`.onrender.com` con TLS automático).
- Dominio propio barato (registrarlo en un registrar; ~US$1–12/año) y
  delegar en **Cloudflare** (plan Free) con proxy (CNAME) hacia tu app:
  - Registro CNAME: `api` → `tu-backend.onrender.com` (proxied).
  - Render: Settings → Custom domains → `api.udominio.com` (emite su
    certificado).
- URL final: `https://api.udominio.com` → ajusta `BACKEND_URL` y el
  `--dart-define` del build.

## 12. CORS (estado real y producción)

El backend ya NO usa `allow_origins=["*"]`: usa
`allow_origin_regex=https?://(localhost|127.0.0.1|10.0.2.2)(:\d+)?`.
- **App Android:** CORS no aplica (no es navegador).
- **Web (Flutter Web) desplegada en un dominio:** amplía el regex en
  `backend/main.py` para incluir tu dominio, por ejemplo
  `https://lichen-dreams.pages.dev`. Ese cambio es de configuración, no
  funcional.

## 13. Google Sign-In en producción

1. Google Cloud Console → crea/abre el proyecto.
2. **OAuth consent screen**: tipo Externo (o Interno si aplica), datos del app.
3. **Web Client ID** → copia a `GOOGLE_CLIENT_ID` (backend). El backend valida
   el ID token con `google-auth` (`/auth/google`).
4. **Android Client ID**: en credenciales Android registra:
   - nombre del paquete (package name real de la app, ej.
     `com.example.lichendreams` según `frontend/android/app/build.gradle`),
   - **SHA-1 y SHA-256** de la firma de release y de depuración
     (`keytool -list -v -keystore ...`),
   - la config de cliente Android la consume el plugin `google_sign_in` en el
     frontend; el `google-services.json` **no debe subirse a Git**.
5. Diferencias dev/prod: en desarrollo puedes usar el emulador con el cliente
   Android de debug; en producción usa la firma de release y restringe
   OAuth Client IDs a las audiencias reales.
6. Si `GOOGLE_CLIENT_ID` queda vacío: Google Sign-In no está disponible; el
   login local sigue funcionando.

## 14. Google Maps en producción

1. Google Cloud Console → habilita **Maps SDK for Android** (y la que uses).
2. Crea una **API key** con restricciones:
   - Restricción por **Android app**: package name + SHA-1/SHA-256 de la
     firma de release (y de debug en desarrollo).
   - En backend: `GOOGLE_MAPS_API_KEY`.
3. Frontend: la clave de Maps de Android está en
   `frontend/android/app/src/main/AndroidManifest.xml`; en producción
   reemplázala por una clave restringida a tu paquete+firma.
4. **Billing**: Google Maps Platform requiere **facturación activada**; hoy
   otorga un **crédito mensual de uso gratuito** (del orden de US$200 en
   consumo de API, suficiente para decenas de miles de cargas/mes). Confirma
   el valor actual en la documentación oficial; con crédito puedes operar sin
   gasto real mientras no superes la cuota.
5. Sin clave: el mapa no se renderiza en dispositivo; el resto funciona.

## 15. Frontend Flutter — APK de producción

```bash
cd frontend
flutter pub get
# Emulador:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
# Dispositivo físico (IP local del PC):
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
adb reverse tcp:8000 tcp:8000   # opcional con USB
# Build de entrega apuntando a producción:
flutter build apk --dart-define=API_BASE_URL=https://api.udominio.com
flutter build appbundle --dart-define=API_BASE_URL=https://api.udominio.com
```

- **Firma**: crea un keystore (`keytool -genkey -v -keystore key.jks ...`),
  configura `frontend/android/key.properties` y el bloque `signingConfigs`
  del `build.gradle` (no subas `key.jks` ni `key.properties` a Git).
- Resultado: `build/app/outputs/flutter-apk/app-release.apk` (y `.aab`).

## 16. Publicación de la app sin pagar inicialmente

| Canal | Costo inicial | Ventajas | Desventajas |
| --- | --- | --- | --- |
| **GitHub Releases** (APK) | $0 | Instantáneo, enlace directo, ideal para evaluación | El usuario instala con “orígenes desconocidos” |
| **Firebase App Distribution** | $0 (plan Spark, verifica) | Beta con instalación sencilla por correo | Orientado a testers, no a Google Play |
| **Google Play** | $25 única para cuenta de desarrollador | Distribución real, autoactualización | Pago + revisión + políticas |

Para el entregable educativo: GitHub Releases (y opcionalmente App
Distribution) es la vía libre.

## 17. Seguridad (checklist de producción)

- [ ] `backend/.env` fuera de Git (el `.gitignore` ya lo cubre)
- [ ] `JWT_SECRET` cambiado por uno aleatorio largo
- [ ] HTTPS activado (host o Cloudflare)
- [ ] CORS restringido (ya está; amplía solo para tu dominio web)
- [ ] `GOOGLE_CLIENT_ID` / `GOOGLE_MAPS_API_KEY` reales y restringidas
- [ ] `key.jks`/`key.properties`/`google-services.json` NO en el repo
- [ ] Debug desactivado (uvicorn sin `--reload` en producción)
- [ ] BD no expuesta públicamente (firewall/IP allowlist del proveedor)
- [ ] Backups configurados (ver sección de BD)
- [ ] Permisos mínimos del usuario de la BD
- [ ] Logs revisables sin exponer secretos

Nota de seguridad real del código: los endpoints de imágenes ya protegidos
(BUG-001 corregido). Mantén la política de propiedad vigente.

## 18. Monitoreo

- **Render**: logs por servicio (7 días en Hobby), health checks, métricas de
  servicio. Rutas útiles: `/` y `/api/test`.
- **/ia/health** y **/ia/diagnostics** (solo admin) permiten verificar modelo y DB.
- **UptimeRobot** (free): verifica el endpoint `/` cada pocos minutos.
- Opcionales (verifica free tiers actuales): **Sentry** (errores de Python),
  **Better Stack** (uptime/logs), **Grafana Cloud** (métricas).

## 19. Actualizaciones y rollback

```text
git push (rama desplegada)
   ↓  auto-deploy del host
   ↓  (opcional) pre-deploy: alembic upgrade head
   ↓  verificación: /api/test + /ia/health + un análisis real
```

- Render mantiene varias builds para **rollback** instantáneo (Hobby: última
  build; valida tus límites).
- Si una migración nueva falla en prod, corrige en un migration
  `down_revision` y vuelve a desplegar; no hagas `git reset --hard`.

## 20. Problemas frecuentes

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| Backend no inicia | faltan variables / puerto | revisa `PORT`, `DB_*`, `JWT_SECRET`; logs del servicio |
| “No puedo conectarme a MySQL” | host/puerto incorrecto o firewall | usa datos exactos de la consola; abre acceso a la IP del backend |
| Migraciones fallan | credenciales/SSL de DB | verifica `DATABASE_URL`/`DB_*`; que la BD exista |
| 401 en /ia/* | falta token o no es admin | usa un usuario con rol admin y token JWT válido |
| Google Login falla | SHA-1/package incorrectos o Client ID distinto al frontend | registra paquete + hash reales; usa el mismo Client ID en backend |
| Mapa en blanco | Maps key sin restricción Android o billing | instala Maps SDK Android, restringe por paquete+SHA, revisa billing |
| APK no conecta | `API_BASE_URL` equivocada; usaste 10.0.2.2 para físico | usa IP local del PC o tu dominio HTTPS; `adb reverse` si aplica |
| Imágenes se pierden | filesystem efímero del host | disco persistente o almacenamiento S3/R2 |
| Primera predicción lenta/errónea | cold start y RAM baja de TF | sube RAM (≥1 GB) o acepta latencia de arranque |
| CORS en web | el regex no incluye tu dominio | amplía `allow_origin_regex` en `main.py` |
| “Modelo activo no encontrado” | migraciones no aplicadas | ejecuta `alembic upgrade head` contra producción |

## 21. Checklist final de producción

```text
[ ] Backend desplegado y con HTTPS
[ ] MySQL creado y accesible desde el backend
[ ] Alembic ejecutado contra producción (modelo v8.0 activo)
[ ] Variables configuradas (JWT_SECRET cambiado, GOOGLE_* reales)
[ ] CORS afinado para el dominio web (si usas web)
[ ] /api/test y /ia/health responden (con token admin para /ia/*)
[ ] Análisis de imagen real: clasificación, historial y mapa funcionan
[ ] Registro, login, recuperación y perfil funcionan
[ ] Google Sign-In y Google Maps validados en un dispositivo real
[ ] Uploads persistentes (disco o almacenamiento objeto)
[ ] Backups configurados (mysqldump / política del proveedor)
[ ] Monitoreo configurado (logs + UptimeRobot + opcional Sentry)
[ ] APK de release firmado con API_BASE_URL de producción
```

## 22. Tabla de costos aproximada (verificar siempre)

| Servicio | Opción gratuita | Límite típico | Costo posterior | Recomendación |
| --- | --- | --- | --- | --- |
| Render (backend) | Free $0 (512 MB) | duerme en inactividad; 5 GB/mes | Starter $7 → Standard $25 (2 GB) | Standard si IA estable |
| Aiven MySQL | Free $0 (1 GB almacenamiento) | 1 vCPU/1 GB RAM; puede apagarse sin uso | Developer $5 (8 GB) | Developer o Hobbyist |
| Disco persistente (Render) | no | — | US$0.25/GB/mes | recomendado para uploads |
| Cloudflare (dominio/DNS) | Free | DNS+proxy+TLS | — | recomendado |
| UptimeRobot | Free | checks básicos | plan básico opcional | suficiente |
| Google Maps | crédito mensual de uso | requiere billing | si superas el crédito | usar con restricciones |
| Google Sign-In | gratis | — | — | — |
| GitHub Releases | gratis | — | — | distribución educativa |

## 23. Tabla de proveedores

| Proveedor | Backend | MySQL | HTTPS | Free tier real | Facilidad | Recomendación |
| --- | --- | --- | --- | --- | --- | --- |
| Render | Sí | No gestiona MySQL | Sí (auto) | Web gratuito 512 MB (duerme) | Alta | recomendado para backend (o paga por RAM) |
| Railway | Sí | Sí (plugin) | Sí | cambia con frecuencia; verifica | Alta | alternativa si el free tier actual cubre ≥1 GB y MySQL |
| Fly.io | Sí | No | Sí | cambia con frecuencia; verifica | Media | si quieres despliegue por Dockerfile |
| Koyeb | Sí | No | Sí | free tier limitado; verifica | Media | alternativa de backend económico |
| Aiven | No (solo datos) | **Sí MySQL** | Sí | **Free MySQL 1 GB** | Media-Alta | **elegido para DB** |
| Cloudflare (R2) | No | No | Sí | ~10 GB gratuitos (verifica) | Media | storage objeto (requiere cambio de código) |
| Oracle Cloud | VM | instalable tú | No incluido | “Always Free” (valida) | Baja | $0 con MySQL propio y RAM alta (24 GB ARM) sin expirar |

## Fuentes oficiales

- Backend: <https://render.com/pricing> · <https://render.com/docs/free>
- DB: <https://aiven.io/pricing/mysql> · <https://aiven.io/free-tier>
- Flutter: <https://docs.flutter.dev/deployment/android> · <https://docs.flutter.dev/deployment>
- Google Cloud / OAuth: <https://cloud.google.com/docs/authentication> ·
  <https://developers.google.com/identity/sign-in/android>
- Google Maps: <https://developers.google.com/maps/documentation/android-sdk>
  · <https://cloud.google.com/maps-platform/pricing>
- Distribución: <https://docs.github.com/en/releases> ·
  <https://firebase.google.com/docs/app-distribution>
- Monitoreo: <https://uptimerobot.com> · <https://sentry.io> ·
  <https://betterstack.com>
- Almacenamiento: <https://developers.cloudflare.com/r2/> ·
  <https://aws.amazon.com/s3/pricing/>

> Recuerda: precios y free tiers cambian. Todo lo que no pude verificar en
> esta revisión está marcado como “verifica en la web oficial”.