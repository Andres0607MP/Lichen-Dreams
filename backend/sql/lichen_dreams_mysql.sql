-- Script SQL puro para MySQL/XAMPP basado en backend/models/core.py
-- Compatible con MariaDB/MySQL de XAMPP

CREATE DATABASE IF NOT EXISTS lichen_dreams
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE lichen_dreams;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS sesiones;
DROP TABLE IF EXISTS imagenes;
DROP TABLE IF EXISTS analisis;
DROP TABLE IF EXISTS datasets;
DROP TABLE IF EXISTS modelos_ia;
DROP TABLE IF EXISTS liquenpedia;
DROP TABLE IF EXISTS ubicaciones;
DROP TABLE IF EXISTS usuarios;
DROP TABLE IF EXISTS roles;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE roles (
    id_rol INT AUTO_INCREMENT PRIMARY KEY,
    nombre_rol VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT NULL,
    nivel_acceso INT DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_nombre_rol (nombre_rol),
    INDEX idx_nivel_acceso (nivel_acceso)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NULL,
    apellido VARCHAR(100) NULL,
    tipo_documento VARCHAR(20) NULL,
    numero_documento VARCHAR(50) NULL,
    correo VARCHAR(150) NULL UNIQUE,
    contrasena VARCHAR(255) NULL,
    telefono VARCHAR(20) NULL,
    foto_perfil TEXT NULL,
    fecha_nacimiento DATETIME NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso TIMESTAMP NULL,
    estado_cuenta VARCHAR(50) DEFAULT 'activo',
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    id_rol INT NULL,
    CONSTRAINT fk_usuarios_roles FOREIGN KEY (id_rol) REFERENCES roles(id_rol),
    INDEX idx_correo (correo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sesiones (
    id_sesion INT AUTO_INCREMENT PRIMARY KEY,
    token_sesion TEXT NULL,
    dispositivo VARCHAR(100) NULL,
    sistema_operativo VARCHAR(100) NULL,
    ip_usuario VARCHAR(50) NULL,
    fecha_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion TIMESTAMP NULL,
    estado_sesion VARCHAR(50) NULL,
    id_usuario INT NULL,
    CONSTRAINT fk_sesiones_usuarios FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    INDEX idx_token_sesion (token_sesion(255)),
    INDEX idx_estado_sesion (estado_sesion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE modelos_ia (
    id_modelo INT AUTO_INCREMENT PRIMARY KEY,
    nombre_modelo VARCHAR(100) NOT NULL,
    version VARCHAR(50) NOT NULL,
    descripcion TEXT NULL,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_nombre_modelo (nombre_modelo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE datasets (
    id_dataset INT AUTO_INCREMENT PRIMARY KEY,
    nombre_dataset VARCHAR(100) NOT NULL,
    ruta_archivo TEXT NOT NULL,
    tipo_datos VARCHAR(50) NULL,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_nombre_dataset (nombre_dataset)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE analisis (
    id_analisis INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    id_modelo INT NULL,
    id_dataset INT NULL,
    resultado TEXT NULL,
    estado VARCHAR(50) DEFAULT 'pending',
    humedad FLOAT NULL,
    calidad_del_aire VARCHAR(100) NULL,
    recomendacion TEXT NULL,
    metadata_resultado JSON NULL,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_analisis_usuarios FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    CONSTRAINT fk_analisis_modelos FOREIGN KEY (id_modelo) REFERENCES modelos_ia(id_modelo),
    CONSTRAINT fk_analisis_datasets FOREIGN KEY (id_dataset) REFERENCES datasets(id_dataset),
    INDEX idx_id_usuario (id_usuario),
    INDEX idx_estado (estado),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE imagenes (
    id_imagen INT AUTO_INCREMENT PRIMARY KEY,
    id_analisis INT NOT NULL,
    url TEXT NULL,
    nombre VARCHAR(255) NULL,
    ruta_original TEXT NULL,
    ruta_procesada TEXT NULL,
    descripcion TEXT NULL,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_imagenes_analisis FOREIGN KEY (id_analisis) REFERENCES analisis(id_analisis),
    INDEX idx_id_analisis (id_analisis)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ubicaciones (
    id_ubicacion INT AUTO_INCREMENT PRIMARY KEY,
    latitud DECIMAL(10,8) NOT NULL,
    longitud DECIMAL(11,8) NOT NULL,
    direccion TEXT NOT NULL,
    municipio VARCHAR(100) NOT NULL,
    departamento VARCHAR(100) NOT NULL,
    pais VARCHAR(100) DEFAULT 'Colombia',
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_latitud_rango CHECK (latitud >= -90 AND latitud <= 90),
    CONSTRAINT chk_longitud_rango CHECK (longitud >= -180 AND longitud <= 180),
    INDEX idx_municipio (municipio),
    INDEX idx_departamento (departamento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE liquenpedia (
    id_articulo INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    contenido TEXT NOT NULL,
    autor VARCHAR(100) NOT NULL,
    categoria VARCHAR(100) NOT NULL,
    imagen_articulo TEXT NULL,
    estado_publicacion VARCHAR(50) DEFAULT 'draft',
    fecha_publicacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_categoria (categoria),
    INDEX idx_estado_publicacion (estado_publicacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
