# 📌 ISSUES - DIVISIÓN DE TRABAJO (2 Personas)

**Tú**: Persona 1 (Backend Infrastructure)  
**Compañero**: Persona 2 (API REST)

---

## 👤 PERSONA 1 (Tú) - Backend Infrastructure

### ✅ ISSUE #1: Mejorar Modelos SQLAlchemy
**Archivo**: `backend/models/core.py`  
**Duración**: 2-3 horas  
**Estado**: 🟡 No iniciado

#### Tareas:
- [ ] Modelo `Usuario`: agregar `estado_activo`, `fecha_actualizacion`, validar `correo` unique
- [ ] Modelo `Sesion`: agregar `fecha_vencimiento`
- [ ] Modelo `Analisis`: agregar campo `estado` (pending, processing, completed, failed)
- [ ] Modelo `Imagen`: agregar `ruta_original`, `ruta_procesada`
- [ ] Modelo `Ubicacion`: agregar validación de coordenadas (latitud: -90 a 90, longitud: -180 a 180)
- [ ] Modelo `LiquenPedia`: agregar `estado_publicacion`, `fecha_actualizacion`
- [ ] Agregar índices en campos de búsqueda frecuente
- [ ] Agregar relaciones bidireccionales con `backref`

#### Checkpoints:
```python
# Test: Deben importar sin errores
from models.core import Usuario, Sesion, Analisis, Imagen, Ubicacion, LiquenPedia
```

---

### ✅ ISSUE #2: Crear Validaciones Pydantic
**Archivo**: `backend/models/validations.py` (CREAR NUEVO)  
**Duración**: 4-5 horas  
**Estado**: 🟡 No iniciado

#### Tareas:
- [ ] `UsuarioCreate`, `UsuarioUpdate`, `UsuarioResponse`
- [ ] `UbicacionCreate`, `UbicacionResponse`
- [ ] `AnalisisCreate`, `AnalisisResponse`
- [ ] `ArticuloCreate`, `ArticuloUpdate`, `ArticuloResponse`
- [ ] `DatasetCreate`, `DatasetResponse`
- [ ] `ModeloIACreate`, `ModeloIAResponse`

#### Validaciones específicas:
- Email: `EmailStr` + validar único en BD
- Contraseña: mín 8 chars, mayúscula, número
- Teléfono: regex `^\+?1?\d{9,15}$`
- Latitud: `-90` a `90`
- Longitud: `-180` a `180`
- Versión: regex semver `^\d+\.\d+\.\d+$`

#### Checkpoints:
```python
# Test: Deben importar sin errores
from models.validations import UsuarioCreate, UbicacionCreate, AnalisisCreate
```

---

### ✅ ISSUE #3: Migraciones con Alembic
**Archivos**: `backend/alembic/versions/*.py`  
**Duración**: 2-3 horas  
**Estado**: 🟡 No iniciado

#### Tareas:
```bash
cd backend
alembic revision --autogenerate -m "Add validation constraints and fields"
alembic upgrade head
```

- [ ] Migration 001: Agregar columnas (estado_activo, fecha_actualizacion, etc)
- [ ] Migration 002: Agregar índices
- [ ] Migration 003: Agregar constraints (unique, check)
- [ ] Migration 004: Agregar relaciones bidireccionales
- [ ] Migration 005: Agregar JSON metadata

#### Checkpoints:
```bash
# Verificar estado
alembic current  # Debe mostrar última versión
```

---

### ✅ ISSUE #4: Tests Unitarios de Modelos
**Archivo**: `backend/tests/test_models.py` (CREAR NUEVO)  
**Duración**: 4-5 horas  
**Estado**: 🟡 No iniciado

#### Tareas:
- [ ] `TestUsuarioModel`: crear, email único, timestamps
- [ ] `TestUbicacionModel`: coordenadas válidas/inválidas
- [ ] `TestRelacionesModelos`: FK correctas
- [ ] `TestValidaciones`: email, teléfono, versión semver

#### Comando para ejecutar:
```bash
cd backend
pytest tests/test_models.py -v
```

#### Checkpoints:
```bash
# Deben pasar todos los tests
pytest tests/test_models.py -v  # ✅ 100% pass
```

---

### ✅ ISSUE #5: Documentar Esquema BD
**Archivo**: `docs/database-schema.md` (CREAR NUEVO)  
**Duración**: 1-2 horas  
**Estado**: 🟡 No iniciado

#### Tareas:
- [ ] Crear tabla con: nombre tabla, campos, tipos, constraints
- [ ] Documentar relaciones (FK)
- [ ] Documentar índices
- [ ] Crear diagrama ER (ASCII o referencia)
- [ ] Incluir ejemplos de queries comunes

#### Contenido mínimo:
```markdown
# Esquema de Base de Datos

## Tabla: USUARIO
| Campo | Tipo | Constraint | Descripción |
|-------|------|-----------|-------------|
| id_usuario | INT | PK AUTO_INCREMENT | ID único |
| nombre | VARCHAR(100) | NOT NULL | Nombre |
| correo | VARCHAR(150) | UNIQUE NOT NULL | Email único |
| ...

## Relaciones
- Usuario (1) ─── (N) Sesion
- Usuario (1) ─── (N) Analisis
- Rol (1) ─── (N) Usuario
```

---

## 👥 PERSONA 2 - API REST Implementation

### ✅ ISSUE #1: Endpoints de Usuarios (CRUD + Admin)
**Archivo**: `backend/routes/users.py`  
**Duración**: 1 día  
**Bloqueador**: Espera a Persona 1 (ISSUE #1-2)

#### Endpoints:
```
GET    /api/users              → Listar usuarios (admin only)
GET    /api/users/{id}         → Obtener usuario (admin only)
PUT    /api/users/{id}         → Actualizar usuario (admin only)
DELETE /api/users/{id}         → Eliminar usuario (admin only, soft delete)
```

#### Validaciones:
- Admin only: `if current_user.rol.nombre_rol != 'admin': raise HTTPException(403)`
- Email duplicado: `raise HTTPException(409, "Email ya existe")`
- No encontrado: `raise HTTPException(404, "Usuario no encontrado")`

---

### ✅ ISSUE #2: Endpoints de Análisis (CRUD)
**Archivo**: `backend/routes/analisis.py`  
**Duración**: 2 días  
**Bloqueador**: Espera a Persona 1 (ISSUE #1-2)

#### Endpoints:
```
POST   /api/analysis/upload    → Subir imagen (validar formato/tamaño)
POST   /api/analysis/process   → Procesar análisis con IA
GET    /api/analysis/{id}      → Obtener análisis (propietario/admin)
DELETE /api/analysis/{id}      → Eliminar análisis (propietario/admin)
```

#### Validaciones:
- Propietario O Admin: `if (analisis.id_usuario != current_user.id_usuario and current_user.rol.nombre_rol != 'admin'): raise HTTPException(403)`
- Formatos válidos: jpg, jpeg, png
- Tamaño máximo: 50MB

---

### ✅ ISSUE #3: Endpoints de LiquenPedia (CRUD + Admin)
**Archivo**: `backend/routes/liquenpedia.py`  
**Duración**: 1 día  
**Bloqueador**: Espera a Persona 1 (ISSUE #1-2)

#### Endpoints:
```
GET    /api/liquenpedia                   → Listar artículos (público)
POST   /api/liquenpedia                   → Crear artículo (admin only)
PUT    /api/liquenpedia/{id}              → Actualizar artículo (admin only)
DELETE /api/liquenpedia/{id}              → Eliminar artículo (admin only)
```

#### Funcionalidades:
- Búsqueda por título, contenido, categoría
- Paginación (skip, limit)

---

### ✅ ISSUE #4: Endpoints de Datasets & Modelos IA
**Archivos**: `backend/routes/datasets.py`, `backend/routes/modelos.py`  
**Duración**: 1.5 días  
**Bloqueador**: Espera a Persona 1 (ISSUE #1-2)

#### Endpoints:
```
GET    /api/datasets              → Listar datasets (público)
POST   /api/datasets              → Crear dataset (admin only)
PUT    /api/datasets/{id}         → Actualizar dataset (admin only)
DELETE /api/datasets/{id}         → Eliminar dataset (admin only)

GET    /api/modelos               → Listar modelos IA (público)
POST   /api/modelos               → Crear modelo IA (admin only)
PUT    /api/modelos/{id}          → Actualizar modelo IA (admin only)
DELETE /api/modelos/{id}          → Eliminar modelo IA (admin only)
```

---

### ✅ ISSUE #5: Tests de Integración
**Archivo**: `backend/tests/test_endpoints.py` (CREAR NUEVO)  
**Duración**: 1.5 días  
**Bloqueador**: Espera a Persona 1 + ISSUE #1-4

#### Tests:
- `TestUsuariosEndpoints`: listar, crear, actualizar, eliminar, permisos
- `TestAnalisisEndpoints`: upload, process, obtener, eliminar, permisos
- `TestLiquenpediaEndpoints`: listar, crear, actualizar, eliminar, permisos
- `TestDatasetModelos`: CRUD, permisos

#### Comando para ejecutar:
```bash
cd backend
pytest tests/test_endpoints.py -v
```

---

### ✅ ISSUE #6: Documentación OpenAPI
**Archivo**: `docs/apis/endpoints.md` (CREAR/ACTUALIZAR)  
**Duración**: 1 día  
**Bloqueador**: Espera a Persona 1 + ISSUE #1-5

#### Tareas:
- [ ] Documentar todos los endpoints
- [ ] Status codes: 200, 201, 204, 400, 403, 404, 409
- [ ] Request/Response examples
- [ ] Swagger disponible en `/docs`

---

## 📊 Timeline

```
SEMANA 1:

LUN-MAR (Persona 1):
├─ ISSUE #1: Mejorar modelos      (2-3h)
├─ ISSUE #2: Validaciones Pydantic (4-5h)
├─ ISSUE #3: Migraciones Alembic  (2-3h)
├─ ISSUE #4: Tests unitarios      (4-5h)
└─ ISSUE #5: Documentación        (1-2h)
└─ ✅ ENTREGA: Modelos completos + BD lista

MIÉ-VIE (Persona 2):
├─ ISSUE #1: Endpoints usuarios   (1 día)
├─ ISSUE #2: Endpoints análisis   (2 días)
├─ ISSUE #3: Endpoints liquenpedia (1 día)
├─ ISSUE #4: Endpoints datasets   (1.5 días)
├─ ISSUE #5: Tests integración    (1.5 días)
└─ ISSUE #6: Documentación        (1 día)
└─ ✅ ENTREGA: API REST completa
```

---

## 🚀 Cómo Empezar (Persona 1 - TÚ)

```bash
# 1. Clona el repo (si no lo hiciste)
git clone https://github.com/Andres0607MP/Lichen-Dreams.git
cd Lichen-Dreams

# 2. Activa venv
.\.venv\Scripts\Activate.ps1

# 3. Ve al backend
cd backend

# 4. Revisa archivo actual
code models/core.py

# 5. Crea rama de trabajo
git checkout -b feat/mejorar-modelos

# 6. Empieza con ISSUE #1
# Modifica models/core.py según tareas checklist

# 7. Commit cuando termines una tarea
git add models/core.py
git commit -m "[ISSUE #1] Mejorar modelos SQLAlchemy - agregar campos validacion"

# 8. Cuando termines TODO (5 issues):
git push origin feat/mejorar-modelos
# Crear Pull Request en GitHub
```

---

## ✅ Checklist Final (Persona 1)

Antes de avisar a Persona 2 que puede empezar:

- [ ] ISSUE #1: Modelos mejorados sin errores
- [ ] ISSUE #2: `from models.validations import *` sin errores
- [ ] ISSUE #3: `alembic current` muestra última versión
- [ ] ISSUE #4: `pytest tests/test_models.py -v` → 100% pass ✅
- [ ] ISSUE #5: Documentación en `docs/database-schema.md`
- [ ] PR aprobado y mergeado a `main`
- [ ] Avisa a Persona 2: **"✅ Modelos listos, puedes empezar"**

---

## 🔗 Conexión entre Personas

Persona 2 **NO PUEDE empezar** hasta que Persona 1 complete:
- ISSUE #1 (Modelos mejorados)
- ISSUE #2 (Validaciones Pydantic)
- ISSUE #3 (Migraciones ejecutadas)

Una vez eso esté hecho, Persona 2 puede hacer:
- ISSUE #1-6 en paralelo (o secuencial)

---

## 💬 Comunicación

**Daily Standup (15 min)**:
- ¿Qué completé?
- ¿En qué estoy?
- ¿Hay bloqueadores?

**Si hay problema**:
1. Avisa en el standup
2. Crear issue en GitHub
3. Code review en PR

---

**Versión**: 1.0  
**Fecha**: 2026-06-11  
**Estado**: Ready ✅
