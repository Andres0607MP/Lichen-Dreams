#!/usr/bin/env python
"""Script para sincronizar la base de datos con schema.sql"""
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.dirname(__file__))

from config.database import engine
from sqlalchemy import text

def sync_database():
    """Sincronizar tablas con schema.sql"""
    with engine.connect() as connection:
        print("🔄 Sincronizando base de datos con schema.sql...")
        
        # ====================== USUARIOS TABLE ======================
        usuarios_columns = {
            'tipo_documento': 'VARCHAR(20) NULL',
            'numero_documento': 'VARCHAR(50) NULL',
            'foto_perfil': 'LONGTEXT NULL',
            'fecha_nacimiento': 'DATE NULL',
            'ultimo_acceso': 'TIMESTAMP NULL DEFAULT NULL',
            'estado_cuenta': 'VARCHAR(50) NULL',
        }
        
        print("\n📋 Actualizando tabla 'usuarios'...")
        for col_name, col_type in usuarios_columns.items():
            try:
                result = connection.execute(text(
                    f"SHOW COLUMNS FROM usuarios WHERE Field = '{col_name}'"
                ))
                if not result.fetchone():
                    connection.execute(text(
                        f"ALTER TABLE usuarios ADD COLUMN {col_name} {col_type}"
                    ))
                    connection.commit()
                    print(f"  ✓ Agregada columna '{col_name}'")
                else:
                    print(f"  ✓ Columna '{col_name}' ya existe")
            except Exception as e:
                print(f"  ⚠ Error en columna '{col_name}': {e}")
        
        # ====================== SESIONES TABLE ======================
        print("\n📋 Actualizando tabla 'sesiones'...")
        
        # Agregar sistema_operativo
        try:
            result = connection.execute(text(
                "SHOW COLUMNS FROM sesiones WHERE Field = 'sistema_operativo'"
            ))
            if not result.fetchone():
                connection.execute(text(
                    "ALTER TABLE sesiones ADD COLUMN sistema_operativo VARCHAR(100) NULL"
                ))
                connection.commit()
                print("  ✓ Agregada columna 'sistema_operativo'")
            else:
                print("  ✓ Columna 'sistema_operativo' ya existe")
        except Exception as e:
            print(f"  ⚠ Error al agregar 'sistema_operativo': {e}")
        
        # Cambiar fecha_vencimiento a fecha_expiracion si existe
        try:
            result = connection.execute(text(
                "SHOW COLUMNS FROM sesiones WHERE Field = 'fecha_vencimiento'"
            ))
            if result.fetchone():
                connection.execute(text(
                    "ALTER TABLE sesiones CHANGE COLUMN fecha_vencimiento fecha_expiracion TIMESTAMP NULL DEFAULT NULL"
                ))
                connection.commit()
                print("  ✓ Renombrada columna 'fecha_vencimiento' → 'fecha_expiracion'")
        except Exception as e:
            print(f"  ℹ Columna 'fecha_expiracion' ya configurada: {e}")
        
        print("\n✅ Sincronización completada exitosamente!")

if __name__ == "__main__":
    sync_database()
