from fastapi import APIRouter, HTTPException, status, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_

from config.db import get_db
from models.core import LiquenPedia, Usuario
from models.validations import ArticuloCreate, ArticuloUpdate
from auth.auth_service import get_current_user

router = APIRouter()


@router.get("/", response_model=list[dict], summary="Listar artículos de LiquenPedia")
def list_articles(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    search: str = Query(None),
    categoria: str = Query(None),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Listar artículos con búsqueda y paginación.
    
    - Usuarios normales: solo artículos publicados
    - Admins: todos los estados (draft, published, archived)
    """
    query = db.query(LiquenPedia)
    
    # Si no es admin, mostrar solo published
    if current_user.rol.nombre_rol != 'admin':
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
    
    # Convertir a dict
    result = []
    for art in articulos:
        result.append({
            "id_articulo": art.id_articulo,
            "titulo": art.titulo,
            "contenido": art.contenido,
            "autor": art.autor,
            "categoria": art.categoria,
            "imagen_articulo": art.imagen_articulo,
            "estado_publicacion": art.estado_publicacion,
            "fecha_publicacion": art.fecha_publicacion,
            "fecha_actualizacion": art.fecha_actualizacion
        })
    
    return result


@router.post("/", response_model=dict, status_code=status.HTTP_201_CREATED, summary="Crear artículo")
def create_article(
    payload: ArticuloCreate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Crear un nuevo artículo (admin only)."""
    # Validar admin
    if current_user.rol.nombre_rol != 'admin':
        raise HTTPException(status_code=403, detail="Solo administradores pueden crear artículos")
    
    article = LiquenPedia(
        titulo=payload.titulo,
        contenido=payload.contenido,
        autor=payload.autor,
        categoria=payload.categoria,
        imagen_articulo=payload.imagen_articulo,
        estado_publicacion='draft'  # Por defecto empieza en draft
    )
    db.add(article)
    db.commit()
    db.refresh(article)
    
    return {
        "id_articulo": article.id_articulo,
        "titulo": article.titulo,
        "contenido": article.contenido,
        "autor": article.autor,
        "categoria": article.categoria,
        "imagen_articulo": article.imagen_articulo,
        "estado_publicacion": article.estado_publicacion,
        "fecha_publicacion": article.fecha_publicacion,
        "fecha_actualizacion": article.fecha_actualizacion
    }


@router.get("/{article_id}", response_model=dict, summary="Obtener artículo por ID")
def get_article(
    article_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Obtener un artículo específico."""
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    
    if not art:
        raise HTTPException(status_code=404, detail="Artículo no encontrado")
    
    # Si no es admin y artículo no está publicado, denegar acceso
    if current_user.rol.nombre_rol != 'admin' and art.estado_publicacion != 'published':
        raise HTTPException(status_code=403, detail="No tienes permiso para ver este artículo")
    
    return {
        "id_articulo": art.id_articulo,
        "titulo": art.titulo,
        "contenido": art.contenido,
        "autor": art.autor,
        "categoria": art.categoria,
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
    # Validar admin
    if current_user.rol.nombre_rol != 'admin':
        raise HTTPException(status_code=403, detail="Solo administradores pueden actualizar artículos")
    
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    
    if not art:
        raise HTTPException(status_code=404, detail="Artículo no encontrado")
    
    # Actualizar solo los campos proporcionados
    update_data = payload.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(art, key, value)
    
    db.commit()
    db.refresh(art)
    
    return {
        "id_articulo": art.id_articulo,
        "titulo": art.titulo,
        "contenido": art.contenido,
        "autor": art.autor,
        "categoria": art.categoria,
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
    # Validar admin
    if current_user.rol.nombre_rol != 'admin':
        raise HTTPException(status_code=403, detail="Solo administradores pueden eliminar artículos")
    
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    
    if not art:
        raise HTTPException(status_code=404, detail="Artículo no encontrado")
    
    db.delete(art)
    db.commit()
    
    return None
