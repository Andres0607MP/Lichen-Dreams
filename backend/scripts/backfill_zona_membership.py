"""Script para backfill de la tabla analisis_zonas_ambientales.

Este script debe ejecutarse después de aplicar la migración e2f3a4b5c6d7_add_zona_membership.py
para poblar la tabla de membresías con los datos existentes.
"""
import sys
import os

# Añadir el directorio raíz al path para poder importar los módulos del backend
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from sqlalchemy.orm import Session
from config.db import SessionLocal
from services.zone_membership import sync_all_zones
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def main():
    """Ejecuta el backfill de la tabla analisis_zonas_ambientales."""
    logger.info("Iniciando backfill de la tabla analisis_zonas_ambientales...")
    
    db = SessionLocal()
    try:
        total_associations = sync_all_zones(db)
        db.commit()
        logger.info(f"Backfill completado. Se crearon {total_associations} asociaciones entre análisis y zonas.")
    except Exception as e:
        db.rollback()
        logger.error(f"Error durante el backfill: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    main()