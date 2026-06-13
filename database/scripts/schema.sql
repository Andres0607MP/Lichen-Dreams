CREATE DATABASE IF NOT EXISTS lichen_dreams;
USE lichen_dreams;

-- ROLES
CREATE TABLE roles (
    id_rol INT AUTO_INCREMENT PRIMARY KEY,
    nombre_rol VARCHAR(50) NOT NULL,
    descripcion TEXT,
    nivel_acceso INT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- USUARIOS
CREATE TABLE usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100),
    apellido VARCHAR(100),
    tipo_documento VARCHAR(20),
    numero_documento VARCHAR(50),
    correo VARCHAR(150) UNIQUE,
    contrasena VARCHAR(255),
    telefono VARCHAR(20),
    foto_perfil LONGTEXT,
    fecha_nacimiento DATE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso TIMESTAMP NULL DEFAULT NULL,
    estado_cuenta VARCHAR(50),
    id_rol INT,
    FOREIGN KEY (id_rol) REFERENCES roles(id_rol)
);

-- SESIONES
CREATE TABLE sesiones (
    id_sesion INT AUTO_INCREMENT PRIMARY KEY,
    token_sesion TEXT,
    dispositivo VARCHAR(100),
    sistema_operativo VARCHAR(100), 
    ip_usuario VARCHAR(50),
    fecha_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion TIMESTAMP NULL DEFAULT NULL,
    estado_sesion VARCHAR(50),
    id_usuario INT,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

-- MODELOS IA
CREATE TABLE modelos_ia (
    id_modelo INT AUTO_INCREMENT PRIMARY KEY,
    nombre_modelo VARCHAR(100),
    version VARCHAR(50),
    tipo_modelo VARCHAR(100),
    descripcion TEXT,
    precision_modelo FLOAT,
    dataset_utilizado VARCHAR(255),
    fecha_entrenamiento DATE,
    fecha_actualizacion TIMESTAMP NULL DEFAULT NULL,
    estado_modelo VARCHAR(50),
    observaciones TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DATASETS
CREATE TABLE datasets (
    id_dataset INT AUTO_INCREMENT PRIMARY KEY,
    nombre_dataset VARCHAR(100),
    descripcion TEXT,
    cantidad_imagenes INT,
    ruta_archivo TEXT,
    tipo_datos VARCHAR(50),
    fuente_dataset VARCHAR(255),
    estado_dataset VARCHAR(50),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ESPECIES LIQUENES
CREATE TABLE especies_liquenes (
    id_especie INT AUTO_INCREMENT PRIMARY KEY,
    nombre_cientifico VARCHAR(100),
    nombre_comun VARCHAR(100),
    descripcion TEXT,
    color_predominante VARCHAR(50),
    tipo_crecimiento VARCHAR(50),
    nivel_tolerancia_contaminacion VARCHAR(100),
    indicador_calidad_aire VARCHAR(255),
    habitat VARCHAR(100),
    imagen_referencia LONGTEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- UBICACIONES
CREATE TABLE ubicaciones (
    id_ubicacion INT AUTO_INCREMENT PRIMARY KEY,
    latitud DECIMAL(10,8),
    longitud DECIMAL(11,8),
    direccion TEXT,
    municipio VARCHAR(100),
    departamento VARCHAR(100),
    pais VARCHAR(100),
    altitud FLOAT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ANALISIS
CREATE TABLE analisis (
    id_analisis INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT,
    id_modelo INT,
    id_dataset INT,
    id_especie INT,
    id_ubicacion INT,
    resultado_ia TEXT,
    porcentaje_confianza FLOAT,
    nivel_contaminacion VARCHAR(50),
    calidad_aire VARCHAR(50),
    estado_liquen VARCHAR(100),
    tiempo_procesamiento FLOAT,
    observaciones TEXT,
    estado_validacion VARCHAR(50),
    temperatura_ambiente FLOAT,
    humedad_relativa FLOAT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (id_modelo) REFERENCES modelos_ia(id_modelo),
    FOREIGN KEY (id_dataset) REFERENCES datasets(id_dataset),
    FOREIGN KEY (id_especie) REFERENCES especies_liquenes(id_especie),
    FOREIGN KEY (id_ubicacion) REFERENCES ubicaciones(id_ubicacion)
);

-- IMAGENES
CREATE TABLE imagenes (
    id_imagen INT AUTO_INCREMENT PRIMARY KEY,
    id_analisis INT,
    nombre_imagen VARCHAR(255),
    ruta_imagen TEXT,
    url TEXT,
    formato_imagen VARCHAR(20),
    tamano_archivo INT,
    resolucion VARCHAR(50),
    fecha_subida TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    imagen_original LONGBLOB,
    imagen_procesada LONGBLOB,
    estado_imagen VARCHAR(50),
    tipo_captura VARCHAR(50),
    descripcion TEXT,
    FOREIGN KEY (id_analisis) REFERENCES analisis(id_analisis)
);

-- PROCESAMIENTO IA
CREATE TABLE procesamiento_ia (
    id_procesamiento INT AUTO_INCREMENT PRIMARY KEY,
    id_analisis INT,
    tiempo_ejecucion FLOAT,
    porcentaje_precision FLOAT,
    precision_modelo FLOAT,
    cantidad_objetos_detectados INT,
    resultado_segmentacion TEXT,
    observaciones TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_analisis) REFERENCES analisis(id_analisis)
);

-- ZONAS AMBIENTALES
CREATE TABLE zonas_ambientales (
    id_zona INT AUTO_INCREMENT PRIMARY KEY,
    nombre_zona VARCHAR(100),
    nivel_riesgo VARCHAR(50),
    calidad_promedio_aire VARCHAR(50),
    descripcion TEXT,
    fecha_actualizacion TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP
);

-- REPORTES
CREATE TABLE reportes (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(100),
    descripcion TEXT,
    tipo_reporte VARCHAR(50),
    formato_reporte VARCHAR(50),
    estado_reporte VARCHAR(50),
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    id_usuario INT,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

-- HISTORIAL
CREATE TABLE historial_actividad (
    id_historial INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT,
    accion_realizada VARCHAR(255),
    descripcion_accion TEXT,
    dispositivo VARCHAR(100),
    ip_usuario VARCHAR(50),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

-- NOTIFICACIONES
CREATE TABLE notificaciones (
    id_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT,
    titulo VARCHAR(100),
    mensaje TEXT,
    tipo_notificacion VARCHAR(50),
    estado_notificacion VARCHAR(50),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

-- LIQUENPEDIA
CREATE TABLE liquenpedia (
    id_articulo INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(150),
    contenido TEXT,
    autor VARCHAR(100),
    categoria VARCHAR(100),
    imagen_articulo LONGTEXT,
    estado_publicacion VARCHAR(50),
    fecha_publicacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP
);

-- MODELO - DATASET
CREATE TABLE modelo_dataset (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_modelo INT,
    id_dataset INT,
    fecha_asociacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_modelo) REFERENCES modelos_ia(id_modelo),
    FOREIGN KEY (id_dataset) REFERENCES datasets(id_dataset)
);