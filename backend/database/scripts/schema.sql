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

create table modelos_ia (
id_modelo INT AUTO_INCREMENT PRIMARY KEY,
    nombre_modelo VARCHAR(100),
    version VARCHAR(50),
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

create table datasets (id_dataset INT AUTO_INCREMENT PRIMARY KEY,
    nombre_dataset VARCHAR(100),
    ruta_archivo TEXT,
    tipo_datos VARCHAR(50),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

create table analisis (id_analisis INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT,
    id_modelo INT,
    id_dataset INT,
    resultado TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (id_modelo) REFERENCES modelos_ia(id_modelo),
    FOREIGN KEY (id_dataset) REFERENCES datasets(id_dataset)
);

create table imagenes (id_imagen INT AUTO_INCREMENT PRIMARY KEY,
    id_analisis INT,
    url TEXT,
    descripcion TEXT,

    FOREIGN KEY (id_analisis) REFERENCES analisis(id_analisis)
);