"""Seed script for initial data.

Run with: `python scripts/seed.py` from the `backend` folder.
"""
from sqlalchemy.exc import IntegrityError
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
