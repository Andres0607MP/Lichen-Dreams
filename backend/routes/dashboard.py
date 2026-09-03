from datetime import datetime, timedelta

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func, exists, and_, or_

from auth.auth_service import get_current_user
from config.db import get_db
from models.core import Analisis, Usuario, Imagen, HistorialActividad, ZonaAmbiental

router = APIRouter()


class DashboardStatsResponse(BaseModel):
    analysis_count: int
    ubicaciones_count: int
    zonas_ambientales_count: int
    zone_count: int
    air_quality: str
    healthy_count: int = 0
    affected_count: int = 0
    unknown_count: int = 0


@router.get('/stats', response_model=DashboardStatsResponse, summary='Obtener estadísticas del dashboard por usuario')
def get_dashboard_stats(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # El contador de análisis debe reflejar los mismos registros que se muestran
    # en el Historial (HistorialActividad). Contar directo la tabla `analisis`
    # producía desfases (p. ej. análisis huérfanos que ya no aparecen en el
    # historial o procesos fallidos que jamás se guardaron).
    analysis_count = db.query(HistorialActividad).filter(
        HistorialActividad.id_usuario == current_user.id_usuario
    ).count()
    # Contador de ubicaciones (puntos GPS únicos) visitados por el usuario.
    # Se renombra semanticamente: esto NO son Zonas Ambientales.
    ubicaciones_count = db.query(Analisis.id_ubicacion).filter(
        Analisis.id_usuario == current_user.id_usuario,
        Analisis.id_ubicacion != None,
    ).distinct().count()

    # Contador real de Zonas Ambientales del catálogo.
    zonas_ambientales_count = db.query(ZonaAmbiental).count()

    eligible_analyses = (
        db.query(Analisis)
        .filter(
            Analisis.id_usuario == current_user.id_usuario,
            Analisis.estado_validacion != 'error',
            exists().where(
                and_(
                    Imagen.id_analisis == Analisis.id_analisis,
                    Imagen.tipo_captura != 'gallery'
                )
            )
        )
        .all()
    )

    healthy_count = sum(1 for a in eligible_analyses if a.resultado_ia == 'liquen saludable')
    affected_count = sum(1 for a in eligible_analyses if a.resultado_ia == 'liquen contaminado')
    unknown_count = sum(1 for a in eligible_analyses if a.resultado_ia == 'liquen desconocido')

    total_eligible = healthy_count + affected_count

    if total_eligible == 0:
        air_quality = 'desconocida'
    elif healthy_count > affected_count:
        air_quality = 'buena'
    elif affected_count > healthy_count:
        air_quality = 'mala'
    else:
        air_quality = 'moderada'

    return {
        'analysis_count': analysis_count,
        'ubicaciones_count': ubicaciones_count,
        'zonas_ambientales_count': zonas_ambientales_count,
        'zone_count': zonas_ambientales_count,
        'air_quality': air_quality,
        'healthy_count': healthy_count,
        'affected_count': affected_count,
        'unknown_count': unknown_count,
    }
