from sqlalchemy import (
    Column, Integer, String, Text, Float, DECIMAL, ForeignKey, TIMESTAMP,
    Boolean, DateTime, JSON, Index, CheckConstraint
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from datetime import datetime
from .base import Base


class Role(Base):
    __tablename__ = 'roles'
    id_rol = Column(Integer, primary_key=True, autoincrement=True)
    nombre_rol = Column(String(50), nullable=False, unique=True)
    descripcion = Column(Text)
    nivel_acceso = Column(Integer, default=1)
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())
    
    __table_args__ = (
        Index('idx_nombre_rol', 'nombre_rol'),
        Index('idx_nivel_acceso', 'nivel_acceso'),
    )


class Usuario(Base):
    __tablename__ = 'usuarios'
    id_usuario = Column(Integer, primary_key=True, autoincrement=True)
    nombre = Column(String(100), nullable=False)
    apellido = Column(String(100), nullable=False)
    correo = Column(String(150), unique=True, nullable=False)
    contrasena = Column(String(255), nullable=False)
    telefono = Column(String(20))
    fecha_registro = Column(TIMESTAMP, server_default=func.now())
    fecha_actualizacion = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    estado_activo = Column(Boolean, default=True)
    id_rol = Column(Integer, ForeignKey('roles.id_rol'), nullable=False)
    
    # Relaciones
    rol = relationship('Role', backref='usuarios')
    sesiones = relationship('Sesion', backref='usuario', cascade='all, delete-orphan')
    analisis = relationship('Analisis', backref='usuario', cascade='all, delete-orphan')
    
    __table_args__ = (
        Index('idx_correo', 'correo'),
        Index('idx_estado_activo', 'estado_activo'),
    )


class Sesion(Base):
    __tablename__ = 'sesiones'
    id_sesion = Column(Integer, primary_key=True, autoincrement=True)
    token_sesion = Column(Text, nullable=False)
    dispositivo = Column(String(100))
    ip_usuario = Column(String(50))
    fecha_inicio = Column(TIMESTAMP, server_default=func.now())
    fecha_vencimiento = Column(DateTime)
    estado_sesion = Column(String(50), default='active')
    id_usuario = Column(Integer, ForeignKey('usuarios.id_usuario'), nullable=False)
    
    __table_args__ = (
        Index('idx_token_sesion', 'token_sesion'),
        Index('idx_estado_sesion', 'estado_sesion'),
    )


class ModeloIA(Base):
    __tablename__ = 'modelos_ia'
    id_modelo = Column(Integer, primary_key=True, autoincrement=True)
    nombre_modelo = Column(String(100), nullable=False)
    version = Column(String(50), nullable=False)
    descripcion = Column(Text)
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())
    
    # Relaciones
    analisis = relationship('Analisis', backref='modelo', cascade='all, delete-orphan')
    
    __table_args__ = (
        Index('idx_nombre_modelo', 'nombre_modelo'),
    )


class Dataset(Base):
    __tablename__ = 'datasets'
    id_dataset = Column(Integer, primary_key=True, autoincrement=True)
    nombre_dataset = Column(String(100), nullable=False)
    ruta_archivo = Column(Text, nullable=False)
    tipo_datos = Column(String(50))
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())
    
    # Relaciones
    analisis = relationship('Analisis', backref='dataset', cascade='all, delete-orphan')
    
    __table_args__ = (
        Index('idx_nombre_dataset', 'nombre_dataset'),
    )


class Analisis(Base):
    __tablename__ = 'analisis'
    id_analisis = Column(Integer, primary_key=True, autoincrement=True)
    id_usuario = Column(Integer, ForeignKey('usuarios.id_usuario'), nullable=False)
    id_modelo = Column(Integer, ForeignKey('modelos_ia.id_modelo'), nullable=False)
    id_dataset = Column(Integer, ForeignKey('datasets.id_dataset'))
    resultado = Column(Text)
    estado = Column(String(50), default='pending')  # pending, processing, completed, failed
    metadata_resultado = Column(JSON)  # Para almacenar datos adicionales
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())
    fecha_actualizacion = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relaciones ya definidas en otros modelos
    imagenes = relationship('Imagen', backref='analisis', cascade='all, delete-orphan')
    
    __table_args__ = (
        Index('idx_id_usuario', 'id_usuario'),
        Index('idx_estado', 'estado'),
        Index('idx_fecha_creacion', 'fecha_creacion'),
    )


class Imagen(Base):
    __tablename__ = 'imagenes'
    id_imagen = Column(Integer, primary_key=True, autoincrement=True)
    id_analisis = Column(Integer, ForeignKey('analisis.id_analisis'), nullable=False)
    url = Column(Text)
    ruta_original = Column(Text)  # Ruta del archivo original
    ruta_procesada = Column(Text)  # Ruta del archivo procesado
    descripcion = Column(Text)
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())
    
    __table_args__ = (
        Index('idx_id_analisis', 'id_analisis'),
    )


class Ubicacion(Base):
    __tablename__ = 'ubicaciones'
    id_ubicacion = Column(Integer, primary_key=True, autoincrement=True)
    latitud = Column(DECIMAL(10, 8), nullable=False)
    longitud = Column(DECIMAL(11, 8), nullable=False)
    direccion = Column(Text, nullable=False)
    municipio = Column(String(100), nullable=False)
    departamento = Column(String(100), nullable=False)
    pais = Column(String(100), default='Colombia')
    fecha_registro = Column(TIMESTAMP, server_default=func.now())
    
    __table_args__ = (
        CheckConstraint('latitud >= -90 AND latitud <= 90', name='check_latitud_rango'),
        CheckConstraint('longitud >= -180 AND longitud <= 180', name='check_longitud_rango'),
        Index('idx_municipio', 'municipio'),
        Index('idx_departamento', 'departamento'),
    )


class LiquenPedia(Base):
    __tablename__ = 'liquenpedia'
    id_articulo = Column(Integer, primary_key=True, autoincrement=True)
    titulo = Column(String(150), nullable=False)
    contenido = Column(Text, nullable=False)
    autor = Column(String(100), nullable=False)
    categoria = Column(String(100), nullable=False)
    estado_publicacion = Column(String(50), default='draft')  # draft, published, archived
    fecha_publicacion = Column(TIMESTAMP, server_default=func.now())
    fecha_actualizacion = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (
        Index('idx_categoria', 'categoria'),
        Index('idx_estado_publicacion', 'estado_publicacion'),
    )
