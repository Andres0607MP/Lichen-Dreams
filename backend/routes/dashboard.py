from datetime import datetime, timedelta

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from auth.auth_service import get_current_user
from config.db import get_db
from models.core import Analisis, Usuario

router = APIRouter()


class DashboardStatsResponse(BaseModel):
    analysis_count: int
    zone_count: int
    air_quality: str


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
    latest_analysis = db.query(Analisis).filter(
        Analisis.id_usuario == current_user.id_usuario,
    ).order_by(Analisis.fecha.desc()).first()

    air_quality = 'desconocida'
    if latest_analysis and latest_analysis.calidad_aire:
        air_quality = latest_analysis.calidad_aire

    return {
        'analysis_count': analysis_count,
        'zone_count': zone_count,
        'air_quality': air_quality,
    }
