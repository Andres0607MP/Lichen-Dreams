"""Seed script for initial data.

Run with: `python scripts/seed.py` from the `backend` folder.
"""
from sqlalchemy.exc import IntegrityError
from auth.password_handler import hash_password
from config.db import SessionLocal
from models.core import (
    Role,
    Usuario,
    ModeloIA,
    Dataset,
    Analisis,
    Imagen,
    Ubicacion,
    EspecieLiquen,
    LiquenPedia,
    HistorialActividad,
    ModeloDataset,
)


def get_or_create(db, model, defaults=None, **kwargs):
    instance = db.query(model).filter_by(**kwargs).first()
    if instance:
        return instance, False
    params = dict(kwargs)
    if defaults:
        params.update(defaults)
    instance = model(**params)
    db.add(instance)
    db.commit()
    return instance, True


def seed():
    db = SessionLocal()
    try:
        admin_role, _ = get_or_create(
            db,
            Role,
            nombre_rol='admin',
            defaults={'descripcion': 'Administrador', 'nivel_acceso': 10},
        )
        user_role, _ = get_or_create(
            db,
            Role,
            nombre_rol='user',
            defaults={'descripcion': 'Usuario normal', 'nivel_acceso': 1},
        )

        admin_user, _ = get_or_create(
            db,
            Usuario,
            correo='admin@gmail.com',
            defaults={
                'nombre': 'Admin',
                'apellido': 'Admin',
                'contrasena': hash_password('admin123'),
                'telefono': None,
                'estado_cuenta': 'active',
                'id_rol': admin_role.id_rol,
            },
        )

        demo_user, _ = get_or_create(
            db,
            Usuario,
            correo='user@gmail.com',
            defaults={
                'nombre': 'Usuario',
                'apellido': 'Demo',
                'contrasena': hash_password('user123'),
                'telefono': '3000000000',
                'estado_cuenta': 'active',
                'id_rol': user_role.id_rol,
            },
        )

        modelo_demo, _ = get_or_create(
            db,
            ModeloIA,
            nombre_modelo='modelo_demo',
            version='1.0',
            defaults={
                'descripcion': 'Modelo de demo para pruebas',
                'tipo_modelo': 'clasificacion',
                'precision_modelo': 0.85,
                'estado_modelo': 'activo',
            },
        )

        dataset_demo, _ = get_or_create(
            db,
            Dataset,
            nombre_dataset='dataset_demo',
            defaults={
                'descripcion': 'Dataset de demo',
                'cantidad_imagenes': 10,
                'ruta_archivo': '/data/demo',
                'tipo_datos': 'imagenes',
                'fuente_dataset': 'generado',
                'estado_dataset': 'activo',
            },
        )

        _, _ = get_or_create(
            db,
            ModeloDataset,
            id_modelo=modelo_demo.id_modelo,
            id_dataset=dataset_demo.id_dataset,
        )

        especie_demo, _ = get_or_create(
            db,
            EspecieLiquen,
            nombre_cientifico='Physcia adscendens',
            defaults={
                'nombre_comun': 'Liquen demo',
                'descripcion': 'Especie de prueba para el seed',
                'color_predominante': 'Verde',
                'tipo_crecimiento': 'foliose',
                'nivel_tolerancia_contaminacion': 'alto',
                'indicador_calidad_aire': 'buena',
                'habitat': 'Bosques húmedos',
            },
        )

        ubicacion_demo, _ = get_or_create(
            db,
            Ubicacion,
            latitud=4.710989,
            longitud=-74.072090,
            defaults={
                'direccion': 'Bogotá, Colombia',
                'municipio': 'Bogotá',
                'departamento': 'Cundinamarca',
                'pais': 'Colombia',
                'altitud': 2640.0,
            },
        )

        analisis_demo, created = get_or_create(
            db,
            Analisis,
            id_usuario=demo_user.id_usuario,
            id_modelo=modelo_demo.id_modelo,
            id_dataset=dataset_demo.id_dataset,
            defaults={
                'id_especie': especie_demo.id_especie,
                'id_ubicacion': ubicacion_demo.id_ubicacion,
                'resultado_ia': 'Liquen saludable',
                'porcentaje_confianza': 0.92,
                'nivel_contaminacion': 'baja',
                'calidad_aire': 'buena',
                'estado_liquen': 'completado',
                'estado_validacion': 'completed',
                'temperatura_ambiente': 22.5,
                'humedad_relativa': 68.0,
            },
        )

        if created:
            imagen = Imagen(
                id_analisis=analisis_demo.id_analisis,
                nombre_imagen='liquen_demo.jpg',
                ruta_imagen='uploads/analyses/demo/liquen_demo.jpg',
                formato_imagen='jpg',
                tamano_archivo=102400,
                resolucion='1024x768',
                estado_imagen='procesada',
            )
            db.add(imagen)
            db.commit()

        _, _ = get_or_create(
            db,
            LiquenPedia,
            titulo='Liquen de prueba',
            defaults={
                'contenido': 'Artículo de prueba para la base de datos.',
                'categoria': 'educacion',
                'autor': 'seed',
                'estado_publicacion': 'published',
            },
        )

        _, _ = get_or_create(
            db,
            HistorialActividad,
            id_usuario=demo_user.id_usuario,
            accion_realizada='Seed inicial',
            defaults={
                'descripcion_accion': 'Registro de prueba creado por el seed.',
                'dispositivo': 'seed-script',
                'ip_usuario': '127.0.0.1',
            },
        )

    except IntegrityError:
        db.rollback()
    finally:
        db.close()


if __name__ == '__main__':
    seed()
