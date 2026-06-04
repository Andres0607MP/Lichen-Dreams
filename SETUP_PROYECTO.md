# 🚀 GUÍA DE CONFIGURACIÓN Y EJECUCIÓN - LICHEN DREAMS

## Estado Actual del Proyecto
✅ Backend: Configurado con FastAPI, SQLAlchemy, JWT  
✅ Frontend: Flutter con API Service mejorado  
✅ BD: Schema definido, listo para crear  
✅ Dependencias: requirements.txt actualizado con PyMySQL  
✅ Variables de entorno: JWT_SECRET generado y configurado  

---

## 📋 PASOS PREVIOS (Una sola vez)

### 1️⃣ Verificar que tienes instalado:
```powershell
# Python 3.8+
python --version

# MySQL (necesario para la BD)
mysql --version

# Flutter y Dart (para el frontend)
flutter --version
```

Si falta algo, instálalo antes de continuar.

---

### 2️⃣ Crear la Base de Datos MySQL

Abre **MySQL Workbench** o **MySQL Command Line Client** y ejecuta:

```sql
CREATE DATABASE IF NOT EXISTS lichen_dreams CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE lichen_dreams;

-- Luego copia y pega TODO el contenido de:
-- C:\Users\mance\Documents\Steffi\Lichen-Dreams\database\scripts\schema.sql
```

**O desde PowerShell (si MySQL está en PATH):**
```powershell
mysql -u root -p lichen_dreams < "C:\Users\mance\Documents\Steffi\Lichen-Dreams\database\scripts\schema.sql"
```

**IMPORTANTE:** Si tienes contraseña en MySQL, actualiza en `backend/.env`:
```
DB_PASSWORD=tu_contraseña_aqui
DB_USER=root
```

---

### 3️⃣ Instalar dependencias del Backend

```powershell
cd C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend

# Crear virtual environment
python -m venv venv

# Activar virtual environment (Windows PowerShell)
.\venv\Scripts\Activate.ps1

# Si tienes permisos restringidos, ejecuta primero:
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Instalar dependencias
pip install -r requirements.txt
```

---

### 4️⃣ Instalar dependencias del Frontend

```powershell
cd C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend

# Descargar/actualizar dependencias
flutter pub get
```

---

## 🎯 EJECUTAR EL PROYECTO

### **PASO 1: Iniciar Backend (Terminal 1 - PowerShell)**

```powershell
cd C:\Users\mance\Documents\Steffi\Lichen-Dreams\backend

# Activar virtual environment
.\venv\Scripts\Activate.ps1

# Ejecutar servidor
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

**Esperado:**
```
INFO:     Uvicorn running on http://127.0.0.1:8000
```

✅ Verifica en navegador: http://127.0.0.1:8000/docs (Swagger UI)

---

### **PASO 2: Iniciar Frontend (Terminal 2 - PowerShell o bash)**

```powershell
cd C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend

# Ejecutar en un emulador o dispositivo
flutter run
```

**Si quieres emulador específico:**
```powershell
# Ver dispositivos disponibles
flutter devices

# Ejecutar en dispositivo específico
flutter run -d <device-id>
```

---

## 🧪 VERIFICAR CONEXIÓN BACKEND-FRONTEND

### En la app Flutter:
1. Va a la pantalla **Login**
2. Debería mostrar el estado de conexión
3. Si ves "Backend conectado" ✅ está funcionando

---

## 🔐 Configuración de Variables de Entorno

### Backend (`.env` - YA CONFIGURADO):
```
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=          ← Cambiar si tu MySQL tiene contraseña
DB_NAME=lichen_dreams

JWT_SECRET=oU2cwqb0IODuEf3BTN5hW697xJpCSVsaYFAz4drMkH8nGRgtlmQP1jyLKiZevX
JWT_ALGORITHM=HS256
JWT_EXPIRATION_HOURS=24

GOOGLE_MAPS_API_KEY=  ← Opcional: Agregar si usas mapas
```

---

## 📱 Credenciales de Prueba

Primero **ejecuta el seed (si existe)**:

```powershell
cd backend
python scripts/seed.py
```

Si el seed no existe, crea un usuario manualmente via API:

**POST** `http://127.0.0.1:8000/auth/register`
```json
{
  "nombre": "Test",
  "apellido": "User",
  "email": "test@example.com",
  "password": "Test123!@"
}
```

---

## ✅ CHECKLIST DE VERIFICACIÓN

Marca cada una que funcione:

- [ ] MySQL corriendo en localhost:3306
- [ ] Base de datos `lichen_dreams` creada con tablas
- [ ] Backend ejecutándose en http://127.0.0.1:8000
- [ ] Swagger UI visible en http://127.0.0.1:8000/docs
- [ ] Frontend compilando sin errores
- [ ] App Flutter se abre sin crashes
- [ ] Login muestra "Backend conectado"
- [ ] Puedes hacer login con usuario de prueba
- [ ] Token se guarda y se mantiene sesión

---

## 🆘 SOLUCIÓN DE PROBLEMAS

### ❌ "mysql: comando no encontrado"
**Solución:** Agrega MySQL al PATH o usa MySQL Workbench para ejecutar schema.sql

### ❌ "Connection refused: localhost:3306"
**Solución:** 
- Verifica que MySQL está corriendo
- En Windows: Abre Services y busca MySQL
- `mysql -u root -p` para verificar acceso

### ❌ "ModuleNotFoundError: No module named 'pymysql'"
**Solución:**
```powershell
cd backend
.\venv\Scripts\Activate.ps1
pip install pymysql==1.1.0
```

### ❌ "Connection refused: 127.0.0.1:8000"
**Solución:**
- Verifica que el backend está corriendo
- Usa http://10.0.2.2:8000 si estás en emulador Android

### ❌ Flutter no conecta con backend
**Solución:**
- Si usas emulador Android: cambia URL a `http://10.0.2.2:8000`
- En física/iOS: usa la IP local `http://192.168.x.x:8000`
- Verifica firewall de Windows

### ❌ "Bad state: Cannot send headers, response already started"
**Solución:** Reinicia el servidor backend

---

## 📊 ENDPOINTS PRINCIPALES DEL BACKEND

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/` | Verificar servicio activo |
| POST | `/auth/login` | Login de usuario |
| POST | `/auth/register` | Registro nuevo usuario |
| POST | `/auth/refresh` | Refrescar token JWT |
| POST | `/auth/logout` | Cerrar sesión |
| GET | `/users/me` | Obtener datos del usuario actual |
| POST | `/analysis` | Crear análisis de imagen |
| GET | `/history` | Ver historial de análisis |

---

## 🎨 ESTRUCTURA DEL PROYECTO

```
Lichen-Dreams/
├── backend/              (FastAPI + Python)
│   ├── .env             (Configuración - NO SUBIR a Git)
│   ├── main.py          (Servidor principal)
│   ├── requirements.txt  (Dependencias)
│   ├── routes/          (Endpoints)
│   ├── models/          (BD Models)
│   └── auth/            (Autenticación)
│
├── frontend/            (Flutter)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── routes/
│   │   ├── screens/
│   │   └── services/    (API Service)
│   └── pubspec.yaml
│
├── database/            (Scripts SQL)
│   └── scripts/schema.sql
│
└── docs/                (Documentación)
```

---

## 🚀 PRÓXIMOS PASOS DESPUÉS DE FUNCIONAL

1. ✅ Hacer login con usuario de prueba
2. Completar pantalla de análisis de imágenes
3. Integrar Google Maps API para ubicaciones
4. Entrenar modelo de IA con dataset de líquenes
5. Implementar subida de imágenes
6. Crear pantalla de Liquenpedia

---

## 📞 CONTACTO / PROBLEMAS

Si algo no funciona:
1. Revisa los logs del backend: `http://127.0.0.1:8000/docs`
2. Revisa la consola del Flutter: `flutter run -v`
3. Verifica la BD: `mysql -u root -p lichen_dreams -e "SHOW TABLES;"`

---

**Última actualización:** 3 de Junio de 2026  
**Estado:** Proyecto funcional para desarrollar  
**Próxima revisión:** Después de completar Sprint 1
