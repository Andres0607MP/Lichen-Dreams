from datetime import datetime, timedelta

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func, exists, and_, or_

from auth.auth_service import get_current_user
from config.db import get_db
from models.core import Analisis, Usuario, Imagen

router = APIRouter()


class DashboardStatsResponse(BaseModel):
    analysis_count: int
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
    analysis_count = db.query(Analisis).filter(Analisis.id_usuario == current_user.id_usuario).count()
    zone_count = db.query(Analisis.id_ubicacion).filter(
        Analisis.id_usuario == current_user.id_usuario,
        Analisis.id_ubicacion != None,
    ).distinct().count()

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
        'zone_count': zone_count,
        'air_quality': air_quality,
        'healthy_count': healthy_count,
        'affected_count': affected_count,
        'unknown_count': unknown_count,
    }
