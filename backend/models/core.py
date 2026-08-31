from sqlalchemy import (
    Column, Integer, String, Text, Float, DECIMAL, ForeignKey, TIMESTAMP,
    Boolean, DateTime, JSON, Index, CheckConstraint, LargeBinary
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
    nombre = Column(String(100))
    apellido = Column(String(100))
    tipo_documento = Column(String(20))
    numero_documento = Column(String(50))
    correo = Column(String(150), unique=True)
    contrasena = Column(String(255))
    telefono = Column(String(20))
    foto_perfil = Column(Text)
    fecha_nacimiento = Column(DateTime)
    fecha_registro = Column(TIMESTAMP, server_default=func.now())
    ultimo_acceso = Column(TIMESTAMP, nullable=True)
    estado_cuenta = Column(String(50), default='active')
    id_rol = Column(Integer, ForeignKey('roles.id_rol'))
    proveedor = Column(String(50), default='local')
    proveedor_id = Column(String(255), nullable=True)
    fecha_actualizacion = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    rol = relationship('Role', backref='usuarios')
    sesiones = relationship('Sesion', backref='usuario', cascade='all, delete-orphan')
    analisis = relationship('Analisis', backref='usuario', cascade='all, delete-orphan')
    historial_actividad = relationship('HistorialActividad', back_populates='usuario', cascade='all, delete-orphan')
    reportes = relationship('Reporte', back_populates='usuario', cascade='all, delete-orphan')
    notificaciones = relationship('Notificacion', back_populates='usuario', cascade='all, delete-orphan')

    __table_args__ = (
        Index('idx_correo', 'correo'),
    )

    @property
    def estado_activo(self):
        return self.estado_cuenta == 'active'

    def __init__(self, **kwargs):
        if 'contraseña' in kwargs:
            kwargs['contrasena'] = kwargs.pop('contraseña')
        super().__init__(**kwargs)


class Sesion(Base):
    __tablename__ = 'sesiones'
    id_sesion = Column(Integer, primary_key=True, autoincrement=True)
    token_sesion = Column(Text)
    dispositivo = Column(String(100))
    sistema_operativo = Column(String(100))
    ip_usuario = Column(String(50))
    fecha_inicio = Column(TIMESTAMP, server_default=func.now())
    fecha_expiracion = Column(TIMESTAMP, nullable=True)
    estado_sesion = Column(String(50))
    id_usuario = Column(Integer, ForeignKey('usuarios.id_usuario'))

    __table_args__ = (
        Index('idx_token_sesion', 'token_sesion'),
        Index('idx_estado_sesion', 'estado_sesion'),
    )


class ModeloIA(Base):
    __tablename__ = 'modelos_ia'
    id_modelo = Column(Integer, primary_key=True, autoincrement=True)
    nombre_modelo = Column(String(100), nullable=False)
    version = Column(String(50), nullable=False)
    tipo_modelo = Column(String(100))
    descripcion = Column(Text)
    precision_modelo = Column(Float)
    dataset_utilizado = Column(String(255))
    fecha_entrenamiento = Column(DateTime)
    fecha_actualizacion = Column(TIMESTAMP, nullable=True)
    estado_modelo = Column(String(50))
    observaciones = Column(Text)
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())

    analisis = relationship('Analisis', backref='modelo', cascade='all, delete-orphan')

    __table_args__ = (
        Index('idx_nombre_modelo', 'nombre_modelo'),
    )


class Dataset(Base):
    __tablename__ = 'datasets'
    id_dataset = Column(Integer, primary_key=True, autoincrement=True)
    nombre_dataset = Column(String(100), nullable=False)
    descripcion = Column(Text)
    cantidad_imagenes = Column(Integer)
    ruta_archivo = Column(String(255), nullable=True)
    tipo_datos = Column(String(50))
    fuente_dataset = Column(String(255))
    estado_dataset = Column(String(50))
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())

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
    id_especie = Column(Integer, ForeignKey('especies_liquenes.id_especie'))
    id_ubicacion = Column(Integer, ForeignKey('ubicaciones.id_ubicacion'))
    resultado_ia = Column(Text)
    porcentaje_confianza = Column(Float)
    nivel_contaminacion = Column(String(50))
    calidad_aire = Column(String(50))
    estado_liquen = Column(String(100))
    tiempo_procesamiento = Column(Float)
    observaciones = Column(Text)
    estado_validacion = Column(String(50))
    visibilidad = Column(String(50), nullable=False, server_default='private')
    temperatura_ambiente = Column(Float)
    humedad_relativa = Column(Float)
    fecha = Column(TIMESTAMP, server_default=func.now())

    imagenes = relationship('Imagen', backref='analisis', cascade='all, delete-orphan')

    @property
    def resultado(self):
        return self.resultado_ia

    @resultado.setter
    def resultado(self, value):
        self.resultado_ia = value

    @property
    def estado(self):
        return self.estado_validacion

    @estado.setter
    def estado(self, value):
        self.estado_validacion = value

    @property
    def metadata_resultado(self):
        return None

    @metadata_resultado.setter
    def metadata_resultado(self, value):
        self.observaciones = value if isinstance(value, str) else str(value)

    @property
    def fecha_creacion(self):
        return self.fecha

    __table_args__ = (
        Index('idx_id_usuario', 'id_usuario'),
        Index('idx_estado_validacion', 'estado_validacion'),
        Index('idx_visibilidad', 'visibilidad'),
        Index('idx_fecha', 'fecha'),
    )


class Imagen(Base):
    __tablename__ = 'imagenes'
    id_imagen = Column(Integer, primary_key=True, index=True)
    id_analisis = Column(Integer, ForeignKey('analisis.id_analisis'))
    nombre_imagen = Column(String(255))
    ruta_imagen = Column(Text)
    url = Column(Text)
    formato_imagen = Column(String(20))
    tamano_archivo = Column(Integer)
    resolucion = Column(String(50))
    imagen_original = Column(LargeBinary)
    imagen_procesada = Column(LargeBinary)
    estado_imagen = Column(String(50))
    tipo_captura = Column(String(50))
    descripcion = Column(Text)

    __table_args__ = (
        Index('idx_id_analisis', 'id_analisis'),
    )

    def __init__(self, **kwargs):
        if 'ruta_original' in kwargs:
            kwargs['ruta_imagen'] = kwargs.pop('ruta_original')
        if 'ruta_procesada' in kwargs:
            kwargs.pop('ruta_procesada')
        super().__init__(**kwargs)


class EspecieLiquen(Base):
    __tablename__ = 'especies_liquenes'
    id_especie = Column(Integer, primary_key=True, autoincrement=True)
    nombre_cientifico = Column(String(100), nullable=False, unique=True)
    nombre_comun = Column(String(100))
    descripcion = Column(Text)
    color_predominante = Column(String(50))
    tipo_crecimiento = Column(String(50))
    nivel_tolerancia_contaminacion = Column(String(100))
    indicador_calidad_aire = Column(String(255))
    habitat = Column(String(100))
    imagen_referencia = Column(Text)
    fecha_registro = Column(TIMESTAMP, server_default=func.now())

    analisis = relationship('Analisis', backref='especie', cascade='all, delete-orphan')


class Ubicacion(Base):
    __tablename__ = 'ubicaciones'
    id_ubicacion = Column(Integer, primary_key=True, autoincrement=True)
    latitud = Column(DECIMAL(10, 8))
    longitud = Column(DECIMAL(11, 8))
    direccion = Column(Text)
    municipio = Column(String(100))
    departamento = Column(String(100))
    pais = Column(String(100))
    altitud = Column(Float)
    fecha_registro = Column(TIMESTAMP, server_default=func.now())

    analisis = relationship('Analisis', backref='ubicacion', cascade='all, delete-orphan')

    __table_args__ = (
        CheckConstraint('latitud BETWEEN -90 AND 90', name='ck_latitud_range'),
        CheckConstraint('longitud BETWEEN -180 AND 180', name='ck_longitud_range'),
    )


class ProcesamientoIA(Base):
    __tablename__ = 'procesamiento_ia'
    id_procesamiento = Column(Integer, primary_key=True, autoincrement=True)
    id_analisis = Column(Integer, ForeignKey('analisis.id_analisis'))
    tiempo_ejecucion = Column(Float)
    porcentaje_precision = Column(Float)
    precision_modelo = Column(Float)
    cantidad_objetos_detectados = Column(Integer)
    resultado_segmentacion = Column(Text)
    observaciones = Column(Text)
    fecha = Column(TIMESTAMP, server_default=func.now())


class ZonaAmbiental(Base):
    __tablename__ = 'zonas_ambientales'
    id_zona = Column(Integer, primary_key=True, autoincrement=True)
    nombre_zona = Column(String(100))
    latitud = Column(DECIMAL(10, 8))
    longitud = Column(DECIMAL(11, 8))
    radio_metros = Column(Float)
    nivel_riesgo = Column(String(50))
    calidad_promedio_aire = Column(String(50))
    descripcion = Column(Text)
    fecha_actualizacion = Column(TIMESTAMP, nullable=True)


class Notificacion(Base):
    __tablename__ = 'notificaciones'
    id_notificacion = Column(Integer, primary_key=True, autoincrement=True)
    id_usuario = Column(Integer, ForeignKey('usuarios.id_usuario'))
    titulo = Column(String(100))
    mensaje = Column(Text)
    tipo_notificacion = Column(String(50))
    estado_notificacion = Column(String(50))
    fecha = Column(TIMESTAMP, server_default=func.now())
    usuario = relationship('Usuario', back_populates='notificaciones')


class LiquenPedia(Base):
    __tablename__ = 'liquenpedia'
    id_articulo = Column(Integer, primary_key=True, autoincrement=True)
    titulo = Column(String(150), nullable=False)
    contenido = Column(Text, nullable=False)
    categoria = Column(String(100), nullable=False, default='general')
    id_categoria = Column(Integer, ForeignKey('categorias_articulos.id_categoria'), nullable=True)
    autor = Column(String(100), nullable=True, default='system')
    imagen_articulo = Column(Text, nullable=True)
    foto_perfil_articulo = Column(Text, nullable=True)
    estado_publicacion = Column(String(50), default='draft')
    fecha_publicacion = Column(TIMESTAMP, server_default=func.now())
    fecha_actualizacion = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    categoria_obj = relationship('CategoriaArticulo', back_populates='articulos')

    __table_args__ = (
        Index('idx_categoria', 'categoria'),
        Index('idx_estado_publicacion', 'estado_publicacion'),
        Index('idx_id_categoria', 'id_categoria'),
    )


class CategoriaArticulo(Base):
    __tablename__ = 'categorias_articulos'
    id_categoria = Column(Integer, primary_key=True, autoincrement=True)
    nombre_categoria = Column(String(100), nullable=False, unique=True)
    descripcion = Column(Text, nullable=True)
    color = Column(String(7), nullable=True)
    icono = Column(String(50), nullable=True)
    orden = Column(Integer, default=0)
    activo = Column(Boolean, default=True)
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())

    articulos = relationship('LiquenPedia', back_populates='categoria_obj')

    __table_args__ = (
        Index('idx_nombre_categoria', 'nombre_categoria'),
        Index('idx_orden', 'orden'),
    )


class Reporte(Base):
    __tablename__ = 'reportes'
    id_reporte = Column(Integer, primary_key=True, autoincrement=True)
    titulo = Column(String(100))
    descripcion = Column(Text)
    tipo_reporte = Column(String(50))
    formato_reporte = Column(String(50))
    estado_reporte = Column(String(50))
    fecha_generacion = Column(TIMESTAMP, server_default=func.now())
    id_usuario = Column(Integer, ForeignKey('usuarios.id_usuario'))
    datos_reporte = Column(JSON, nullable=True)
    usuario = relationship('Usuario', back_populates='reportes')


class HistorialActividad(Base):
    __tablename__ = 'historial_actividad'
    id_historial = Column(Integer, primary_key=True, autoincrement=True)
    id_usuario = Column(Integer, ForeignKey('usuarios.id_usuario'))
    accion_realizada = Column(String(255))
    descripcion_accion = Column(Text)
    dispositivo = Column(String(100))
    ip_usuario = Column(String(50))
    fecha = Column(TIMESTAMP, server_default=func.now())
    usuario = relationship('Usuario', back_populates='historial_actividad')


class ModeloDataset(Base):
    __tablename__ = 'modelo_dataset'
    id = Column(Integer, primary_key=True, autoincrement=True)
    id_modelo = Column(Integer, ForeignKey('modelos_ia.id_modelo'))
    id_dataset = Column(Integer, ForeignKey('datasets.id_dataset'))
    fecha_asociacion = Column(TIMESTAMP, server_default=func.now())


class PasswordResetToken(Base):
    __tablename__ = 'password_reset_tokens'
    id = Column(Integer, primary_key=True, autoincrement=True)
    id_usuario = Column(Integer, ForeignKey('usuarios.id_usuario'), nullable=False)
    token_hash = Column(String(255), nullable=False, unique=True)
    expires_at = Column(TIMESTAMP, nullable=False)
    used_at = Column(TIMESTAMP, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())

    usuario = relationship('Usuario', backref='password_reset_tokens')

    __table_args__ = (
        Index('idx_token_hash', 'token_hash'),
        Index('idx_id_usuario_token', 'id_usuario'),
    )


class EmailVerificationToken(Base):
    __tablename__ = 'email_verification_tokens'
    id = Column(Integer, primary_key=True, autoincrement=True)
    id_usuario = Column(Integer, ForeignKey('usuarios.id_usuario'), nullable=False)
    token_hash = Column(String(255), nullable=False, unique=True)
    expires_at = Column(TIMESTAMP, nullable=False)
    used_at = Column(TIMESTAMP, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())

    usuario = relationship('Usuario', backref='email_verification_tokens')

    __table_args__ = (
        Index('idx_verification_token_hash', 'token_hash'),
        Index('idx_verification_id_usuario', 'id_usuario'),
    )


class RecoveryCode(Base):
    __tablename__ = 'recovery_codes'
    id = Column(Integer, primary_key=True, autoincrement=True)
    id_usuario = Column(Integer, ForeignKey('usuarios.id_usuario'), nullable=False)
    code_hash = Column(String(255), nullable=False, unique=True)
    expires_at = Column(TIMESTAMP, nullable=False)
    used_at = Column(TIMESTAMP, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())

    usuario = relationship('Usuario', backref='recovery_codes')

    __table_args__ = (
        Index('idx_recovery_code_hash', 'code_hash'),
        Index('idx_recovery_id_usuario', 'id_usuario'),
    )
