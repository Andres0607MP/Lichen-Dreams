# 🚀 Flujo Completo de Ejecución - Lichen Dreams

## 📋 Requisitos Previos
- Git instalado
- Python 3.11+ instalado
- Flutter/Dart instalado
- MySQL/MariaDB corriendo localmente
- VS Code o editor de código

---

## 1️⃣ Clonar el Repositorio

```bash
git clone https://github.com/tu-usuario/Lichen-Dreams.git
cd Lichen-Dreams
```

---

## 2️⃣ Cambiar a Rama Develop

```bash
git switch develop
```

O si prefieres la forma antigua:
```bash
git checkout develop
```

---

## 3️⃣ Configurar Variables de Entorno

### En la raíz del proyecto, crear `.env`:

```bash
# Frontend
FLUTTER_API_BASE_URL=http://127.0.0.1:8000

# Backend
DB_USER=root
DB_PASSWORD=tu_contraseña
DB_HOST=localhost
DB_PORT=3306
DB_NAME=lichen_dreams
```

---

## 🎯 FLUJO DE EJECUCIÓN (2 Terminales)

### **TERMINAL 1: Backend (FastAPI)**

```bash
# 1. Ir a carpeta backend
cd backend

# 2. Crear environment virtual (si no existe)
python -m venv .venv

# 3. Activar environment
# Windows:
.venv\Scripts\activate

# macOS/Linux:
source .venv/bin/activate

# 4. Instalar dependencias
pip install -r requirements.txt

# 5. Ejecutar migraciones (opcional, si es primera vez)
python -m alembic upgrade head

# 6. INICIAR SERVIDOR
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

**Salida esperada:**
```
Conexion exitosa a la base de datos
INFO:     Uvicorn running on http://127.0.0.1:8000
```

✅ Backend está listo en `http://127.0.0.1:8000`

---

### **TERMINAL 2: Frontend (Flutter)**

```bash
# 1. Ir a carpeta frontend
cd frontend

# 2. Obtener dependencias
flutter pub get

# 3. Ejecutar en Chrome (desarrollo)
flutter run -d chrome

# O en Android Emulator:
flutter run -d emulator-5554

# O en iOS (macOS):
flutter run -d iphone
```

**Salida esperada:**
```
flutter run key commands.
r Hot reload.
R Hot restart.
h List all available interactive commands.
```

✅ Frontend está listo

---

## 📱 Probar la Aplicación

### **Desde el navegador (Chrome):**
- URL: `http://localhost:XXXX` (Flutter asigna puerto automáticamente)
- Ver consola del navegador para debug

### **Endpoint de Salud (API):**
```bash
curl http://127.0.0.1:8000/
```

### **Login Test:**
```bash
curl -X POST http://127.0.0.1:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"password123"}'
```

---

## 🔄 Flujo Rápido (Resumen)

```
┌─────────────────────────────────────┐
│  CLONAR + SETUP                     │
├─────────────────────────────────────┤
│ git clone <repo>                    │
│ cd Lichen-Dreams                    │
│ git switch develop                  │
└─────────────────────────────────────┘
                 ↓
         ┌───────────────────┐
         │ ABRIR 2 TERMINALES│
         └───────────────────┘
              ↙           ↖
    ┌──────────────┐   ┌──────────────┐
    │  TERMINAL 1  │   │  TERMINAL 2  │
    │   BACKEND    │   │   FRONTEND   │
    ├──────────────┤   ├──────────────┤
    │ cd backend   │   │ cd frontend  │
    │ .venv\Act..  │   │ flutter pub  │
    │ pip install  │   │ flutter run  │
    │ uvicorn ...  │   │ -d chrome    │
    │              │   │              │
    │ :8000 ✅     │   │ :XXXX ✅     │
    └──────────────┘   └──────────────┘
```

---

## 🛠️ Comandos Útiles

### **Backend**
```bash
# Ver logs en tiempo real
uvicorn main:app --reload --log-level debug

# Ejecutar tests
pytest tests/

# Reset BD (cuidado!)
python scripts/seed.py
```

### **Frontend**
```bash
# Hot reload (aplicar cambios sin reiniciar)
# Presiona: r

# Hot restart (reiniciar app)
# Presiona: R

# Limpiar build
flutter clean

# Compilar APK (Android)
flutter build apk

# Compilar Web
flutter build web
```

---

## ❌ Solución de Problemas

### Backend no inicia
```bash
# Verificar conexión a BD
mysql -u root -p lichen_dreams

# Reinstalar dependencias
pip install --upgrade pip
pip install -r requirements.txt --force-reinstall
```

### Flutter pub get falla
```bash
flutter clean
flutter pub get
```

### Puerto 8000 en uso
```bash
# Cambiar puerto
uvicorn main:app --port 8001
```

### Base de datos no existe
```bash
mysql -u root -p < database/scripts/schema.sql
```

---

## ✅ Verificación Final

| Componente | Estado | URL |
|-----------|--------|-----|
| Backend API | ✅ Running | http://127.0.0.1:8000 |
| Base de Datos | ✅ Connected | localhost:3306 |
| Frontend | ✅ Running | http://localhost:XXXX |
| Swagger (API Docs) | ✅ Available | http://127.0.0.1:8000/docs |

---

## 🎓 Estructura de Carpetas

```
Lichen-Dreams/
├── backend/                    # FastAPI + SQLAlchemy
│   ├── .venv/                 # Environment virtual
│   ├── main.py               # Entrada principal
│   ├── requirements.txt       # Dependencias Python
│   ├── alembic/              # Migraciones BD
│   ├── config/               # Configuración
│   ├── models/               # Modelos ORM
│   ├── routes/               # Endpoints API
│   ├── auth/                 # Autenticación
│   └── ia/                   # Lógica IA
│
├── frontend/                  # Flutter/Dart
│   ├── lib/
│   │   ├── main.dart        # Entrada principal
│   │   ├── screens/         # Pantallas
│   │   ├── services/        # Servicios (API, etc)
│   │   ├── models/          # Modelos Dart
│   │   └── widgets/         # Componentes
│   ├── pubspec.yaml         # Dependencias Flutter
│   └── build/               # Archivos generados
│
├── database/
│   └── scripts/
│       └── schema.sql       # Script creación BD
│
├── docs/                     # Documentación
└── flujo.md                 # Este archivo
```

---

## 🚦 Checklist de Inicio Rápido

- [ ] Git clone completado
- [ ] `git switch develop`
- [ ] Variables de entorno configuradas (`.env`)
- [ ] **Terminal 1**: Backend iniciado (`:8000`)
- [ ] **Terminal 2**: Frontend iniciado (Flutter)
- [ ] Navegador muestra la app
- [ ] Login test exitoso
- [ ] Base de datos conectada

---

**¡Listo! Ya está todo corriendo. 🎉**
