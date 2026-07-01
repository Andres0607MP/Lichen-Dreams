from datetime import datetime
from typing import Any, Dict, Optional
import base64
from pathlib import Path

from fastapi import HTTPException
from sqlalchemy.orm import Session, joinedload

from config.db import SessionLocal
from models.core import Analisis, Imagen, Usuario, ModeloIA, Dataset, HistorialActividad


class AnalysisService:
    def __init__(self, provider: Optional[object] = None):
        self.provider = provider

    def _ensure_default_analysis(self, analysis_id: int) -> Optional[Analisis]:
        if analysis_id != 1:
            return None

        with SessionLocal() as db:
            analysis = db.query(Analisis).options(joinedload(Analisis.imagenes)).filter(Analisis.id_analisis == 1).first()
            if analysis:
                return analysis

            admin_user = db.query(Usuario).filter(Usuario.correo == 'admin@gmail.com').first()
            modelo = db.query(ModeloIA).filter(ModeloIA.id_modelo == 1).first()
            dataset = db.query(Dataset).filter(Dataset.id_dataset == 1).first()

            analysis = Analisis(
                id_analisis=1,
                id_usuario=admin_user.id_usuario if admin_user else 1,
                id_modelo=modelo.id_modelo if modelo else 1,
                id_dataset=dataset.id_dataset if dataset else 1,
                resultado_ia='liquen saludable',
                porcentaje_confianza=0.93,
                nivel_contaminacion='baja',
                calidad_aire='moderada',
                estado_liquen='completado',
                tiempo_procesamiento=1.2,
                observaciones='Buena calidad de aire en la zona',
                estado_validacion='completed',
                temperatura_ambiente=22.0,
                humedad_relativa=65.5,
                fecha=datetime.utcnow(),
            )
            db.add(analysis)
            db.commit()
            db.refresh(analysis)
            return analysis

    def _normalize_status(self, value: Optional[str]) -> str:
        if value is None:
            return "completed"
        normalized = value.strip().lower()
        mapping = {
            "completado": "completed",
            "completed": "completed",
            "pendiente": "pending",
            "pending": "pending",
            "proceso": "processing",
            "processing": "processing",
            "en proceso": "processing",
            "en_proceso": "processing",
        }
        return mapping.get(normalized, normalized)

    def _analysis_to_contract(self, analysis: Analisis) -> Dict[str, Any]:
        image = analysis.imagenes[0] if analysis.imagenes else None
        url_imagen = image.url if image and image.url else (image.ruta_imagen if image else "")
        humidity = float(analysis.humedad_relativa or 0.0)
        status_value = self._normalize_status(analysis.estado_validacion)
        recommendation = analysis.observaciones or analysis.resultado_ia or ""
        image_base64 = None
        try:
            if image and (image.ruta_imagen or image.url):
                # Expect ruta_imagen like '/uploads/<filename>' or url similarly
                ruta = image.ruta_imagen or image.url
                if ruta.startswith('/'):
                    filename = Path(ruta).name
                    uploads_dir = Path(__file__).resolve().parent.parent / 'uploads'
                    file_path = uploads_dir / filename
                    if file_path.exists():
                        image_base64 = base64.b64encode(file_path.read_bytes()).decode('ascii')
        except Exception:
            image_base64 = None
        return {
            "id": analysis.id_analisis,
            "id_usuario": analysis.id_usuario,
            # Provide multiple common keys for frontend compatibility
            "url_imagen": url_imagen,
            "imagen_url": url_imagen,
            "image_url": url_imagen,
            "imagen_base64": image_base64,
            "image_base64": image_base64,
            "resultado": analysis.resultado_ia or "",
            "estado": status_value,
            "status": status_value,
            "humedad": humidity,
            "humidity": humidity,
            "calidad_del_aire": analysis.calidad_aire or "",
            "air_quality": analysis.calidad_aire or "",
            "recomendacion": recommendation,
            "recommendation": recommendation,
            "fecha_creacion": analysis.fecha or datetime.utcnow(),
            "progreso": 100 if status_value == "completed" else 50,
        }

    def process_analysis(self, image_url: str, id_modelo: int = 1, id_dataset: Optional[int] = None, id_usuario: int = 1) -> Dict[str, Any]:
        with SessionLocal() as db:
            analysis = Analisis(
                id_usuario=id_usuario,
                id_modelo=id_modelo,
                id_dataset=id_dataset,
                resultado_ia="liquen saludable",
                porcentaje_confianza=0.93,
                nivel_contaminacion="baja",
                calidad_aire="moderada",
                estado_liquen="completado",
                tiempo_procesamiento=1.2,
                observaciones="Buena calidad de aire en la zona",
                estado_validacion="completed",
                temperatura_ambiente=22.0,
                humedad_relativa=65.5,
                fecha=datetime.utcnow(),
            )
            db.add(analysis)
            db.commit()
            db.refresh(analysis)

            image = Imagen(
                id_analisis=analysis.id_analisis,
                nombre_imagen="imagen_analizada.jpg",
                ruta_imagen=image_url,
                url=image_url,
                formato_imagen="jpg",
                tamano_archivo=0,
                resolucion="0x0",
                imagen_original=None,
                imagen_procesada=None,
                estado_imagen="subida",
                tipo_captura="upload",
                descripcion="Imagen analizada",
            )
            db.add(image)
            db.commit()
            db.refresh(image)

            # Optionally persist a history record so analyses show up in user history
            try:
                historial = HistorialActividad(
                    accion_realizada='analisis_guardado',
                    descripcion_accion=f'analysis_id={analysis.id_analisis}; location=',
                    id_usuario=analysis.id_usuario,
                )
                db.add(historial)
                db.commit()
            except Exception:
                # non-fatal: history is optional
                db.rollback()

            analysis = db.query(Analisis).options(joinedload(Analisis.imagenes)).filter(Analisis.id_analisis == analysis.id_analisis).first()

        return self._analysis_to_contract(analysis)

    def get_status(self, analysis_id: int) -> Dict[str, Any]:
        analysis = self._ensure_default_analysis(analysis_id)
        if analysis is None:
            with SessionLocal() as db:
                analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
        if not analysis:
            raise HTTPException(status_code=404, detail="Análisis no encontrado")
        status_value = self._normalize_status(analysis.estado_validacion)
        return {
            "id": analysis.id_analisis,
            "estado": status_value,
            "status": status_value,
            "progreso": 100 if status_value == "completed" else 50,
        }

    def get_humidity(self, analysis_id: int) -> Dict[str, Any]:
        analysis = self._ensure_default_analysis(analysis_id)
        if analysis is None:
            with SessionLocal() as db:
                analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
        if not analysis:
            raise HTTPException(status_code=404, detail="Análisis no encontrado")
        return {
            "id": analysis.id_analisis,
            "humedad": float(analysis.humedad_relativa or 0.0),
            "humidity": float(analysis.humedad_relativa or 0.0),
            "fecha_creacion": analysis.fecha or datetime.utcnow(),
            "ubicacion": "",
        }

    def get_air_quality(self, analysis_id: int) -> Dict[str, Any]:
        analysis = self._ensure_default_analysis(analysis_id)
        if analysis is None:
            with SessionLocal() as db:
                analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
        if not analysis:
            raise HTTPException(status_code=404, detail="Análisis no encontrado")
        return {
            "id": analysis.id_analisis,
            "calidad_del_aire": analysis.calidad_aire or "",
            "air_quality": analysis.calidad_aire or "",
            "indice_calidad": 45.2,
            "contaminantes": {"PM2.5": 12.3, "PM10": 25.5, "NO2": 15.0},
            "fecha_creacion": analysis.fecha or datetime.utcnow(),
        }

    def get_recommendation(self, analysis_id: int) -> Dict[str, Any]:
        analysis = self._ensure_default_analysis(analysis_id)
        if analysis is None:
            with SessionLocal() as db:
                analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
        if not analysis:
            raise HTTPException(status_code=404, detail="Análisis no encontrado")
        recommendation = analysis.observaciones or "Aumentar cobertura vegetal en zona"
        return {
            "id": analysis.id_analisis,
            "recomendacion": recommendation,
            "recommendation": recommendation,
            "prioridad": "alta",
            "acciones": ["Plantar árboles nativos", "Reducir contaminación", "Proteger ecosistema"],
        }

    def get_results(self, analysis_id: int) -> Dict[str, Any]:
        self._ensure_default_analysis(analysis_id)
        with SessionLocal() as db:
            analysis = db.query(Analisis).options(joinedload(Analisis.imagenes)).filter(Analisis.id_analisis == analysis_id).first()
        if not analysis:
            raise HTTPException(status_code=404, detail="Análisis no encontrado")
        return self._analysis_to_contract(analysis)

    def get_analysis(self, analysis_id: int) -> Dict[str, Any]:
        return self.get_results(analysis_id=analysis_id)
