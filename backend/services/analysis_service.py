from typing import Any, Dict, Optional

from sqlalchemy.orm import Session

from models.core import Analisis, Imagen as ImagenModel, ModeloIA
from services.ia_provider import IAProvider, MockIAProvider


class AnalysisService:
    def __init__(self, provider: Optional[IAProvider] = None):
        self.provider = provider or MockIAProvider()

    def process_analysis(self, image_url: str, current_user_id: Optional[int] = None, db: Optional[Session] = None) -> Dict[str, Any]:
        if db is None:
            analysis_result = self.provider.analyze(image_url=image_url)
            return {
                "id": 1,
                "id_usuario": current_user_id or 1,
                "url_imagen": image_url,
                "resultado": analysis_result.get("resultado", ""),
                "estado": analysis_result.get("estado", "completado"),
                "humedad": analysis_result.get("humedad", 0.0),
                "calidad_del_aire": analysis_result.get("calidad_del_aire", "moderada"),
                "recomendacion": analysis_result.get("recomendacion", ""),
                "fecha_creacion": None,
            }
        return self.process(image_url=image_url, current_user_id=current_user_id or 1, db=db)

    def process(self, image_url: str, current_user_id: int, db: Session) -> Dict[str, Any]:
        modelo = db.query(ModeloIA).first()
        if not modelo:
            modelo = ModeloIA(nombre_modelo="modelo_demo", version="1.0", descripcion="Modelo temporal")
            db.add(modelo)
            db.commit()
            db.refresh(modelo)

        analysis_result = self.provider.analyze(image_url=image_url)

        nuevo_analisis = Analisis(
            id_usuario=current_user_id,
            id_modelo=modelo.id_modelo,
            resultado=analysis_result.get("resultado"),
            estado=analysis_result.get("estado"),
            humedad=analysis_result.get("humedad"),
            calidad_del_aire=analysis_result.get("calidad_del_aire"),
            recomendacion=analysis_result.get("recomendacion"),
        )
        db.add(nuevo_analisis)
        db.commit()
        db.refresh(nuevo_analisis)

        nombre_imagen = image_url.split("/")[-1] or "imagen"
        imagen = ImagenModel(
            id_analisis=nuevo_analisis.id_analisis,
            url=image_url,
            nombre=nombre_imagen,
            descripcion="Imagen enviada para análisis",
        )
        db.add(imagen)
        db.commit()
        db.refresh(imagen)

        return {
            "id": nuevo_analisis.id_analisis,
            "id_usuario": nuevo_analisis.id_usuario,
            "url_imagen": image_url,
            "resultado": nuevo_analisis.resultado,
            "estado": nuevo_analisis.estado,
            "humedad": nuevo_analisis.humedad,
            "calidad_del_aire": nuevo_analisis.calidad_del_aire,
            "recomendacion": nuevo_analisis.recomendacion,
            "fecha_creacion": nuevo_analisis.fecha_creacion,
        }

    def get_analysis_payload(self, analysis_id: int, db: Session) -> Optional[Dict[str, Any]]:
        analisis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
        if not analisis:
            return None

        imagen = db.query(ImagenModel).filter(ImagenModel.id_analisis == analisis.id_analisis).first()
        return {
            "id": analisis.id_analisis,
            "id_usuario": analisis.id_usuario,
            "url_imagen": imagen.url if imagen else "",
            "resultado": analisis.resultado,
            "estado": analisis.estado,
            "humedad": analisis.humedad,
            "calidad_del_aire": analisis.calidad_del_aire,
            "recomendacion": analisis.recomendacion,
            "fecha_creacion": analisis.fecha_creacion,
        }

    def get_status(self, analysis_id: int, db: Session) -> Optional[Dict[str, Any]]:
        payload = self.get_analysis_payload(analysis_id, db)
        if not payload:
            return None
        payload["progreso"] = 100 if payload.get("estado") == "completado" else 50
        return payload

    def get_humidity(self, analysis_id: int, db: Session) -> Optional[Dict[str, Any]]:
        payload = self.get_analysis_payload(analysis_id, db)
        if not payload:
            return None
        payload["ubicacion"] = "Sin ubicación registrada"
        return payload

    def get_air_quality(self, analysis_id: int, db: Session) -> Optional[Dict[str, Any]]:
        payload = self.get_analysis_payload(analysis_id, db)
        if not payload:
            return None
        payload["indice_calidad"] = {"buena": 35.0, "moderada": 55.0, "mala": 80.0}.get((payload.get("calidad_del_aire") or "moderada").lower(), 50.0)
        payload["contaminantes"] = {"PM2.5": 12.3, "PM10": 25.5, "NO2": 15.0}
        return payload

    def get_recommendation(self, analysis_id: int, db: Session) -> Optional[Dict[str, Any]]:
        payload = self.get_analysis_payload(analysis_id, db)
        if not payload:
            return None
        payload["prioridad"] = "alta"
        payload["acciones"] = ["Proteger el ecosistema", "Reducir contaminación", "Monitorear calidad del aire"]
        return payload

    def delete_analysis(self, analysis_id: int, db: Session) -> bool:
        analisis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
        if not analisis:
            return False

        imagenes = db.query(ImagenModel).filter(ImagenModel.id_analisis == analisis.id_analisis).all()
        for imagen in imagenes:
            db.delete(imagen)

        db.delete(analisis)
        db.commit()
        return True


MockAnalysisProvider = MockIAProvider
