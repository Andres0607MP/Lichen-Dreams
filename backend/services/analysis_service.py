from datetime import datetime, timezone
from typing import Any, Dict, Optional, List
import base64
import logging
import time
from pathlib import Path

from fastapi import HTTPException
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import or_

from config.db import SessionLocal
from config.settings import normalize_image_path
from services.upload_service import download_image_from_r2
from services.weather_service import WeatherService
from models.core import Analisis, Imagen, Usuario, ModeloIA, Dataset, HistorialActividad, Ubicacion, EspecieLiquen, Notificacion, ProcesamientoIA
from services.zone_membership import sync_analysis_to_zones


class AnalysisService:
    def __init__(self, provider: Optional[object] = None):
        self.provider = provider

    def _ensure_owner_or_admin(self, analysis: Analisis, user_id: int) -> bool:
        with SessionLocal() as db:
            admin_user = db.query(Usuario).filter(Usuario.correo == 'admin@gmail.com').first()
        is_admin = admin_user is not None and user_id == admin_user.id_usuario
        return analysis.id_usuario == user_id or is_admin

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
                ruta = image.ruta_imagen or image.url
                # Download image from R2 and encode to base64
                image_bytes = download_image_from_r2(ruta)
                image_base64 = base64.b64encode(image_bytes).decode('ascii')
        except Exception:
            image_base64 = None
        return {
            "id": analysis.id_analisis,
            "id_usuario": analysis.id_usuario,
            "url_imagen": url_imagen,
            "imagen_url": url_imagen,
            "image_url": url_imagen,
            "imagen_base64": image_base64,
            "image_base64": image_base64,
            "resultado": analysis.resultado_ia or "",
            "categoria": analysis.resultado_ia or "",
            "confianza": float(analysis.porcentaje_confianza or 0.0),
            "nombre_especie": analysis.especie.nombre_cientifico if analysis.especie and analysis.especie.nombre_cientifico else None,
            "id_especie": analysis.id_especie,
            "especie_nombre_cientifico": analysis.especie.nombre_cientifico if analysis.especie and analysis.especie.nombre_cientifico else None,
            "especie_nombre_comun": analysis.especie.nombre_comun if analysis.especie else None,
            "estado": status_value,
            "status": status_value,
            "humedad": humidity,
            "humidity": humidity,
            "calidad_del_aire": analysis.calidad_aire or "",
            "air_quality": analysis.calidad_aire or "",
            "nivel_contaminacion": analysis.nivel_contaminacion or "",
            "contamination_level": analysis.nivel_contaminacion or "",
            "recomendacion": recommendation,
            "recommendation": recommendation,
            "fecha_creacion": analysis.fecha or datetime.now(timezone.utc),
            "progreso": 100 if status_value == "completed" else 50,
            "estado_validacion": analysis.estado_validacion or "",
            "visibilidad": analysis.visibilidad or "private",
        }

    def _resolve_id_modelo(self, db) -> int:
        """ID del modelo activo registrado, coherente con el .keras en uso.

        Resuelve la ruta del modelo activo vía resolver_modelo_activo (misma
        politica que lichen_classifier) y devuelve el id_modelo de esa fila.
        Si no se puede resolver, lanza ActiveModelError (NO id inventado 1).
        """
        from ia.resolver_modelo_activo import resolver_modelo_activo, ActiveModelError

        try:
            active = resolver_modelo_activo()
        except ActiveModelError as e:
            raise ActiveModelError(f"no se pudo resolver el modelo activo: {e}") from e

        rows = (
            db.query(ModeloIA)
            .filter(ModeloIA.estado_modelo == "activo")
            .order_by(ModeloIA.id_modelo.desc())
            .all()
        )
        import json as _json
        from pathlib import Path as _Path

        active_name = _Path(active).name
        for row in rows:
            f = None
            if row.observaciones:
                try:
                    f = _json.loads(row.observaciones).get("archivo")
                except Exception:
                    f = None
            if f and _Path(str(f)).name == active_name:
                return row.id_modelo
        raise ActiveModelError(
            f"el activo resuelto ({active}) no coincide con ninguna fila 'activa' en BD")

    def process_analysis(self, image_url: str, id_modelo: Optional[int] = None, id_dataset: Optional[int] = None, id_usuario: int = 1, id_ubicacion: Optional[int] = None, id_especie: Optional[int] = None, image_source: str = 'upload') -> Dict[str, Any]:
        from services.monitoring_service import monitoring_service

        # Generar un ID de seguimiento temporal para eventos SSE.
        # El id_analisis real de la BD no está disponible hasta después
        # de la inferencia, pero necesitamos un ID consistente para el
        # Monitor IA.
        tracking_id = int(time.time() * 1000) % 1000000

        monitoring_service.record_analysis_started(analysis_id=tracking_id)
        inference_start = time.perf_counter()
        inference_error_type: Optional[str] = None
        ia_result = None
        try:
            from ia.modelos.lichen_classifier import predict
            import tempfile
            import os

            # Download image from R2 to a temporary file
            image_bytes = download_image_from_r2(image_url)
            with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as temp_file:
                temp_file.write(image_bytes)
                temp_file_path = temp_file.name

            try:
                ia_result = predict(temp_file_path)
                resultado_ia = ia_result["categoria"]
                porcentaje_confianza = ia_result["confianza"]
                nivel_contaminacion = ia_result["nivel_contaminacion"]
                calidad_aire = ia_result["calidad_aire"]
                estado_liquen = "completado"
                estado_validacion = "completed"
            finally:
                # Clean up the temporary file
                if os.path.exists(temp_file_path):
                    os.unlink(temp_file_path)
        except Exception as e:
            inference_error_type = e.__class__.__name__
            logging.error(f"Error en predicción IA para {image_url}: {e}")
            resultado_ia = "error"
            porcentaje_confianza = 0.0
            nivel_contaminacion = "desconocida"
            calidad_aire = "desconocida"
            estado_liquen = "error"
            estado_validacion = "error"

        inference_time_ms = (time.perf_counter() - inference_start) * 1000.0

        # Registrar métricas de inferencia (silencioso: nunca rompe el flujo)
        try:
            monitoring_service.record_inference(
                success=inference_error_type is None,
                inference_time_ms=inference_time_ms,
                confidence=(ia_result["confianza"] if ia_result else None),
                category=(ia_result["categoria"] if ia_result else None),
                analysis_id=tracking_id,
                error_type=inference_error_type,
            )
        except Exception as mon_exc:
            logger_mon = logging.getLogger("lichdreams.monitoring")
            logger_mon.warning("Monitoring record_inference failed (ignored): %s", mon_exc)

        print(f"[PROCESS] ia_result={ia_result}")
        print(f"[PROCESS] resultado_ia={resultado_ia}")
        print(f"[PROCESS] image_source={image_source}")

        if resultado_ia == "liquen saludable":
            observaciones = "Calidad del aire buena. El liquen se encuentra en condiciones saludables."
        elif resultado_ia == "liquen contaminado":
            observaciones = "Calidad del aire comprometida. El liquen muestra signos de contaminación."
        elif resultado_ia == "liquen desconocido":
            observaciones = "No fue posible determinar la calidad del aire. Intenta con otra imagen."
        else:
            observaciones = f"Análisis completado: {resultado_ia}"

        categoria_normalizada = resultado_ia.strip().lower()
        if categoria_normalizada in ("liquen desconocido", "desconocido"):
            mensaje_rechazo = "La imagen no corresponde a un liquen o no fue posible identificarla. Intenta con otra fotografía."
            try:
                with SessionLocal() as db:
                    notificacion = Notificacion(
                        id_usuario=id_usuario,
                        titulo="Imagen no válida",
                        mensaje=f"analysis_id=0|{mensaje_rechazo}",
                        tipo_notificacion="analysis",
                        estado_notificacion="rejected",
                        fecha=datetime.now(timezone.utc),
                    )
                    db.add(notificacion)
                    db.flush()
                    db.commit()
            except Exception as exc:
                logging.error(f"Error al crear notificacion de rechazo: {exc}")
            return {
                "id": 0,
                "id_usuario": id_usuario,
                "url_imagen": image_url,
                "imagen_url": image_url,
                "image_url": image_url,
                "imagen_base64": None,
                "image_base64": None,
                "resultado": resultado_ia,
                "categoria": resultado_ia,
                "confianza": porcentaje_confianza,
                "nombre_especie": None,
                "id_especie": None,
                "especie_nombre_cientifico": None,
                "especie_nombre_comun": None,
                "estado": estado_validacion,
                "status": estado_validacion,
                "humedad": 0.0,
                "humidity": 0.0,
                "calidad_del_aire": calidad_aire,
                "air_quality": calidad_aire,
                "nivel_contaminacion": nivel_contaminacion,
                "contamination_level": nivel_contaminacion,
                "recomendacion": observaciones,
                "recommendation": observaciones,
                "fecha_creacion": datetime.now(timezone.utc),
                "progreso": 100 if estado_validacion == "completed" else 50,
                "estado_validacion": estado_validacion,
                "visibilidad": "private",
                "rechazado": True,
                "mensaje_rechazo": mensaje_rechazo,
            }

        if image_source == 'gallery':
            # For gallery, do not persist anything, return temporary result
            return {
                "id": -1,  # temporary id to indicate gallery result
                "id_usuario": id_usuario,
                "url_imagen": image_url,
                "imagen_url": image_url,
                "image_url": image_url,
                "imagen_base64": None,
                "image_base64": None,
                "resultado": resultado_ia,
                "categoria": resultado_ia,
                "confianza": porcentaje_confianza,
                "nombre_especie": None,  # gallery results do not store species info
                "estado": estado_validacion,
                "status": estado_validacion,
                "humedad": 0.0,
                "humidity": 0.0,
                "calidad_del_aire": calidad_aire,
                "air_quality": calidad_aire,
                "nivel_contaminacion": nivel_contaminacion,
                "contamination_level": nivel_contaminacion,
                "recomendacion": observaciones,
                "recommendation": observaciones,
                "fecha_creacion": datetime.now(timezone.utc),
                "progreso": 100 if estado_validacion == "completed" else 50,
                "estado_validacion": estado_validacion,
                "visibilidad": "private",
            }

        # Persistent flow for camera/upload
        with SessionLocal() as db:
            print(f"[PROCESS] GUARDANDO resultado_ia={resultado_ia} image_source={image_source}")
            # Coherencia archivo activo <-> registro BD: resolver el id_real
            # (nunca se hardcodea: corresponde al modelo que hizo la inferencia).
            resolved_model_id = self._resolve_id_modelo(db)
            print(f"[PROCESS] modelo activo id_modelo={resolved_model_id}")
            analysis_date = datetime.now(timezone.utc)
            humidity_value = None
            if id_ubicacion is not None:
                ubicacion = db.query(Ubicacion).filter(Ubicacion.id_ubicacion == id_ubicacion).first()
                if ubicacion is not None:
                    try:
                        lat = float(ubicacion.latitud)
                        lng = float(ubicacion.longitud)
                        humidity_value = WeatherService.get_humidity(lat, lng, analysis_date)
                    except (ValueError, TypeError, AttributeError):
                        humidity_value = None
            analysis = Analisis(
                id_usuario=id_usuario,
                id_modelo=resolved_model_id,
                id_dataset=id_dataset,
                id_especie=id_especie,
                resultado_ia=resultado_ia,
                porcentaje_confianza=porcentaje_confianza,
                nivel_contaminacion=nivel_contaminacion,
                calidad_aire=calidad_aire,
                estado_liquen=estado_liquen,
                tiempo_procesamiento=1.2,
                observaciones=observaciones,
                estado_validacion=estado_validacion,
                visibilidad="private",
                temperatura_ambiente=22.0,
                humedad_relativa=humidity_value,
                fecha=analysis_date,
                id_ubicacion=id_ubicacion,
            )
            db.add(analysis)
            db.flush()

            notificacion = Notificacion(
                id_usuario=id_usuario,
                titulo="Análisis en proceso",
                mensaje=f"analysis_id={analysis.id_analisis}|Análisis en proceso",
                tipo_notificacion="analysis",
                estado_notificacion="processing",
                fecha=datetime.now(timezone.utc),
            )
            db.add(notificacion)
            db.flush()
            print(f"[NOTIFICACION] creada processing para analysis_id={analysis.id_analisis}")

            image = Imagen(
                id_analisis=analysis.id_analisis,
                nombre_imagen="imagen_analizada.jpg",
                ruta_imagen=normalize_image_path(image_url),
                url=normalize_image_path(image_url),
                formato_imagen="jpg",
                tamano_archivo=0,
                resolucion="0x0",
                imagen_original=None,
                imagen_procesada=None,
                estado_imagen="subida",
                tipo_captura=image_source,
                descripcion="Imagen analizada",
            )
            db.add(image)
            db.flush()

            modelo_ia = db.query(ModeloIA).filter(ModeloIA.id_modelo == resolved_model_id).first()
            precision_modelo = float(modelo_ia.precision_modelo) if modelo_ia and modelo_ia.precision_modelo is not None else None

            procesamiento = ProcesamientoIA(
                id_analisis=analysis.id_analisis,
                tiempo_ejecucion=1.2,
                porcentaje_precision=porcentaje_confianza,
                precision_modelo=precision_modelo,
                cantidad_objetos_detectados=None,
                resultado_segmentacion=None,
                observaciones=f"Clasificación IA: {resultado_ia}",
            )
            db.add(procesamiento)
            db.flush()
            print(f"[PROCESAMIENTO_IA] creado para analysis_id={analysis.id_analisis}")

            should_save_history = (
                estado_validacion != "error"
                and not (image_source == "gallery" and resultado_ia == "liquen saludable")
            )
            if should_save_history:
                historial = HistorialActividad(
                    accion_realizada='analisis_guardado',
                    descripcion_accion=f'analysis_id={analysis.id_analisis}; source={image_source}',
                    id_usuario=analysis.id_usuario,
                )
                db.add(historial)

            if estado_validacion == "completed":
                db.query(Notificacion).filter(
                    Notificacion.id_usuario == id_usuario,
                    Notificacion.tipo_notificacion == "analysis",
                    Notificacion.mensaje.like(f"analysis_id={analysis.id_analisis}|%"),
                ).update({
                    Notificacion.titulo: "Tu análisis está listo",
                    Notificacion.estado_notificacion: "completed",
                    Notificacion.mensaje: f"analysis_id={analysis.id_analisis}|Resultado disponible",
                    Notificacion.fecha: datetime.now(timezone.utc),
                }, synchronize_session=False)
                print(f"[NOTIFICACION] completada analysis_id={analysis.id_analisis}")
            else:
                db.query(Notificacion).filter(
                    Notificacion.id_usuario == id_usuario,
                    Notificacion.tipo_notificacion == "analysis",
                    Notificacion.mensaje.like(f"analysis_id={analysis.id_analisis}|%"),
                ).update({
                    Notificacion.titulo: "Análisis fallido",
                    Notificacion.estado_notificacion: "failed",
                    Notificacion.mensaje: f"analysis_id={analysis.id_analisis}|No se pudo completar",
                    Notificacion.fecha: datetime.now(timezone.utc),
                }, synchronize_session=False)
                print(f"[NOTIFICACION] fallida analysis_id={analysis.id_analisis}")

            try:
                db.commit()
            except Exception as exc:
                db.rollback()
                logging.error(f"Error al guardar historial para análisis {analysis.id_analisis}: {exc}")
                raise

            db.refresh(analysis)
            db.refresh(image)

            # Sincronizar membresía de zonas: asociar el análisis a las zonas
            # cuyo círculo geográfico contiene la ubicación del análisis.
            try:
                sync_analysis_to_zones(db, analysis.id_analisis, analysis.id_ubicacion)
                db.commit()
            except Exception as sync_exc:
                db.rollback()
                logging.error(f"Error al sincronizar zonas para análisis {analysis.id_analisis}: {sync_exc}")

            analysis = db.query(Analisis).options(
                joinedload(Analisis.imagenes),
                joinedload(Analisis.especie),
            ).filter(Analisis.id_analisis == analysis.id_analisis).first()

        return self._analysis_to_contract(analysis)

    def get_status(self, analysis_id: int, user_id: Optional[int] = None) -> Dict[str, Any]:
        with SessionLocal() as db:
            analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
            if not analysis:
                raise HTTPException(status_code=404, detail="Análisis no encontrado")
            if user_id is not None and not self._ensure_owner_or_admin(analysis, user_id):
                raise HTTPException(status_code=403, detail="No tienes acceso a este análisis")
            status_value = self._normalize_status(analysis.estado_validacion)
            image = analysis.imagenes[0] if analysis.imagenes else None
            image_url = ""
            if image:
                image_url = image.url or image.ruta_imagen or ""
            return {
                "id": analysis.id_analisis,
                "id_usuario": analysis.id_usuario,
                "url_imagen": image_url,
                "resultado": analysis.resultado_ia or "",
                "categoria": analysis.resultado_ia or "",
                "confianza": float(analysis.porcentaje_confianza or 0.0),
                "nombre_especie": analysis.especie.nombre_cientifico if analysis.especie and analysis.especie.nombre_cientifico else None,
                "id_especie": analysis.id_especie,
                "especie_nombre_cientifico": analysis.especie.nombre_cientifico if analysis.especie and analysis.especie.nombre_cientifico else None,
                "especie_nombre_comun": analysis.especie.nombre_comun if analysis.especie else None,
                "estado": status_value,
                "status": status_value,
                "humedad": float(analysis.humedad_relativa or 0.0),
                "humidity": float(analysis.humedad_relativa or 0.0),
                "calidad_del_aire": analysis.calidad_aire or "",
                "air_quality": analysis.calidad_aire or "",
                "recomendacion": analysis.observaciones or "",
                "recommendation": analysis.observaciones or "",
                "imagen_base64": None,
                "image_base64": None,
                "fecha_creacion": analysis.fecha or datetime.now(timezone.utc),
                "rechazado": False,
                "mensaje_rechazo": None,
                "progreso": 100 if status_value == "completed" else 50,
            }

    def get_humidity(self, analysis_id: int, user_id: Optional[int] = None) -> Dict[str, Any]:
        with SessionLocal() as db:
            analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
            if not analysis:
                raise HTTPException(status_code=404, detail="Análisis no encontrado")
            if user_id is not None and not self._ensure_owner_or_admin(analysis, user_id):
                raise HTTPException(status_code=403, detail="No tienes acceso a este análisis")
            especie_nombre_cientifico = analysis.especie.nombre_cientifico if analysis.especie and analysis.especie.nombre_cientifico else None
            especie_nombre_comun = analysis.especie.nombre_comun if analysis.especie else None
            id_especie = analysis.id_especie
        return {
            "id": analysis.id_analisis,
            "id_usuario": analysis.id_usuario,
            "url_imagen": "",
            "resultado": analysis.resultado_ia or "",
            "categoria": analysis.resultado_ia or "",
            "confianza": float(analysis.porcentaje_confianza or 0.0),
            "nombre_especie": especie_nombre_cientifico,
            "id_especie": id_especie,
            "especie_nombre_cientifico": especie_nombre_cientifico,
            "especie_nombre_comun": especie_nombre_comun,
            "estado": self._normalize_status(analysis.estado_validacion),
            "status": self._normalize_status(analysis.estado_validacion),
            "humedad": float(analysis.humedad_relativa or 0.0),
            "humidity": float(analysis.humedad_relativa or 0.0),
            "calidad_del_aire": analysis.calidad_aire or "",
            "air_quality": analysis.calidad_aire or "",
            "recomendacion": analysis.observaciones or "",
            "recommendation": analysis.observaciones or "",
            "imagen_base64": None,
            "image_base64": None,
            "fecha_creacion": analysis.fecha or datetime.now(timezone.utc),
            "ubicacion": "",
        }

    def get_air_quality(self, analysis_id: int, user_id: Optional[int] = None) -> Dict[str, Any]:
        with SessionLocal() as db:
            analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
            if not analysis:
                raise HTTPException(status_code=404, detail="Análisis no encontrado")
            if user_id is not None and not self._ensure_owner_or_admin(analysis, user_id):
                raise HTTPException(status_code=403, detail="No tienes acceso a este análisis")
            especie_nombre_cientifico = analysis.especie.nombre_cientifico if analysis.especie and analysis.especie.nombre_cientifico else None
            especie_nombre_comun = analysis.especie.nombre_comun if analysis.especie else None
            id_especie = analysis.id_especie
        return {
            "id": analysis.id_analisis,
            "id_usuario": analysis.id_usuario,
            "url_imagen": "",
            "resultado": analysis.resultado_ia or "",
            "categoria": analysis.resultado_ia or "",
            "confianza": float(analysis.porcentaje_confianza or 0.0),
            "nombre_especie": especie_nombre_cientifico,
            "id_especie": id_especie,
            "especie_nombre_cientifico": especie_nombre_cientifico,
            "especie_nombre_comun": especie_nombre_comun,
            "estado": self._normalize_status(analysis.estado_validacion),
            "status": self._normalize_status(analysis.estado_validacion),
            "humedad": float(analysis.humedad_relativa or 0.0),
            "humidity": float(analysis.humedad_relativa or 0.0),
            "calidad_del_aire": analysis.calidad_aire or "",
            "air_quality": analysis.calidad_aire or "",
            "recomendacion": analysis.observaciones or "",
            "recommendation": analysis.observaciones or "",
            "imagen_base64": None,
            "image_base64": None,
            "fecha_creacion": analysis.fecha or datetime.now(timezone.utc),
            "indice_calidad": 45.2,
            "contaminantes": {"PM2.5": 12.3, "PM10": 25.5, "NO2": 15.0},
        }

    def get_recommendation(self, analysis_id: int, user_id: Optional[int] = None) -> Dict[str, Any]:
        with SessionLocal() as db:
            analysis = db.query(Analisis).filter(Analisis.id_analisis == analysis_id).first()
            if not analysis:
                raise HTTPException(status_code=404, detail="Análisis no encontrado")
            if user_id is not None and not self._ensure_owner_or_admin(analysis, user_id):
                raise HTTPException(status_code=403, detail="No tienes acceso a este análisis")
            especie_nombre_cientifico = analysis.especie.nombre_cientifico if analysis.especie and analysis.especie.nombre_cientifico else None
            especie_nombre_comun = analysis.especie.nombre_comun if analysis.especie else None
            id_especie = analysis.id_especie
        recommendation = analysis.observaciones or "Aumentar cobertura vegetal en zona"
        return {
            "id": analysis.id_analisis,
            "id_usuario": analysis.id_usuario,
            "url_imagen": "",
            "resultado": analysis.resultado_ia or "",
            "categoria": analysis.resultado_ia or "",
            "confianza": float(analysis.porcentaje_confianza or 0.0),
            "nombre_especie": especie_nombre_cientifico,
            "id_especie": id_especie,
            "especie_nombre_cientifico": especie_nombre_cientifico,
            "especie_nombre_comun": especie_nombre_comun,
            "estado": self._normalize_status(analysis.estado_validacion),
            "status": self._normalize_status(analysis.estado_validacion),
            "humedad": float(analysis.humedad_relativa or 0.0),
            "humidity": float(analysis.humedad_relativa or 0.0),
            "calidad_del_aire": analysis.calidad_aire or "",
            "air_quality": analysis.calidad_aire or "",
            "recomendacion": recommendation,
            "recommendation": recommendation,
            "imagen_base64": None,
            "image_base64": None,
            "fecha_creacion": analysis.fecha or datetime.now(timezone.utc),
            "prioridad": "alta",
            "acciones": ["Plantar árboles nativos", "Reducir contaminación", "Proteger ecosistema"],
        }

    def get_results(self, analysis_id: int, user_id: Optional[int] = None) -> Dict[str, Any]:
        with SessionLocal() as db:
            analysis = db.query(Analisis).options(joinedload(Analisis.imagenes), joinedload(Analisis.especie)).filter(Analisis.id_analisis == analysis_id).first()
        if not analysis:
            raise HTTPException(status_code=404, detail="Análisis no encontrado")
        if user_id is not None and not self._ensure_owner_or_admin(analysis, user_id):
            raise HTTPException(status_code=403, detail="No tienes acceso a este análisis")
        return self._analysis_to_contract(analysis)

    def get_analysis(self, analysis_id: int, user_id: Optional[int] = None) -> Dict[str, Any]:
        return self.get_results(analysis_id=analysis_id, user_id=user_id)

    def get_map_points(self, user_id: int) -> List[Dict[str, Any]]:
        with SessionLocal() as db:
            analyses = db.query(Analisis).options(
                joinedload(Analisis.ubicacion),
                joinedload(Analisis.especie),
                joinedload(Analisis.usuario),
            ).filter(
                Analisis.id_ubicacion.isnot(None),
                or_(
                    Analisis.id_usuario == user_id,
                    Analisis.visibilidad == 'shared'
                )
            ).order_by(Analisis.fecha.desc()).all()

            results = []

            for analysis in analyses:
                ubicacion = analysis.ubicacion
                especie = analysis.especie
                usuario = analysis.usuario

                if ubicacion is None or ubicacion.latitud is None or ubicacion.longitud is None:
                    continue

                lat = float(ubicacion.latitud)
                lng = float(ubicacion.longitud)
                location_id = ubicacion.id_ubicacion

                zone_name = ubicacion.municipio or ubicacion.direccion or 'Zona sin nombre'
                if ubicacion.direccion and ubicacion.municipio:
                    zone_name = f"{ubicacion.direccion}, {ubicacion.municipio}"

                species = especie.nombre_cientifico if especie and especie.nombre_cientifico else 'Especie desconocida'

                status_value = self._normalize_status(analysis.estado_validacion)

                usuario_payload = None
                if usuario is not None:
                    usuario_payload = {
                        "id": usuario.id_usuario,
                        "nombre": usuario.nombre or "Usuario",
                        "foto_perfil": usuario.foto_perfil or "",
                    }

                analysis_payload = {
                    "id": analysis.id_analisis,
                    "resultado": analysis.resultado_ia or "",
                    "categoria": analysis.resultado_ia or "",
                    "confianza": float(analysis.porcentaje_confianza or 0.0),
                    "nombre_especie": especie.nombre_cientifico if especie and especie.nombre_cientifico else None,
                    "estado": status_value,
                    "status": status_value,
                    "humedad": float(analysis.humedad_relativa or 0.0),
                    "humidity": float(analysis.humedad_relativa or 0.0),
                    "calidad_del_aire": analysis.calidad_aire or "",
                    "air_quality": analysis.calidad_aire or "",
                    "recomendacion": analysis.observaciones or analysis.resultado_ia or "",
                    "recommendation": analysis.observaciones or analysis.resultado_ia or "",
                    "fecha_creacion": analysis.fecha or datetime.now(timezone.utc),
                    "visibilidad": analysis.visibilidad or "private",
                }

                results.append({
                    "id": analysis.id_analisis,
                    "id_usuario": analysis.id_usuario,
                    "lat": lat,
                    "lng": lng,
                    "zone_name": zone_name,
                    "air_quality": analysis.calidad_aire or "desconocida",
                    "contamination_level": analysis.nivel_contaminacion,
                    "species": species,
                    "confidence": float(analysis.porcentaje_confianza or 0.0),
                    "date": analysis.fecha or datetime.now(timezone.utc),
                    "status": status_value,
                    "visibilidad": analysis.visibilidad or "private",
                    "usuario": usuario_payload,
                    "analysis_count": 1,
                    "analyses": [analysis_payload],
                })

            return results
