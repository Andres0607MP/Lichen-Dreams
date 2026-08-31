from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func

from auth.auth_service import get_current_user
from config.db import get_db
from models.core import Usuario, Analisis, EspecieLiquen, Imagen, HistorialActividad, Reporte

router = APIRouter()


class EnvironmentalReportResponse(BaseModel):
    id_reporte: int
    titulo: str
    descripcion: Optional[str]
    tipo_reporte: Optional[str]
    formato_reporte: Optional[str]
    estado_reporte: Optional[str]
    fecha_generacion: datetime
    datos_reporte: Optional[dict] = None
    id_usuario: Optional[int] = None

    class Config:
        from_attributes = True


class EnvironmentalReportCreate(BaseModel):
    titulo: str
    descripcion: Optional[str] = None
    tipo_reporte: str = "ambiental"
    formato_reporte: str = "json"


class EnvironmentalReportStats(BaseModel):
    total_analisis: int
    zonas_analizadas: int
    liquidos_saludables: int
    liquidos_afectados: int
    liquidos_desconocidos: int
    calidad_aire_predominante: str
    nivel_contaminacion_predominante: Optional[str]
    temperatura_promedio: Optional[float]
    humedad_promedio: Optional[float]
    periodo: str
    fecha_generacion: datetime


def _calculate_environmental_stats(user_id: int, db: Session) -> dict:
    analysis_count = db.query(HistorialActividad).filter(
        HistorialActividad.id_usuario == user_id
    ).count()

    eligible_analyses = (
        db.query(Analisis)
        .filter(
            Analisis.id_usuario == user_id,
            Analisis.estado_validacion != 'error',
        )
        .all()
    )

    eligible_analyses = [
        a for a in eligible_analyses
        if any(img.tipo_captura != 'gallery' for img in a.imagenes)
    ]

    zone_count = db.query(Analisis.id_ubicacion).filter(
        Analisis.id_usuario == user_id,
        Analisis.id_ubicacion != None,
    ).distinct().count()

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

    contamination_levels = [a.nivel_contaminacion for a in eligible_analyses if a.nivel_contaminacion]
    predominant_contamination = None
    if contamination_levels:
        from collections import Counter
        predominant_contamination = Counter(contamination_levels).most_common(1)[0][0]

    temps = [a.temperatura_ambiente for a in eligible_analyses if a.temperatura_ambiente is not None]
    humids = [a.humedad_relativa for a in eligible_analyses if a.humedad_relativa is not None]

    species_rows = (
        db.query(
            EspecieLiquen.id_especie,
            EspecieLiquen.nombre_cientifico,
            EspecieLiquen.nombre_comun,
            func.count(Analisis.id_analisis),
        )
        .join(EspecieLiquen, Analisis.id_especie == EspecieLiquen.id_especie)
        .filter(Analisis.id_usuario == user_id, Analisis.id_especie.isnot(None))
        .group_by(
            EspecieLiquen.id_especie,
            EspecieLiquen.nombre_cientifico,
            EspecieLiquen.nombre_comun,
        )
        .all()
    )
    especies_registradas = [
        {
            "id": r[0],
            "nombre_cientifico": r[1],
            "nombre_comun": r[2],
            "cantidad": r[3],
        }
        for r in species_rows
    ]

    return {
        'total_analisis': analysis_count,
        'zonas_analizadas': zone_count,
        'liquidos_saludables': healthy_count,
        'liquidos_afectados': affected_count,
        'liquidos_desconocidos': unknown_count,
        'calidad_aire_predominante': air_quality,
        'nivel_contaminacion_predominante': predominant_contamination,
        'temperatura_promedio': round(sum(temps) / len(temps), 2) if temps else None,
        'humedad_promedio': round(sum(humids) / len(humids), 2) if humids else None,
        'especies_registradas': especies_registradas,
        'periodo': 'último período',
        'fecha_generacion': datetime.utcnow().isoformat(),
    }


@router.get('/', response_model=list[EnvironmentalReportResponse], summary="Obtener mis reportes ambientales")
def get_my_reports(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    reports = db.query(Reporte).filter(
        Reporte.id_usuario == current_user.id_usuario,
        Reporte.tipo_reporte == 'ambiental',
    ).order_by(Reporte.fecha_generacion.desc()).all()
    return reports


@router.get('/{report_id}', response_model=EnvironmentalReportResponse, summary="Obtener detalle de mi reporte")
def get_my_report(
    report_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    reporte = db.query(Reporte).filter(
        Reporte.id_reporte == report_id,
        Reporte.id_usuario == current_user.id_usuario,
    ).first()
    if not reporte:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Informe no encontrado")
    return reporte


@router.delete('/{report_id}', status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar mi reporte")
def delete_my_report(
    report_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    reporte = db.query(Reporte).filter(
        Reporte.id_reporte == report_id,
        Reporte.id_usuario == current_user.id_usuario,
    ).first()
    if not reporte:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Informe no encontrado")
    db.delete(reporte)
    db.commit()
    return None


@router.post('/environmental', response_model=EnvironmentalReportResponse, status_code=status.HTTP_201_CREATED, summary="Generar resumen ambiental")
def create_environmental_report(
    request: EnvironmentalReportCreate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stats = _calculate_environmental_stats(current_user.id_usuario, db)

    if stats['total_analisis'] == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No tienes análisis registrados para generar un resumen ambiental."
        )

    descripcion = (
        f"Resumen ambiental basado en {stats['total_analisis']} análisis. "
        f"Calidad del aire predominante: {stats['calidad_aire_predominante']}. "
        f"Zonas analizadas: {stats['zonas_analizadas']}."
    )

    reporte = Reporte(
        titulo=request.titulo,
        descripcion=descripcion,
        tipo_reporte=request.tipo_reporte,
        formato_reporte=request.formato_reporte,
        estado_reporte='completado',
        id_usuario=current_user.id_usuario,
        datos_reporte=stats,
    )
    db.add(reporte)
    db.commit()
    db.refresh(reporte)
    return reporte
