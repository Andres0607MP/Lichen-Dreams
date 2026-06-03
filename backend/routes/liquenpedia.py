from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import LiquenPedia

router = APIRouter()


class ArticleCreate(BaseModel):
    titulo: str
    contenido: str
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


@router.get("", response_model=List[ArticleResponse], summary="Listar artículos de LiquenPedia")
def list_articles(db: Session = Depends(get_db)):
    return db.query(LiquenPedia).all()


@router.post("", response_model=ArticleResponse, status_code=status.HTTP_201_CREATED, summary="Crear artículo")
def create_article(payload: ArticleCreate, db: Session = Depends(get_db)):
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


@router.get("/{article_id}", response_model=ArticleResponse, summary="Obtener artículo por ID")
def get_article(article_id: int, db: Session = Depends(get_db)):
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    if not art:
        raise HTTPException(status_code=404, detail="Artículo no encontrado")
    return art


@router.put("/{article_id}", response_model=ArticleResponse, summary="Actualizar artículo")
def update_article(article_id: int, payload: ArticleCreate, db: Session = Depends(get_db)):
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    if not art:
        raise HTTPException(status_code=404, detail="Artículo no encontrado")
    art.titulo = payload.titulo
    art.contenido = payload.contenido
    art.autor = payload.autor
    art.categoria = payload.categoria
    db.commit()
    db.refresh(art)
    return art


@router.delete("/{article_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar artículo")
def delete_article(article_id: int, db: Session = Depends(get_db)):
    art = db.query(LiquenPedia).filter(LiquenPedia.id_articulo == article_id).first()
    if not art:
        raise HTTPException(status_code=404, detail="Artículo no encontrado")
    db.delete(art)
    db.commit()
    return None
