from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import or_

from config.db import get_db
from models.core import LiquenPedia, Usuario
from auth.auth_service import get_current_user

router = APIRouter()


class ArticleCreate(BaseModel):
    titulo: str
    contenido: str
    autor: Optional[str] = None
    categoria: Optional[str] = None


class ArticleUpdate(BaseModel):
    titulo: Optional[str] = None
    contenido: Optional[str] = None
    autor: Optional[str] = None
    categoria: Optional[str] = None


class ArticleResponse(BaseModel):
    id_articulo: int
    titulo: str
    contenido: str
    autor: Optional[str]
    categoria: Optional[str]
    fecha_publicacion: datetime

    class Config:
        orm_mode = True


def verify_admin(current_user: Usuario = Depends(get_current_user)):
    """Verifica que el usuario sea administrador"""
    if current_user.rol is None or current_user.rol.nombre_rol != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso"
        )
    return current_user


@router.get("", response_model=List[ArticleResponse], summary="Listar artículos (público)")
def list_articles(
    skip: int = 0,
    limit: int = 100,
    titulo: Optional[str] = None,
    contenido: Optional[str] = None,
    categoria: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Lista artículos de LiquenPedia con búsqueda y paginación (público)
    
    - **skip**: número de registros a saltar (paginación)
    - **limit**: número máximo de registros a retornar
    - **titulo**: buscar por título (búsqueda parcial)
    - **contenido**: buscar por contenido (búsqueda parcial)
    - **categoria**: filtrar por categoría exacta
    """
    query = db.query(LiquenPedia)
    
    # Búsqueda por título
    if titulo:
        query = query.filter(LiquenPedia.titulo.ilike(f"%{titulo}%"))
    
    # Búsqueda por contenido
    if contenido:
        query = query.filter(LiquenPedia.contenido.ilike(f"%{contenido}%"))
    
    # Filtro por categoría
    if categoria:
        query = query.filter(LiquenPedia.categoria == categoria)
    
    articles = query.offset(skip).limit(limit).all()
    return articles


@router.post("", response_model=ArticleResponse, status_code=status.HTTP_201_CREATED, summary="Crear artículo (admin only)")
def create_article(
    payload: ArticleCreate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Crea un nuevo artículo en LiquenPedia (solo administradores)
    
    - **titulo**: título del artículo (requerido)
    - **contenido**: contenido del artículo (requerido)
    - **autor**: autor del artículo (opcional)
    - **categoria**: categoría del artículo (opcional)
    """
    article = LiquenPedia(
        titulo=payload.titulo,
        contenido=payload.contenido,
        autor=payload.autor,
        categoria=payload.categoria
    )
    db.add(article)
    db.commit()
    db.refresh(article)
    return article


@router.get("/{article_id}", response_model=ArticleResponse, summary="Obtener artículo por ID (público)")
def get_article(
    article_id: int,
    db: Session = Depends(get_db)
):
    """
    Obtiene un artículo específico por su ID (público)
    
    - **article_id**: ID del artículo
    """
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    if not art:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Artículo no encontrado"
        )
    return art


@router.put("/{article_id}", response_model=ArticleResponse, summary="Actualizar artículo (admin only)")
def update_article(
    article_id: int,
    payload: ArticleUpdate,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Actualiza un artículo existente (solo administradores)
    
    - **article_id**: ID del artículo a actualizar
    """
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    if not art:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Artículo no encontrado"
        )
    
    # Actualizar campos si se proporcionan
    if payload.titulo is not None:
        art.titulo = payload.titulo
    if payload.contenido is not None:
        art.contenido = payload.contenido
    if payload.autor is not None:
        art.autor = payload.autor
    if payload.categoria is not None:
        art.categoria = payload.categoria
    
    db.commit()
    db.refresh(art)
    return art


@router.delete("/{article_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar artículo (admin only)")
def delete_article(
    article_id: int,
    current_user: Usuario = Depends(verify_admin),
    db: Session = Depends(get_db)
):
    """
    Elimina un artículo (solo administradores)
    
    - **article_id**: ID del artículo a eliminar
    """
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    if not art:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Artículo no encontrado"
        )
    db.delete(art)
    db.commit()
    return None
