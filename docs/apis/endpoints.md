# 📚 Documentación API REST - Lichen Dreams

## Información General

- **Base URL**: `http://localhost:8000`
- **Documentación Interactiva (Swagger)**: `http://localhost:8000/docs`
- **Documentación Alternativa (ReDoc)**: `http://localhost:8000/redoc`
- **Versión API**: 1.0.0
- **Formato**: JSON

---

## 🔐 Autenticación

Todos los endpoints marcados con 🔒 requieren autenticación mediante JWT.

```
Authorization: Bearer <token>
```

---

## 👥 USUARIOS

### GET /api/users
**Descripción**: Listar todos los usuarios (admin only)

**Autenticación**: 🔒 Admin required

**Query Parameters**:
- `skip` (integer, default: 0): Número de registros a saltar
- `limit` (integer, default: 100): Número máximo de registros

**Response 200 OK**:
```json
[
  {
    "id_usuario": 1,
    "nombre": "John",
    "apellido": "Doe",
    "correo": "john@example.com",
    "telefono": "+57300000000",
    "estado_cuenta": "activo",
    "id_rol": 1
  }
]
```

**Response 403 Forbidden**:
```json
{
  "detail": "Solo administradores pueden acceder a este recurso"
}
```

---

### GET /api/users/{user_id}
**Descripción**: Obtener un usuario por ID (admin only)

**Autenticación**: 🔒 Admin required

**Path Parameters**:
- `user_id` (integer): ID del usuario

**Response 200 OK**:
```json
{
  "id_usuario": 1,
  "nombre": "John",
  "apellido": "Doe",
  "correo": "john@example.com",
  "telefono": "+57300000000",
  "estado_cuenta": "activo",
  "id_rol": 1
}
```

**Response 404 Not Found**:
```json
{
  "detail": "Usuario no encontrado"
}
```

---

### PUT /api/users/{user_id}
**Descripción**: Actualizar un usuario (admin only)

**Autenticación**: 🔒 Admin required

**Path Parameters**:
- `user_id` (integer): ID del usuario

**Request Body**:
```json
{
  "nombre": "Jane",
  "apellido": "Doe",
  "correo": "jane@example.com",
  "telefono": "+57300000001",
  "id_rol": 2
}
```

**Response 200 OK**:
```json
{
  "id_usuario": 1,
  "nombre": "Jane",
  "apellido": "Doe",
  "correo": "jane@example.com",
  "telefono": "+57300000001",
  "estado_cuenta": "activo",
  "id_rol": 2
}
```

**Response 404 Not Found**:
```json
{
  "detail": "Usuario no encontrado"
}
```

**Response 409 Conflict**:
```json
{
  "detail": "Email ya existe"
}
```

---

### DELETE /api/users/{user_id}
**Descripción**: Eliminar un usuario (soft delete - admin only)

**Autenticación**: 🔒 Admin required

**Path Parameters**:
- `user_id` (integer): ID del usuario

**Response 204 No Content**: Sin contenido

**Response 404 Not Found**:
```json
{
  "detail": "Usuario no encontrado"
}
```

---

## 📊 ANÁLISIS

### POST /api/analysis/upload
**Descripción**: Subir imagen para análisis

**Autenticación**: 🔒 Token required

**Request Body**: `multipart/form-data`
- `file` (file): Archivo de imagen (jpg, jpeg, png, máximo 50MB)

**Response 200 OK**:
```json
{
  "filename": "lichen_sample.jpg",
  "size": 2048576,
  "upload_time": "2026-06-11T10:30:00",
  "file_path": "backend/uploads/1_lichen_sample.jpg"
}
```

**Response 400 Bad Request**:
```json
{
  "detail": "Formato no permitido. Formatos válidos: jpg, jpeg, png"
}
```

---

### POST /api/analysis/process
**Descripción**: Procesar análisis con IA

**Autenticación**: 🔒 Token required

**Query Parameters**:
- `id_modelo` (integer, optional): ID del modelo IA
- `id_dataset` (integer, optional): ID del dataset
- `resultado` (string, optional): Resultado del análisis

**Response 200 OK**:
```json
{
  "id_analisis": 1,
  "id_usuario": 1,
  "id_modelo": 1,
  "id_dataset": null,
  "resultado": "liquen saludable",
  "fecha": "2026-06-11T10:35:00"
}
```

**Response 400 Bad Request**:
```json
{
  "detail": "Modelo IA no encontrado"
}
```

---

### GET /api/analysis/{analysis_id}
**Descripción**: Obtener análisis (propietario o admin)

**Autenticación**: 🔒 Token required

**Path Parameters**:
- `analysis_id` (integer): ID del análisis

**Response 200 OK**:
```json
{
  "id_analisis": 1,
  "id_usuario": 1,
  "id_modelo": 1,
  "id_dataset": null,
  "resultado": "liquen saludable",
  "fecha": "2026-06-11T10:35:00",
  "imagenes": [
    {
      "id_imagen": 1,
      "id_analisis": 1,
      "url": "http://example.com/image.jpg",
      "descripcion": "Muestra del liquen"
    }
  ]
}
```

**Response 403 Forbidden**:
```json
{
  "detail": "No tienes permiso para acceder a este análisis"
}
```

**Response 404 Not Found**:
```json
{
  "detail": "Análisis no encontrado"
}
```

---

### DELETE /api/analysis/{analysis_id}
**Descripción**: Eliminar análisis (propietario o admin)

**Autenticación**: 🔒 Token required

**Path Parameters**:
- `analysis_id` (integer): ID del análisis

**Response 204 No Content**: Sin contenido

**Response 403 Forbidden**:
```json
{
  "detail": "No tienes permiso para acceder a este análisis"
}
```

**Response 404 Not Found**:
```json
{
  "detail": "Análisis no encontrado"
}
```

---

## 📖 LIQUENPEDIA

### GET /liquenpedia
**Descripción**: Listar artículos (público)

**Autenticación**: No requerida

**Query Parameters**:
- `skip` (integer, default: 0): Número de registros a saltar
- `limit` (integer, default: 100): Número máximo de registros
- `titulo` (string, optional): Buscar por título (búsqueda parcial)
- `contenido` (string, optional): Buscar por contenido (búsqueda parcial)
- `categoria` (string, optional): Filtrar por categoría

**Response 200 OK**:
```json
[
  {
    "id_articulo": 1,
    "titulo": "Líquenes como indicadores ambientales",
    "contenido": "Los líquenes son excelentes bioindicadores...",
    "autor": "Dr. Smith",
    "categoria": "Ecología",
    "fecha_publicacion": "2026-06-01T08:00:00"
  }
]
```

---

### POST /liquenpedia
**Descripción**: Crear artículo (admin only)

**Autenticación**: 🔒 Admin required

**Request Body**:
```json
{
  "titulo": "Nuevo artículo",
  "contenido": "Contenido del artículo...",
  "autor": "Dr. Author",
  "categoria": "Biología"
}
```

**Response 201 Created**:
```json
{
  "id_articulo": 2,
  "titulo": "Nuevo artículo",
  "contenido": "Contenido del artículo...",
  "autor": "Dr. Author",
  "categoria": "Biología",
  "fecha_publicacion": "2026-06-11T10:40:00"
}
```

---

### GET /liquenpedia/{article_id}
**Descripción**: Obtener artículo por ID (público)

**Autenticación**: No requerida

**Path Parameters**:
- `article_id` (integer): ID del artículo

**Response 200 OK**:
```json
{
  "id_articulo": 1,
  "titulo": "Líquenes como indicadores ambientales",
  "contenido": "Los líquenes son excelentes bioindicadores...",
  "autor": "Dr. Smith",
  "categoria": "Ecología",
  "fecha_publicacion": "2026-06-01T08:00:00"
}
```

**Response 404 Not Found**:
```json
{
  "detail": "Artículo no encontrado"
}
```

---

### PUT /liquenpedia/{article_id}
**Descripción**: Actualizar artículo (admin only)

**Autenticación**: 🔒 Admin required

**Request Body**:
```json
{
  "titulo": "Título actualizado",
  "contenido": "Contenido actualizado...",
  "autor": "Dr. Updated Author",
  "categoria": "Ecología Avanzada"
}
```

**Response 200 OK**:
```json
{
  "id_articulo": 1,
  "titulo": "Título actualizado",
  "contenido": "Contenido actualizado...",
  "autor": "Dr. Updated Author",
  "categoria": "Ecología Avanzada",
  "fecha_publicacion": "2026-06-01T08:00:00"
}
```

---

### DELETE /liquenpedia/{article_id}
**Descripción**: Eliminar artículo (admin only)

**Autenticación**: 🔒 Admin required

**Response 204 No Content**: Sin contenido

---

## 📦 DATASETS

### GET /datasets
**Descripción**: Listar datasets (público)

**Autenticación**: No requerida

**Query Parameters**:
- `skip` (integer, default: 0): Número de registros a saltar
- `limit` (integer, default: 100): Número máximo de registros

**Response 200 OK**:
```json
[
  {
    "id_dataset": 1,
    "nombre_dataset": "Lichenometry Data 2024",
    "ruta_archivo": "/data/datasets/lichen_2024.csv",
    "tipo_datos": "CSV",
    "fecha_creacion": "2026-05-01T09:00:00"
  }
]
```

---

### POST /datasets
**Descripción**: Crear dataset (admin only)

**Autenticación**: 🔒 Admin required

**Request Body**:
```json
{
  "nombre_dataset": "Nuevo Dataset",
  "ruta_archivo": "/data/new_dataset.csv",
  "tipo_datos": "CSV"
}
```

**Response 201 Created**:
```json
{
  "id_dataset": 2,
  "nombre_dataset": "Nuevo Dataset",
  "ruta_archivo": "/data/new_dataset.csv",
  "tipo_datos": "CSV",
  "fecha_creacion": "2026-06-11T10:45:00"
}
```

---

### GET /datasets/{dataset_id}
**Descripción**: Obtener dataset por ID (público)

**Response 200 OK**:
```json
{
  "id_dataset": 1,
  "nombre_dataset": "Lichenometry Data 2024",
  "ruta_archivo": "/data/datasets/lichen_2024.csv",
  "tipo_datos": "CSV",
  "fecha_creacion": "2026-05-01T09:00:00"
}
```

---

### PUT /datasets/{dataset_id}
**Descripción**: Actualizar dataset (admin only)

**Autenticación**: 🔒 Admin required

**Request Body**:
```json
{
  "nombre_dataset": "Dataset Actualizado"
}
```

**Response 200 OK**: Dataset actualizado

---

### DELETE /datasets/{dataset_id}
**Descripción**: Eliminar dataset (admin only)

**Response 204 No Content**: Sin contenido

---

## 🤖 MODELOS IA

### GET /modelos
**Descripción**: Listar modelos IA (público)

**Autenticación**: No requerida

**Query Parameters**:
- `skip` (integer, default: 0): Número de registros a saltar
- `limit` (integer, default: 100): Número máximo de registros

**Response 200 OK**:
```json
[
  {
    "id_modelo": 1,
    "nombre_modelo": "CNN Lichen Classifier v1",
    "version": "1.0.0",
    "descripcion": "Modelo de clasificación de líquenes basado en CNN",
    "fecha_creacion": "2026-04-15T10:00:00"
  }
]
```

---

### POST /modelos
**Descripción**: Crear modelo IA (admin only)

**Autenticación**: 🔒 Admin required

**Request Body**:
```json
{
  "nombre_modelo": "Nuevo Modelo",
  "version": "2.0.0",
  "descripcion": "Descripción del modelo"
}
```

**Response 201 Created**:
```json
{
  "id_modelo": 2,
  "nombre_modelo": "Nuevo Modelo",
  "version": "2.0.0",
  "descripcion": "Descripción del modelo",
  "fecha_creacion": "2026-06-11T10:50:00"
}
```

---

### GET /modelos/{model_id}
**Descripción**: Obtener modelo IA por ID (público)

**Response 200 OK**:
```json
{
  "id_modelo": 1,
  "nombre_modelo": "CNN Lichen Classifier v1",
  "version": "1.0.0",
  "descripcion": "Modelo de clasificación de líquenes basado en CNN",
  "fecha_creacion": "2026-04-15T10:00:00"
}
```

---

### PUT /modelos/{model_id}
**Descripción**: Actualizar modelo IA (admin only)

**Autenticación**: 🔒 Admin required

**Request Body**:
```json
{
  "version": "1.1.0"
}
```

**Response 200 OK**: Modelo actualizado

---

### DELETE /modelos/{model_id}
**Descripción**: Eliminar modelo IA (admin only)

**Response 204 No Content**: Sin contenido

---

## 📊 Códigos de Estado HTTP

| Código | Significado | Uso |
|--------|------------|-----|
| **200** | OK | GET exitoso, actualización exitosa |
| **201** | Created | POST exitoso (nuevo recurso creado) |
| **204** | No Content | DELETE exitoso, sin respuesta |
| **400** | Bad Request | Datos inválidos o formato incorrecto |
| **403** | Forbidden | Acceso denegado (permisos insuficientes) |
| **404** | Not Found | Recurso no encontrado |
| **409** | Conflict | Conflicto (ej: email duplicado) |
| **500** | Internal Server Error | Error del servidor |

---

## 🔍 Ejemplos de Uso

### Ejemplo 1: Listar usuarios (admin)
```bash
curl -X GET "http://localhost:8000/api/users" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "accept: application/json"
```

### Ejemplo 2: Subir imagen
```bash
curl -X POST "http://localhost:8000/api/analysis/upload" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@lichen_sample.jpg"
```

### Ejemplo 3: Buscar artículos
```bash
curl -X GET "http://localhost:8000/liquenpedia?titulo=Lichen&categoria=Ecologia" \
  -H "accept: application/json"
```

---

## 📝 Notas Importantes

- Todos los endpoints con 🔒 requieren token JWT válido
- El token debe ser incluido en el header `Authorization: Bearer <token>`
- Las búsquedas son **case-insensitive**
- La paginación usa parámetros `skip` y `limit`
- El soft delete marca usuarios como "eliminado" sin borrarlos de BD
- Las imágenes máximo 50MB en formatos: jpg, jpeg, png

---

## 🚀 Ejecutar Tests

```bash
cd backend
pytest tests/test_endpoints.py -v
```

---

## 📚 Documentación Interactiva

Accede a la documentación interactiva de Swagger en:
```
http://localhost:8000/docs
```

O en ReDoc:
```
http://localhost:8000/redoc
```

---

*Última actualización: 2026-06-11*
*Versión: 1.0.0*
