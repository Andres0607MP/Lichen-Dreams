#!/usr/bin/env python
"""Script de limpieza de imágenes de perfil en R2.

Migra las fotos de perfil actuales a keys deterministas:
    profiles/user_{id}/profile.jpg

Elimina objetos huérfanos y de usuarios eliminados.
"""
import sys
from config.settings import (
    R2_ENDPOINT_URL,
    R2_ACCESS_KEY_ID,
    R2_SECRET_ACCESS_KEY,
    R2_BUCKET_NAME,
)
import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from config.db import SessionLocal
from models.core import Usuario


def get_r2_client():
    return boto3.client(
        's3',
        endpoint_url=R2_ENDPOINT_URL,
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4"),
    )


def list_profile_objects(client, user_id):
    """Lista todos los objetos en profiles/user_{id}/"""
    prefix = f"profiles/user_{user_id}/"
    objects = []
    paginator = client.get_paginator('list_objects_v2')
    for page in paginator.paginate(Bucket=R2_BUCKET_NAME, Prefix=prefix):
        if 'Contents' in page:
            for obj in page['Contents']:
                objects.append(obj)
    return objects


def copy_object(client, source_key, dest_key):
    """Copia un objeto dentro del mismo bucket."""
    copy_source = {'Bucket': R2_BUCKET_NAME, 'Key': source_key}
    client.copy_object(
        Bucket=R2_BUCKET_NAME,
        Key=dest_key,
        CopySource=copy_source,
    )


def delete_objects(client, keys):
    """Elimina múltiples objetos."""
    if not keys:
        return
    objects = [{'Key': k} for k in keys]
    client.delete_objects(Bucket=R2_BUCKET_NAME, Delete={'Objects': objects})


def main():
    client = get_r2_client()
    db = SessionLocal()
    
    try:
        # Usuarios activos que deben conservarse
        active_user_ids = [1, 6, 7, 9]
        
        # Obtener foto_perfil actual de la BD para usuarios activos
        users = db.query(Usuario).filter(Usuario.id_usuario.in_(active_user_ids)).all()
        current_profile_map = {}
        for u in users:
            if u.foto_perfil:
                current_profile_map[u.id_usuario] = u.foto_perfil
        
        print("=== Estado actual en BD ===")
        for uid, path in current_profile_map.items():
            print(f"  user_{uid}: {path}")
        
        # Procesar cada usuario activo
        for user_id in active_user_ids:
            prefix = f"profiles/user_{user_id}/"
            dest_key = f"profiles/user_{user_id}/profile.jpg"
            
            objects = list_profile_objects(client, user_id)
            print(f"\n=== user_{user_id} ({len(objects)} objetos) ===")
            
            if user_id in current_profile_map:
                current_path = current_profile_map[user_id]
                # Extraer la key R2 del path BD
                if current_path.startswith("/uploads/"):
                    source_key = current_path[len("/uploads/"):]
                    print(f"  Foto actual en BD: {source_key}")
                    
                    # Verificar que el objeto existe
                    try:
                        client.head_object(Bucket=R2_BUCKET_NAME, Key=source_key)
                        print(f"  Objeto existe en R2, copiando a {dest_key}...")
                        copy_object(client, source_key, dest_key)
                        print(f"  OK Copiado exitosamente")
                    except ClientError as e:
                        if e.response['Error']['Code'] == '404':
                            print(f"  ✗ Objeto no encontrado en R2: {source_key}")
                        else:
                            raise
                else:
                    print(f"  ✗ Path en BD no es formato esperado: {current_path}")
            else:
                print(f"  Sin foto_perfil en BD")
            
            # Listar objetos a eliminar (todos excepto profile.jpg)
            keys_to_delete = []
            for obj in objects:
                if obj['Key'] != dest_key:
                    keys_to_delete.append(obj['Key'])
                    print(f"  Eliminar: {obj['Key']} ({obj['Size']} bytes)")
            
            if keys_to_delete:
                delete_objects(client, keys_to_delete)
                print(f"  OK {len(keys_to_delete)} objetos eliminados")
            else:
                print(f"  Nada que eliminar")
        
        # Eliminar usuarios borrados (2, 5)
        deleted_user_ids = [2, 5]
        print("\n=== Usuarios eliminados ===")
        for user_id in deleted_user_ids:
            objects = list_profile_objects(client, user_id)
            if objects:
                keys = [obj['Key'] for obj in objects]
                print(f"  user_{user_id}: eliminando {len(keys)} objetos")
                for k in keys:
                    print(f"    - {k}")
                delete_objects(client, keys)
                print(f"  OK Eliminados")
            else:
                print(f"  user_{user_id}: sin objetos")
        
        # Verificación final
        print("\n=== Verificación final ===")
        for user_id in active_user_ids:
            objects = list_profile_objects(client, user_id)
            for obj in objects:
                print(f"  {obj['Key']} ({obj['Size']} bytes)")
        
        print("\nOK Limpieza completada")
        
    finally:
        db.close()


if __name__ == "__main__":
    main()