CREATE TABLE roles (
    id_rol INT AUTO_INCREMENT PRIMARY KEY,
    nombre_rol VARCHAR(50) NOT NULL,
    descripcion TEXT,
    nivel_acceso INT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100),
    apellido VARCHAR(100),
    correo VARCHAR(150) UNIQUE,
    contraseña VARCHAR(255),
    telefono VARCHAR(20),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado_cuenta VARCHAR(50),
    id_rol INT,
    FOREIGN KEY (id_rol) REFERENCES roles(id_rol)
);

CREATE TABLE sesiones (
    id_sesion INT AUTO_INCREMENT PRIMARY KEY,
    token_sesion TEXT,
    dispositivo VARCHAR(100),
    ip_usuario VARCHAR(50),
    fecha_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado_sesion VARCHAR(50),
    id_usuario INT,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

CREATE TABLE modelos_ia (
    id_modelo INT AUTO_INCREMENT PRIMARY KEY,
    nombre_modelo VARCHAR(100),
    version VARCHAR(50),
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE datasets (
    id_dataset INT AUTO_INCREMENT PRIMARY KEY,
    nombre_dataset VARCHAR(100),
    ruta_archivo TEXT,
    tipo_datos VARCHAR(50),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE analisis (
    id_analisis INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT,
    id_modelo INT,
    id_dataset INT,
    resultado TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (id_modelo) REFERENCES modelos_ia(id_modelo),
    FOREIGN KEY (id_dataset) REFERENCES datasets(id_dataset)
);

CREATE TABLE imagenes (
    id_imagen INT AUTO_INCREMENT PRIMARY KEY,
    id_analisis INT,
    url TEXT,
    descripcion TEXT,
    FOREIGN KEY (id_analisis) REFERENCES analisis(id_analisis)
);

CREATE TABLE especies_liquenes (
    id_especie INT AUTO_INCREMENT PRIMARY KEY,
    nombre_cientifico VARCHAR(100),
    nombre_comun VARCHAR(100),
    descripcion TEXT,
    color_predominante VARCHAR(50),
    tipo_crecimiento VARCHAR(50),
    habitat VARCHAR(100),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ubicaciones (
    id_ubicacion INT AUTO_INCREMENT PRIMARY KEY,
    latitud DECIMAL(10,8),
    longitud DECIMAL(11,8),
    direccion TEXT,
    municipio VARCHAR(100),
    departamento VARCHAR(100),
    pais VARCHAR(100),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE procesamiento_ia (
    id_procesamiento INT AUTO_INCREMENT PRIMARY KEY,
    id_analisis INT,
    tiempo_ejecucion FLOAT,
    precision_modelo FLOAT,
    observaciones TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_analisis) REFERENCES analisis(id_analisis)
);

CREATE TABLE zonas_ambientales (
    id_zona INT AUTO_INCREMENT PRIMARY KEY,
    nombre_zona VARCHAR(100),
    nivel_riesgo VARCHAR(50),
    descripcion TEXT,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE reportes (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(100),
    descripcion TEXT,
    tipo_reporte VARCHAR(50),
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    id_usuario INT,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

CREATE TABLE historial_actividad (
    id_historial INT AUTO_INCREMENT PRIMARY KEY,
    accion VARCHAR(100),
    descripcion TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    id_usuario INT,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

CREATE TABLE notificaciones (
    id_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(100),
    mensaje TEXT,
    estado VARCHAR(50),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    id_usuario INT,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

CREATE TABLE liquenpedia (
    id_articulo INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(150),
    contenido TEXT,
    autor VARCHAR(100),
    categoria VARCHAR(100),
    fecha_publicacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE modelo_dataset (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_modelo INT,
    id_dataset INT,
    fecha_asociacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_modelo) REFERENCES modelos_ia(id_modelo),
    FOREIGN KEY (id_dataset) REFERENCES datasets(id_dataset)
);
