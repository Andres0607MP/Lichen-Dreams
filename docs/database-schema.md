# Esquema de Base de Datos

Este documento describe las tablas principales, sus campos, constraints, índices y relaciones.

## Tablas principales

### roles
- id_rol: INT, PK, AUTOINCREMENT
- nombre_rol: VARCHAR(50), NOT NULL, UNIQUE
- descripcion: TEXT, NULL
- nivel_acceso: INT, DEFAULT 1
- fecha_creacion: TIMESTAMP, DEFAULT now()
- Índices: `idx_nombre_rol`, `idx_nivel_acceso`

### usuarios
- id_usuario: INT, PK, AUTOINCREMENT
- nombre: VARCHAR(100), NOT NULL
- apellido: VARCHAR(100), NOT NULL
- correo: VARCHAR(150), UNIQUE, NOT NULL
- contrasena: VARCHAR(255), NOT NULL
- telefono: VARCHAR(20), NULL
- fecha_registro: TIMESTAMP, DEFAULT now()
- fecha_actualizacion: DATETIME, ON UPDATE CURRENT_TIMESTAMP
- estado_activo: BOOLEAN, DEFAULT TRUE
- id_rol: INT, FK -> `roles.id_rol`, NOT NULL
- Índices: `idx_correo`, `idx_estado_activo`

### sesiones
- id_sesion: INT, PK, AUTOINCREMENT
- token_sesion: TEXT, NOT NULL
- dispositivo: VARCHAR(100), NULL
- ip_usuario: VARCHAR(50), NULL
- fecha_inicio: TIMESTAMP, DEFAULT now()
- fecha_vencimiento: DATETIME, NULL
- estado_sesion: VARCHAR(50), DEFAULT 'active'
- id_usuario: INT, FK -> `usuarios.id_usuario`, NOT NULL
- Índices: `idx_token_sesion`, `idx_estado_sesion`

### modelos_ia
- id_modelo: INT, PK, AUTOINCREMENT
- nombre_modelo: VARCHAR(100), NOT NULL
- version: VARCHAR(50), NOT NULL  -- semver X.Y.Z recomendado
- descripcion: TEXT
- fecha_creacion: TIMESTAMP, DEFAULT now()
- Índices: `idx_nombre_modelo`

### datasets
- id_dataset: INT, PK, AUTOINCREMENT
- nombre_dataset: VARCHAR(100), NOT NULL
- ruta_archivo: TEXT, NOT NULL
- tipo_datos: VARCHAR(50)
- fecha_creacion: TIMESTAMP, DEFAULT now()
- Índices: `idx_nombre_dataset`

### analisis
- id_analisis: INT, PK, AUTOINCREMENT
- id_usuario: INT, FK -> `usuarios.id_usuario`, NOT NULL
- id_modelo: INT, FK -> `modelos_ia.id_modelo`, NOT NULL
- id_dataset: INT, FK -> `datasets.id_dataset`, NULL
- resultado: TEXT / JSON (según uso)
- estado: VARCHAR(50), DEFAULT 'pending'
- metadata_resultado: JSON, NULL
- fecha_creacion: TIMESTAMP, DEFAULT now()
- fecha_actualizacion: DATETIME, ON UPDATE CURRENT_TIMESTAMP
- Índices: `idx_id_usuario`, `idx_estado`, `idx_fecha_creacion`

### imagenes
- id_imagen: INT, PK, AUTOINCREMENT
- id_analisis: INT, FK -> `analisis.id_analisis`, NOT NULL
- url: TEXT
- ruta_original: TEXT
- ruta_procesada: TEXT
- descripcion: TEXT
- fecha_creacion: TIMESTAMP, DEFAULT now()
- Índices: `idx_id_analisis`

### ubicaciones
- id_ubicacion: INT, PK, AUTOINCREMENT
- latitud: DECIMAL(10,8), NOT NULL
- longitud: DECIMAL(11,8), NOT NULL
- direccion: TEXT, NOT NULL
- municipio: VARCHAR(100), NOT NULL
- departamento: VARCHAR(100), NOT NULL
- pais: VARCHAR(100), DEFAULT 'Colombia'
- fecha_registro: TIMESTAMP, DEFAULT now()
- Constraints: `check_latitud_rango` (latitud entre -90 y 90), `check_longitud_rango` (longitud entre -180 y 180)
- Índices: `idx_municipio`, `idx_departamento`

### liquenpedia
- id_articulo: INT, PK, AUTOINCREMENT
- titulo: VARCHAR(150), NOT NULL
- contenido: TEXT, NOT NULL
- autor: VARCHAR(100), NOT NULL
- categoria: VARCHAR(100), NOT NULL
- estado_publicacion: VARCHAR(50), DEFAULT 'draft'
- fecha_publicacion: TIMESTAMP, DEFAULT now()
- fecha_actualizacion: DATETIME, ON UPDATE CURRENT_TIMESTAMP
- Índices: `idx_categoria`, `idx_estado_publicacion`


## Relaciones
- `roles (1)` ─── (`N`) `usuarios` via `usuarios.id_rol` → `roles.id_rol`
- `usuarios (1)` ─── (`N`) `sesiones` via `sesiones.id_usuario` → `usuarios.id_usuario`
- `usuarios (1)` ─── (`N`) `analisis` via `analisis.id_usuario` → `usuarios.id_usuario`
- `modelos_ia (1)` ─── (`N`) `analisis` via `analisis.id_modelo` → `modelos_ia.id_modelo`
- `datasets (1)` ─── (`N`) `analisis` via `analisis.id_dataset` → `datasets.id_dataset`
- `analisis (1)` ─── (`N`) `imagenes` via `imagenes.id_analisis` → `analisis.id_analisis`

## Índices y performance
- Los índices principales están definidos en `__table_args__` para consultas por correo, estado y fechas.
- Para consultas geoespaciales simples se usan los campos `latitud`/`longitud` con `DECIMAL`; para consultas avanzadas considerar PostGIS.

## Ejemplos de consultas comunes
- Obtener análisis de un usuario con imágenes:

```sql
SELECT a.*, i.*
FROM analisis a
LEFT JOIN imagenes i ON i.id_analisis = a.id_analisis
WHERE a.id_usuario = :user_id
ORDER BY a.fecha_creacion DESC;
```

- Buscar usuario por correo (índice `idx_correo`):

```sql
SELECT * FROM usuarios WHERE correo = 'usuario@example.com';
```

- Contar análisis por estado:

```sql
SELECT estado, COUNT(*) as total FROM analisis GROUP BY estado;
```

## Diagrama ER (simple ASCII)

roles (1)───< usuarios (N) >───(1)modelos_ia
                │
                ├───< sesiones (N)
                └───< analisis (N) >───(N) imagenes
                              │
                              └───< datasets (1)


## Notas
- Muchos campos usan `TIMESTAMP` con `server_default=func.now()` y `DateTime` con `onupdate` para control de auditoría.
- Validaciones de entrada deben garantizar semver en `modelos_ia.version` y rangos en `ubicaciones` (Pydantic y DB checks duplican seguridad).

