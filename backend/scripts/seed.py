"""Seed script for initial data.

Run with: `python scripts/seed.py` from the `backend` folder.
"""
from sqlalchemy.exc import IntegrityError
from auth.password_handler import hash_password
from config.db import SessionLocal
from models.core import Role, Usuario, ModeloIA, Dataset


def seed():
    db = SessionLocal()
    try:
        # roles
        admin = Role(nombre_rol='admin', descripcion='Administrador', nivel_acceso=10)
        user = Role(nombre_rol='user', descripcion='Usuario normal', nivel_acceso=1)
        db.add_all([admin, user])
        db.commit()
    except IntegrityError:
        db.rollback()

    try:
        admin_role = db.query(Role).filter(Role.nombre_rol == 'admin').first()
        if admin_role:
            existing_admin = db.query(Usuario).filter(Usuario.correo == 'admin@gmail.com').first()
            if not existing_admin:
                admin_user = Usuario(
                    nombre='Admin',
                    apellido='Admin',
                    correo='admin@gmail.com',
                    contrasena=hash_password('admin'),
                    telefono=None,
                    estado_cuenta='active',
                    id_rol=admin_role.id_rol
                )
                db.add(admin_user)
                db.commit()
    except IntegrityError:
        db.rollback()

    try:
        # sample model and dataset
        m = ModeloIA(nombre_modelo='modelo_demo', version='1.0', descripcion='Demo')
        ds = Dataset(nombre_dataset='dataset_demo', ruta_archivo='/data/demo', tipo_datos='imagenes')
        db.add_all([m, ds])
        db.commit()
    except IntegrityError:
        db.rollback()

    db.close()


if __name__ == '__main__':
    seed()
