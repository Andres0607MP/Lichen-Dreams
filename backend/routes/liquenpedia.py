from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, HTTPException, status, Depends, Query
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import or_

from config.db import get_db
from config.settings import normalize_image_path
from models.core import LiquenPedia, Usuario, CategoriaArticulo
from models.validations import ArticuloCreate, ArticuloUpdate
from auth.auth_service import get_current_user, get_current_user_optional
from auth.jwt_handler import decode_token

router = APIRouter()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)


class ArticleResponse(BaseModel):
    id_articulo: int
    titulo: str
    contenido: str
    autor: Optional[str]
    categoria: Optional[str]
    imagen_articulo: Optional[str] = None
    estado_publicacion: Optional[str] = None
    fecha_publicacion: datetime
    fecha_actualizacion: Optional[datetime] = None

    class Config:
        from_attributes = True


def verify_admin(current_user: Usuario = Depends(get_current_user)):
    """Verifica que el usuario sea administrador."""
    if current_user.rol is None or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso"
        )
    return current_user


@router.get("", response_model=List[ArticleResponse], summary="Listar artículos (público)")
def list_articles(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    search: str = Query(None),
    categoria: str = Query(None),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user_optional)
):
    """Listar artículos con búsqueda y paginación.
    
    - Usuarios no autenticados: solo artículos publicados
    - Usuarios normales: solo artículos publicados
    - Admins: todos los estados (draft, published, archived)
    """
    query = db.query(LiquenPedia)
    
    # Si no es admin, mostrar solo published
    is_admin = (current_user and current_user.rol and current_user.rol.nombre_rol == 'admin')
    if not is_admin:
        query = query.filter(LiquenPedia.estado_publicacion == 'published')
    
    # Búsqueda por título, contenido, categoría
    if search:
        query = query.filter(
            or_(
                LiquenPedia.titulo.ilike(f"%{search}%"),
                LiquenPedia.contenido.ilike(f"%{search}%"),
                LiquenPedia.categoria.ilike(f"%{search}%")
            )
        )
    
    if categoria:
        query = query.filter(LiquenPedia.categoria.ilike(f"%{categoria}%"))
    
    # Ordenar por fecha de actualización descendente
    query = query.order_by(LiquenPedia.fecha_actualizacion.desc())
    
    # Paginación
    articulos = query.offset(skip).limit(limit).all()
    
    # Convertir a dict con información de categoría
    result = []
    for art in articulos:
        categoria_nombre = None
        if art.id_categoria:
            cat_obj = db.query(CategoriaArticulo).filter(CategoriaArticulo.id_categoria == art.id_categoria).first()
            if cat_obj:
                categoria_nombre = cat_obj.nombre_categoria
        result.append({
            "id_articulo": art.id_articulo,
            "titulo": art.titulo,
            "contenido": art.contenido,
            "autor": art.autor,
            "categoria": art.categoria,
            "id_categoria": art.id_categoria,
            "categoria_nombre": categoria_nombre,
            "imagen_articulo": art.imagen_articulo,
            "estado_publicacion": art.estado_publicacion,
            "fecha_publicacion": art.fecha_publicacion,
            "fecha_actualizacion": art.fecha_actualizacion
        })
    
    return result


@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED, summary="Crear artículo")
def create_article(
    payload: ArticuloCreate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Crear un nuevo artículo (admin only)."""
    # Cargar usuario con rol eager-loaded
    current_user = db.query(Usuario).options(joinedload(Usuario.rol)).filter(
        Usuario.id_usuario == current_user.id_usuario
    ).first()
    
    # Validar admin
    if not current_user or not current_user.rol or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(status_code=403, detail="Solo administradores pueden crear artículos")
    
    article = LiquenPedia(
        titulo=payload.titulo,
        contenido=payload.contenido,
        autor=payload.autor,
        categoria=payload.categoria,
        id_categoria=payload.id_categoria,
        imagen_articulo=normalize_image_path(payload.imagen_articulo),
        estado_publicacion=payload.estado_publicacion or 'draft'
    )
    db.add(article)
    db.commit()
    db.refresh(article)
    
    categoria_nombre = None
    if article.id_categoria:
        cat_obj = db.query(CategoriaArticulo).filter(CategoriaArticulo.id_categoria == article.id_categoria).first()
        if cat_obj:
            categoria_nombre = cat_obj.nombre_categoria
    
    return {
        "id_articulo": article.id_articulo,
        "titulo": article.titulo,
        "contenido": article.contenido,
        "autor": article.autor,
        "categoria": article.categoria,
        "id_categoria": article.id_categoria,
        "categoria_nombre": categoria_nombre,
        "imagen_articulo": article.imagen_articulo,
        "estado_publicacion": article.estado_publicacion,
        "fecha_publicacion": article.fecha_publicacion,
        "fecha_actualizacion": article.fecha_actualizacion
    }


@router.get("/{article_id}", response_model=dict, summary="Obtener artículo por ID")
def get_article(
    article_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user_optional)
):
    """Obtener un artículo específico."""
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    
    if not art:
        raise HTTPException(status_code=404, detail="Artículo no encontrado")
    
    # Si no es admin y artículo no está publicado, denegar acceso
    is_admin = (current_user and current_user.rol and current_user.rol.nombre_rol == 'admin')
    if not is_admin and art.estado_publicacion != 'published':
        raise HTTPException(status_code=403, detail="No tienes permiso para ver este artículo")
    
    categoria_nombre = None
    if art.id_categoria:
        cat_obj = db.query(CategoriaArticulo).filter(CategoriaArticulo.id_categoria == art.id_categoria).first()
        if cat_obj:
            categoria_nombre = cat_obj.nombre_categoria
    
    return {
        "id_articulo": art.id_articulo,
        "titulo": art.titulo,
        "contenido": art.contenido,
        "autor": art.autor,
        "categoria": art.categoria,
        "id_categoria": art.id_categoria,
        "categoria_nombre": categoria_nombre,
        "imagen_articulo": art.imagen_articulo,
        "estado_publicacion": art.estado_publicacion,
        "fecha_publicacion": art.fecha_publicacion,
        "fecha_actualizacion": art.fecha_actualizacion
    }


@router.put("/{article_id}", response_model=dict, summary="Actualizar artículo")
def update_article(
    article_id: int,
    payload: ArticuloUpdate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Actualizar un artículo (admin only)."""
    # Cargar usuario con rol eager-loaded
    current_user = db.query(Usuario).options(joinedload(Usuario.rol)).filter(
        Usuario.id_usuario == current_user.id_usuario
    ).first()
    
    # Validar admin
    if not current_user or not current_user.rol or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(status_code=403, detail="Solo administradores pueden actualizar artículos")
    
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    
    if not art:
        raise HTTPException(status_code=404, detail="Artículo no encontrado")
    
    # Actualizar solo los campos proporcionados
    update_data = payload.dict(exclude_unset=True)
    for key, value in update_data.items():
        if key == 'imagen_articulo':
            value = normalize_image_path(value)
        setattr(art, key, value)
    
    db.commit()
    db.refresh(art)
    
    categoria_nombre = None
    if art.id_categoria:
        cat_obj = db.query(CategoriaArticulo).filter(CategoriaArticulo.id_categoria == art.id_categoria).first()
        if cat_obj:
            categoria_nombre = cat_obj.nombre_categoria
    
    return {
        "id_articulo": art.id_articulo,
        "titulo": art.titulo,
        "contenido": art.contenido,
        "autor": art.autor,
        "categoria": art.categoria,
        "id_categoria": art.id_categoria,
        "categoria_nombre": categoria_nombre,
        "imagen_articulo": art.imagen_articulo,
        "estado_publicacion": art.estado_publicacion,
        "fecha_publicacion": art.fecha_publicacion,
        "fecha_actualizacion": art.fecha_actualizacion
    }


@router.delete("/{article_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar artículo")
def delete_article(
    article_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Eliminar un artículo (admin only)."""
    # Cargar usuario con rol eager-loaded
    current_user = db.query(Usuario).options(joinedload(Usuario.rol)).filter(
        Usuario.id_usuario == current_user.id_usuario
    ).first()
    
    # Validar admin
    if not current_user or not current_user.rol or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(status_code=403, detail="Solo administradores pueden eliminar artículos")
    
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    
    if not art:
        raise HTTPException(status_code=404, detail="Artículo no encontrado")
    
    db.delete(art)
    db.commit()
    
    return None
