#!/usr/bin/env python3
"""
Script único de limpieza: elimina definitivamente usuarios que quedaron con
estado_cuenta = "eliminado" (soft delete antiguo).

Este script reutiliza la misma lógica de hard delete que el endpoint
DELETE /admin/users/{id} para garantizar consistencia total.

Uso:
    python -m scripts.cleanup_soft_deleted_users [--dry-run] [--limit N]

Opciones:
    --dry-run    Solo muestra qué usuarios se eliminarían sin hacer cambios
    --limit N    Máximo de usuarios a procesar (default: todos)
"""

import sys
import logging
from typing import List, Optional

# Configurar logging antes de importar módulos que lo usan
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

# Importar después de configurar logging
from sqlalchemy.orm import Session

from config.db import SessionLocal
from models.core import (
    Usuario, Sesion, Analisis, Notificacion, Reporte,
    HistorialActividad, RecoveryCode, EmailVerificationToken,
    PasswordResetToken
)
from services.upload_service import delete_user_r2_objects


def get_users_to_cleanup(db: Session) -> List[Usuario]:
    """Obtiene todos los usuarios con estado_cuenta = 'eliminado'."""
    return db.query(Usuario).filter(Usuario.estado_cuenta == "eliminado").all()


def hard_delete_user(db: Session, user: Usuario) -> tuple[bool, str]:
    """
    Elimina definitivamente un usuario y todos sus datos asociados.
    
    Returns:
        (success, message)
    """
    user_id = user.id_usuario
    user_email = user.correo
    
    try:
        # 1. Eliminar objetos R2 asociados
        try:
            delete_user_r2_objects(user_id)
            logger.info(f"  R2 cleanup done for user {user_id}")
        except Exception as e:
            logger.warning(f"  Error limpiando R2 para usuario {user_id}: {e}")
            # No fallar por R2, continuar con BD
        
        # 2. Eliminar dependencias en orden (respetando FKs)
        # Usar synchronize_session=False para mejor performance
        deleted_counts = {}
        
        deleted_counts['recovery_codes'] = db.query(RecoveryCode).filter(
            RecoveryCode.id_usuario == user_id
        ).delete(synchronize_session=False)
        
        deleted_counts['email_verification_tokens'] = db.query(EmailVerificationToken).filter(
            EmailVerificationToken.id_usuario == user_id
        ).delete(synchronize_session=False)
        
        deleted_counts['password_reset_tokens'] = db.query(PasswordResetToken).filter(
            PasswordResetToken.id_usuario == user_id
        ).delete(synchronize_session=False)
        
        deleted_counts['notificaciones'] = db.query(Notificacion).filter(
            Notificacion.id_usuario == user_id
        ).delete(synchronize_session=False)
        
        deleted_counts['reportes'] = db.query(Reporte).filter(
            Reporte.id_usuario == user_id
        ).delete(synchronize_session=False)
        
        deleted_counts['historial_actividad'] = db.query(HistorialActividad).filter(
            HistorialActividad.id_usuario == user_id
        ).delete(synchronize_session=False)
        
        # Analisis cascada borra imagenes, procesamiento_ia, analisis_zonas_ambientales
        deleted_counts['analisis'] = db.query(Analisis).filter(
            Analisis.id_usuario == user_id
        ).delete(synchronize_session=False)
        
        deleted_counts['sesiones'] = db.query(Sesion).filter(
            Sesion.id_usuario == user_id
        ).delete(synchronize_session=False)
        
        # 3. Finalmente borrar el usuario
        db.delete(user)
        db.commit()
        
        return True, f"Usuario {user_id} ({user_email}) eliminado correctamente. Detalles: {deleted_counts}"
        
    except Exception as e:
        db.rollback()
        return False, f"Error eliminando usuario {user_id} ({user_email}): {e}"


def run_cleanup(dry_run: bool = False, limit: Optional[int] = None) -> dict:
    """
    Ejecuta la limpieza de usuarios con estado_cuenta = 'eliminado'.
    
    Args:
        dry_run: Si True, solo muestra qué se haría sin cambios
        limit: Máximo de usuarios a procesar
    
    Returns:
        Diccionario con estadísticas de la ejecución
    """
    db = SessionLocal()
    stats = {
        "total_found": 0,
        "processed": 0,
        "success": 0,
        "failed": 0,
        "errors": [],
        "dry_run": dry_run
    }
    
    try:
        users = get_users_to_cleanup(db)
        stats["total_found"] = len(users)
        
        if limit:
            users = users[:limit]
            logger.info(f"Limitando a {limit} usuarios de {stats['total_found']} encontrados")
        
        if not users:
            logger.info("No hay usuarios con estado_cuenta = 'eliminado' para limpiar")
            return stats
        
        logger.info(f"Encontrados {len(users)} usuario(s) con estado_cuenta = 'eliminado'")
        
        for user in users:
            stats["processed"] += 1
            user_id = user.id_usuario
            user_email = user.correo
            
            logger.info(f"Procesando {stats['processed']}/{len(users)}: usuario {user_id} ({user_email})")
            
            if dry_run:
                logger.info(f"  [DRY-RUN] Se eliminaría usuario {user_id} ({user_email})")
                stats["success"] += 1
                continue
            
            success, message = hard_delete_user(db, user)
            
            if success:
                stats["success"] += 1
                logger.info(f"  OK: {message}")
            else:
                stats["failed"] += 1
                stats["errors"].append(message)
                logger.error(f"  FALLO: {message}")
        
        return stats
        
    finally:
        db.close()


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Limpieza única de usuarios soft-deleted (estado_cuenta='eliminado')"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Solo muestra qué usuarios se eliminarían sin hacer cambios"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Máximo de usuarios a procesar"
    )
    
    args = parser.parse_args()
    
    logger.info("=" * 60)
    logger.info("INICIANDO LIMPIEZA DE USUARIOS SOFT-DELETED")
    logger.info("=" * 60)
    
    if args.dry_run:
        logger.info("MODO DRY-RUN: No se harán cambios reales")
    
    stats = run_cleanup(dry_run=args.dry_run, limit=args.limit)
    
    logger.info("=" * 60)
    logger.info("RESUMEN DE LIMPIEZA")
    logger.info("=" * 60)
    logger.info(f"Total encontrados: {stats['total_found']}")
    logger.info(f"Procesados: {stats['processed']}")
    logger.info(f"Eliminados correctamente: {stats['success']}")
    logger.info(f"Fallidos: {stats['failed']}")
    
    if stats["errors"]:
        logger.info("Errores:")
        for err in stats["errors"]:
            logger.info(f"  - {err}")
    
    if stats["failed"] > 0:
        logger.warning("Algunos usuarios no pudieron eliminarse. Revisar errores arriba.")
        sys.exit(1)
    else:
        logger.info("Limpieza completada exitosamente.")
        sys.exit(0)


if __name__ == "__main__":
    main()