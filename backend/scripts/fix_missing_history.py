import os
import sys
from pathlib import Path

# Asegurar que el directorio backend esté en el path para imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy.orm import Session
from models.core import Analisis, HistorialActividad
from config.db import SessionLocal

def fix_missing_history():
    session: Session = SessionLocal()
    try:
        analisis_list = session.query(Analisis).all()
        fixed = 0
        skipped = 0
        errors = 0

        for analysis in analisis_list:
            existing = session.query(HistorialActividad).filter(
                HistorialActividad.id_usuario == analysis.id_usuario,
                HistorialActividad.descripcion_accion.contains(f"analysis_id={analysis.id_analisis};")
            ).first()

            if existing:
                skipped += 1
                continue

            try:
                historial = HistorialActividad(
                    accion_realizada='analisis_guardado',
                    descripcion_accion=f'analysis_id={analysis.id_analisis}; location=',
                    id_usuario=analysis.id_usuario,
                )
                session.add(historial)
                session.commit()
                fixed += 1
            except Exception as exc:
                session.rollback()
                print(f"Error creando historial para análisis {analysis.id_analisis}: {exc}")
                errors += 1

        print(f"Reparación completada:")
        print(f"  - Analizados: {len(analisis_list)}")
        print(f"  - Corregidos: {fixed}")
        print(f"  - Ya existían: {skipped}")
        print(f"  - Errores: {errors}")
    finally:
        session.close()

if __name__ == "__main__":
    fix_missing_history()
