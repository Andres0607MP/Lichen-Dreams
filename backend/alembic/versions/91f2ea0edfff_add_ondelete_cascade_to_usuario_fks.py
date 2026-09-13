"""add_ondelete_cascade_to_usuario_fks

Revision ID: 91f2ea0edfff
Revises: df0ea4d242fd
Create Date: 2026-09-12 22:00:16.591779
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = '91f2ea0edfff'
down_revision: Union[str, None] = 'df0ea4d242fd'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Drop existing FKs and recreate with ON DELETE CASCADE
    # sesiones.id_usuario -> usuarios.id_usuario
    op.drop_constraint('sesiones_ibfk_1', 'sesiones', type_='foreignkey')
    op.create_foreign_key(
        None, 'sesiones', 'usuarios',
        ['id_usuario'], ['id_usuario'],
        ondelete='CASCADE'
    )

    # analisis.id_usuario -> usuarios.id_usuario
    op.drop_constraint('analisis_ibfk_1', 'analisis', type_='foreignkey')
    op.create_foreign_key(
        None, 'analisis', 'usuarios',
        ['id_usuario'], ['id_usuario'],
        ondelete='CASCADE'
    )

    # historial_actividad.id_usuario -> usuarios.id_usuario
    op.drop_constraint('historial_actividad_ibfk_1', 'historial_actividad', type_='foreignkey')
    op.create_foreign_key(
        None, 'historial_actividad', 'usuarios',
        ['id_usuario'], ['id_usuario'],
        ondelete='CASCADE'
    )

    # reportes.id_usuario -> usuarios.id_usuario
    op.drop_constraint('reportes_ibfk_1', 'reportes', type_='foreignkey')
    op.create_foreign_key(
        None, 'reportes', 'usuarios',
        ['id_usuario'], ['id_usuario'],
        ondelete='CASCADE'
    )

    # notificaciones.id_usuario -> usuarios.id_usuario
    op.drop_constraint('notificaciones_ibfk_1', 'notificaciones', type_='foreignkey')
    op.create_foreign_key(
        None, 'notificaciones', 'usuarios',
        ['id_usuario'], ['id_usuario'],
        ondelete='CASCADE'
    )

    # password_reset_tokens.id_usuario -> usuarios.id_usuario
    op.drop_constraint('password_reset_tokens_ibfk_1', 'password_reset_tokens', type_='foreignkey')
    op.create_foreign_key(
        None, 'password_reset_tokens', 'usuarios',
        ['id_usuario'], ['id_usuario'],
        ondelete='CASCADE'
    )

    # email_verification_tokens.id_usuario -> usuarios.id_usuario
    op.drop_constraint('email_verification_tokens_ibfk_1', 'email_verification_tokens', type_='foreignkey')
    op.create_foreign_key(
        None, 'email_verification_tokens', 'usuarios',
        ['id_usuario'], ['id_usuario'],
        ondelete='CASCADE'
    )

    # recovery_codes.id_usuario -> usuarios.id_usuario
    op.drop_constraint('recovery_codes_ibfk_1', 'recovery_codes', type_='foreignkey')
    op.create_foreign_key(
        None, 'recovery_codes', 'usuarios',
        ['id_usuario'], ['id_usuario'],
        ondelete='CASCADE'
    )

    # imagenes.id_analisis -> analisis.id_analisis
    op.drop_constraint('imagenes_ibfk_1', 'imagenes', type_='foreignkey')
    op.create_foreign_key(
        None, 'imagenes', 'analisis',
        ['id_analisis'], ['id_analisis'],
        ondelete='CASCADE'
    )

    # procesamiento_ia.id_analisis -> analisis.id_analisis
    op.drop_constraint('procesamiento_ia_ibfk_1', 'procesamiento_ia', type_='foreignkey')
    op.create_foreign_key(
        None, 'procesamiento_ia', 'analisis',
        ['id_analisis'], ['id_analisis'],
        ondelete='CASCADE'
    )

    # zonas_ambientales.id_usuario_creador -> usuarios.id_usuario (keep SET NULL)
    op.drop_constraint('fk_zona_usuario_creador', 'zonas_ambientales', type_='foreignkey')
    op.create_foreign_key(
        None, 'zonas_ambientales', 'usuarios',
        ['id_usuario_creador'], ['id_usuario'],
        ondelete='SET NULL'
    )


def downgrade() -> None:
    # zonas_ambientales
    op.drop_constraint(None, 'zonas_ambientales', type_='foreignkey')
    op.create_foreign_key(
        'fk_zona_usuario_creador', 'zonas_ambientales', 'usuarios',
        ['id_usuario_creador'], ['id_usuario'],
        ondelete='SET NULL'
    )

    # procesamiento_ia
    op.drop_constraint(None, 'procesamiento_ia', type_='foreignkey')
    op.create_foreign_key(
        'procesamiento_ia_ibfk_1', 'procesamiento_ia', 'analisis',
        ['id_analisis'], ['id_analisis']
    )

    # imagenes
    op.drop_constraint(None, 'imagenes', type_='foreignkey')
    op.create_foreign_key(
        'imagenes_ibfk_1', 'imagenes', 'analisis',
        ['id_analisis'], ['id_analisis']
    )

    # recovery_codes
    op.drop_constraint(None, 'recovery_codes', type_='foreignkey')
    op.create_foreign_key(
        'recovery_codes_ibfk_1', 'recovery_codes', 'usuarios',
        ['id_usuario'], ['id_usuario']
    )

    # email_verification_tokens
    op.drop_constraint(None, 'email_verification_tokens', type_='foreignkey')
    op.create_foreign_key(
        'email_verification_tokens_ibfk_1', 'email_verification_tokens', 'usuarios',
        ['id_usuario'], ['id_usuario']
    )

    # password_reset_tokens
    op.drop_constraint(None, 'password_reset_tokens', type_='foreignkey')
    op.create_foreign_key(
        'password_reset_tokens_ibfk_1', 'password_reset_tokens', 'usuarios',
        ['id_usuario'], ['id_usuario']
    )

    # notificaciones
    op.drop_constraint(None, 'notificaciones', type_='foreignkey')
    op.create_foreign_key(
        'notificaciones_ibfk_1', 'notificaciones', 'usuarios',
        ['id_usuario'], ['id_usuario']
    )

    # reportes
    op.drop_constraint(None, 'reportes', type_='foreignkey')
    op.create_foreign_key(
        'reportes_ibfk_1', 'reportes', 'usuarios',
        ['id_usuario'], ['id_usuario']
    )

    # historial_actividad
    op.drop_constraint(None, 'historial_actividad', type_='foreignkey')
    op.create_foreign_key(
        'historial_actividad_ibfk_1', 'historial_actividad', 'usuarios',
        ['id_usuario'], ['id_usuario']
    )

    # analisis
    op.drop_constraint(None, 'analisis', type_='foreignkey')
    op.create_foreign_key(
        'analisis_ibfk_1', 'analisis', 'usuarios',
        ['id_usuario'], ['id_usuario']
    )

    # sesiones
    op.drop_constraint(None, 'sesiones', type_='foreignkey')
    op.create_foreign_key(
        'sesiones_ibfk_1', 'sesiones', 'usuarios',
        ['id_usuario'], ['id_usuario']
    )