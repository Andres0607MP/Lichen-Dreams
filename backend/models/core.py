from sqlalchemy import Column, Integer, String, Text, Float, DECIMAL, ForeignKey, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from .base import Base


class Role(Base):
    __tablename__ = 'roles'
    id_rol = Column(Integer, primary_key=True, autoincrement=True)
    nombre_rol = Column(String(50), nullable=False)
    descripcion = Column(Text)
    nivel_acceso = Column(Integer)
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())


class Usuario(Base):
    __tablename__ = 'usuarios'
    id_usuario = Column(Integer, primary_key=True, autoincrement=True)
    nombre = Column(String(100))
    apellido = Column(String(100))
    correo = Column(String(150), unique=True)
    contraseña = Column(String(255))
    telefono = Column(String(20))
    fecha_registro = Column(TIMESTAMP, server_default=func.now())
    estado_cuenta = Column(String(50))
    id_rol = Column(Integer, ForeignKey('roles.id_rol'))
    rol = relationship('Role')


class ModeloIA(Base):
    __tablename__ = 'modelos_ia'
    id_modelo = Column(Integer, primary_key=True, autoincrement=True)
    nombre_modelo = Column(String(100))
    version = Column(String(50))
    descripcion = Column(Text)
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())


class Dataset(Base):
    __tablename__ = 'datasets'
    id_dataset = Column(Integer, primary_key=True, autoincrement=True)
    nombre_dataset = Column(String(100))
    ruta_archivo = Column(Text)
    tipo_datos = Column(String(50))
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())


class Analisis(Base):
    __tablename__ = 'analisis'
    id_analisis = Column(Integer, primary_key=True, autoincrement=True)
    id_usuario = Column(Integer, ForeignKey('usuarios.id_usuario'))
    id_modelo = Column(Integer, ForeignKey('modelos_ia.id_modelo'))
    id_dataset = Column(Integer, ForeignKey('datasets.id_dataset'))
    resultado = Column(Text)
    fecha = Column(TIMESTAMP, server_default=func.now())


class Imagen(Base):
    __tablename__ = 'imagenes'
    id_imagen = Column(Integer, primary_key=True, autoincrement=True)
    id_analisis = Column(Integer, ForeignKey('analisis.id_analisis'))
    url = Column(Text)
    descripcion = Column(Text)


class Ubicacion(Base):
    __tablename__ = 'ubicaciones'
    id_ubicacion = Column(Integer, primary_key=True, autoincrement=True)
    latitud = Column(DECIMAL(10, 8))
    longitud = Column(DECIMAL(11, 8))
    direccion = Column(Text)
    municipio = Column(String(100))
    departamento = Column(String(100))
    pais = Column(String(100))
    fecha_registro = Column(TIMESTAMP, server_default=func.now())
