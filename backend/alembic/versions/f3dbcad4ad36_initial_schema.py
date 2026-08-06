"""initial_schema

Revision ID: f3dbcad4ad36
Revises:
Create Date: 2026-08-05 19:17:27.982918
"""

from datetime import datetime
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f3dbcad4ad36'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'roles',
        sa.Column('id_rol', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('nombre_rol', sa.String(50), nullable=False, unique=True),
        sa.Column('descripcion', sa.Text),
        sa.Column('nivel_acceso', sa.Integer, server_default='1'),
        sa.Column('fecha_creacion', sa.TIMESTAMP, server_default=sa.func.now()),
        sa.Index('idx_nombre_rol', 'nombre_rol'),
        sa.Index('idx_nivel_acceso', 'nivel_acceso'),
    )

    op.create_table(
        'usuarios',
        sa.Column('id_usuario', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('nombre', sa.String(100)),
        sa.Column('apellido', sa.String(100)),
        sa.Column('tipo_documento', sa.String(20)),
        sa.Column('numero_documento', sa.String(50)),
        sa.Column('correo', sa.String(150), unique=True),
        sa.Column('contrasena', sa.String),
        sa.Column('telefono', sa.String(20)),
        sa.Column('foto_perfil', sa.Text),
        sa.Column('fecha_nacimiento', sa.DateTime),
        sa.Column('fecha_registro', sa.TIMESTAMP, server_default=sa.func.now()),
        sa.Column('ultimo_acceso', sa.TIMESTAMP, nullable=True),
        sa.Column('estado_cuenta', sa.String(50), server_default='active'),
        sa.Column('id_rol', sa.Integer, sa.ForeignKey('roles.id_rol')),
        sa.Column('fecha_actualizacion', sa.DateTime, nullable=True),
        sa.Index('idx_correo', 'correo'),
    )

    op.create_table(
        'sesiones',
        sa.Column('id_sesion', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('token_sesion', sa.Text),
        sa.Column('dispositivo', sa.String(100)),
        sa.Column('sistema_operativo', sa.String(100)),
        sa.Column('ip_usuario', sa.String(50)),
        sa.Column('fecha_inicio', sa.TIMESTAMP, server_default=sa.func.now()),
        sa.Column('fecha_expiracion', sa.TIMESTAMP, nullable=True),
        sa.Column('estado_sesion', sa.String(50)),
        sa.Column('id_usuario', sa.Integer, sa.ForeignKey('usuarios.id_usuario')),
        sa.Index('idx_token_sesion', 'token_sesion'),
        sa.Index('idx_estado_sesion', 'estado_sesion'),
    )

    op.create_table(
        'modelos_ia',
        sa.Column('id_modelo', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('nombre_modelo', sa.String(100), nullable=False),
        sa.Column('version', sa.String(50), nullable=False),
        sa.Column('tipo_modelo', sa.String(100)),
        sa.Column('descripcion', sa.Text),
        sa.Column('precision_modelo', sa.Float),
        sa.Column('dataset_utilizado', sa.String(255)),
        sa.Column('fecha_entrenamiento', sa.DateTime),
        sa.Column('fecha_actualizacion', sa.TIMESTAMP, nullable=True),
        sa.Column('estado_modelo', sa.String(50)),
        sa.Column('observaciones', sa.Text),
        sa.Column('fecha_creacion', sa.TIMESTAMP, server_default=sa.func.now()),
        sa.Index('idx_nombre_modelo', 'nombre_modelo'),
    )

    op.create_table(
        'datasets',
        sa.Column('id_dataset', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('nombre_dataset', sa.String(100), nullable=False),
        sa.Column('descripcion', sa.Text),
        sa.Column('cantidad_imagenes', sa.Integer),
        sa.Column('ruta_archivo', sa.String, nullable=True),
        sa.Column('tipo_datos', sa.String(50)),
        sa.Column('fuente_dataset', sa.String(255)),
        sa.Column('estado_dataset', sa.String(50)),
        sa.Column('fecha_creacion', sa.TIMESTAMP, server_default=sa.func.now()),
        sa.Index('idx_nombre_dataset', 'nombre_dataset'),
    )

    op.create_table(
        'especies_liquenes',
        sa.Column('id_especie', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('nombre_cientifico', sa.String(100)),
        sa.Column('nombre_comun', sa.String(100)),
        sa.Column('descripcion', sa.Text),
        sa.Column('color_predominante', sa.String(50)),
        sa.Column('tipo_crecimiento', sa.String(50)),
        sa.Column('nivel_tolerancia_contaminacion', sa.String(100)),
        sa.Column('indicador_calidad_aire', sa.String(255)),
        sa.Column('habitat', sa.String(100)),
        sa.Column('imagen_referencia', sa.Text),
        sa.Column('fecha_registro', sa.TIMESTAMP, server_default=sa.func.now()),
    )

    op.create_table(
        'ubicaciones',
        sa.Column('id_ubicacion', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('latitud', sa.DECIMAL(10, 8)),
        sa.Column('longitud', sa.DECIMAL(11, 8)),
        sa.Column('direccion', sa.Text),
        sa.Column('municipio', sa.String(100)),
        sa.Column('departamento', sa.String(100)),
        sa.Column('pais', sa.String(100)),
        sa.Column('altitud', sa.Float),
        sa.Column('fecha_registro', sa.TIMESTAMP, server_default=sa.func.now()),
        sa.CheckConstraint('latitud BETWEEN -90 AND 90', name='ck_latitud_range'),
        sa.CheckConstraint('longitud BETWEEN -180 AND 180', name='ck_longitud_range'),
    )

    op.create_table(
        'analisis',
        sa.Column('id_analisis', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('id_usuario', sa.Integer, sa.ForeignKey('usuarios.id_usuario'), nullable=False),
        sa.Column('id_modelo', sa.Integer, sa.ForeignKey('modelos_ia.id_modelo'), nullable=False),
        sa.Column('id_dataset', sa.Integer, sa.ForeignKey('datasets.id_dataset')),
        sa.Column('id_especie', sa.Integer, sa.ForeignKey('especies_liquenes.id_especie')),
        sa.Column('id_ubicacion', sa.Integer, sa.ForeignKey('ubicaciones.id_ubicacion')),
        sa.Column('resultado_ia', sa.Text),
        sa.Column('porcentaje_confianza', sa.Float),
        sa.Column('nivel_contaminacion', sa.String(50)),
        sa.Column('calidad_aire', sa.String(50)),
        sa.Column('estado_liquen', sa.String(100)),
        sa.Column('tiempo_procesamiento', sa.Float),
        sa.Column('observaciones', sa.Text),
        sa.Column('estado_validacion', sa.String(50)),
        sa.Column('temperatura_ambiente', sa.Float),
        sa.Column('humedad_relativa', sa.Float),
        sa.Column('fecha', sa.TIMESTAMP, server_default=sa.func.now()),
        sa.Index('idx_id_usuario', 'id_usuario'),
        sa.Index('idx_estado_validacion', 'estado_validacion'),
        sa.Index('idx_fecha', 'fecha'),
    )

    op.create_table(
        'imagenes',
        sa.Column('id_imagen', sa.Integer, primary_key=True, index=True),
        sa.Column('id_analisis', sa.Integer, sa.ForeignKey('analisis.id_analisis')),
        sa.Column('nombre_imagen', sa.String(255)),
        sa.Column('ruta_imagen', sa.Text),
        sa.Column('url', sa.Text),
        sa.Column('formato_imagen', sa.String(20)),
        sa.Column('tamano_archivo', sa.Integer),
        sa.Column('resolucion', sa.String(50)),
        sa.Column('imagen_original', sa.LargeBinary),
        sa.Column('imagen_procesada', sa.LargeBinary),
        sa.Column('estado_imagen', sa.String(50)),
        sa.Column('tipo_captura', sa.String(50)),
        sa.Column('descripcion', sa.Text),
        sa.Index('idx_id_analisis', 'id_analisis'),
    )

    op.create_table(
        'procesamiento_ia',
        sa.Column('id_procesamiento', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('id_analisis', sa.Integer, sa.ForeignKey('analisis.id_analisis')),
        sa.Column('tiempo_ejecucion', sa.Float),
        sa.Column('porcentaje_precision', sa.Float),
        sa.Column('precision_modelo', sa.Float),
        sa.Column('cantidad_objetos_detectados', sa.Integer),
        sa.Column('resultado_segmentacion', sa.Text),
        sa.Column('observaciones', sa.Text),
        sa.Column('fecha', sa.TIMESTAMP, server_default=sa.func.now()),
    )

    op.create_table(
        'zonas_ambientales',
        sa.Column('id_zona', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('nombre_zona', sa.String(100)),
        sa.Column('nivel_riesgo', sa.String(50)),
        sa.Column('calidad_promedio_aire', sa.String(50)),
        sa.Column('descripcion', sa.Text),
        sa.Column('fecha_actualizacion', sa.TIMESTAMP, nullable=True),
    )

    op.create_table(
        'reportes',
        sa.Column('id_reporte', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('titulo', sa.String(100)),
        sa.Column('descripcion', sa.Text),
        sa.Column('tipo_reporte', sa.String(50)),
        sa.Column('formato_reporte', sa.String(50)),
        sa.Column('estado_reporte', sa.String(50)),
        sa.Column('fecha_generacion', sa.TIMESTAMP, server_default=sa.func.now()),
        sa.Column('id_usuario', sa.Integer, sa.ForeignKey('usuarios.id_usuario')),
    )

    op.create_table(
        'notificaciones',
        sa.Column('id_notificacion', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('id_usuario', sa.Integer, sa.ForeignKey('usuarios.id_usuario')),
        sa.Column('titulo', sa.String(100)),
        sa.Column('mensaje', sa.Text),
        sa.Column('tipo_notificacion', sa.String(50)),
        sa.Column('estado_notificacion', sa.String(50)),
        sa.Column('fecha', sa.TIMESTAMP, server_default=sa.func.now()),
    )

    op.create_table(
        'liquenpedia',
        sa.Column('id_articulo', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('titulo', sa.String(150), nullable=False),
        sa.Column('contenido', sa.Text, nullable=False),
        sa.Column('categoria', sa.String(100), nullable=False, server_default='general'),
        sa.Column('autor', sa.String(100), nullable=True, server_default='system'),
        sa.Column('imagen_articulo', sa.Text, nullable=True),
        sa.Column('estado_publicacion', sa.String(50), server_default='draft'),
        sa.Column('fecha_publicacion', sa.TIMESTAMP, server_default=sa.func.now()),
        sa.Column('fecha_actualizacion', sa.DateTime),
        sa.Index('idx_categoria', 'categoria'),
        sa.Index('idx_estado_publicacion', 'estado_publicacion'),
    )

    op.create_table(
        'modelo_dataset',
        sa.Column('id', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('id_modelo', sa.Integer, sa.ForeignKey('modelos_ia.id_modelo')),
        sa.Column('id_dataset', sa.Integer, sa.ForeignKey('datasets.id_dataset')),
        sa.Column('fecha_asociacion', sa.TIMESTAMP, server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table('modelo_dataset')
    op.drop_table('liquenpedia')
    op.drop_table('notificaciones')
    op.drop_table('reportes')
    op.drop_table('zonas_ambientales')
    op.drop_table('procesamiento_ia')
    op.drop_table('imagenes')
    op.drop_table('analisis')
    op.drop_table('ubicaciones')
    op.drop_table('especies_liquenes')
    op.drop_table('modelos_ia')
    op.drop_table('sesiones')
    op.drop_table('datasets')
    op.drop_table('usuarios')
    op.drop_table('roles')
