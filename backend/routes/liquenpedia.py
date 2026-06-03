from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

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


@router.get("", response_model=List[ArticleResponse], summary="Listar artículos de LiquenPedia")
def list_articles():
    return [
        {
            "id_articulo": 1,
            "titulo": "Líquenes comunes",
            "contenido": "Contenido de ejemplo",
            "autor": "Admin",
            "categoria": "General",
            "fecha_publicacion": datetime.now()
        }
    ]


@router.post("", response_model=ArticleResponse, status_code=status.HTTP_201_CREATED, summary="Crear artículo")
def create_article(payload: ArticleCreate):
    return {
        "id_articulo": 1,
        "titulo": payload.titulo,
        "contenido": payload.contenido,
        "autor": payload.autor,
        "categoria": payload.categoria,
        "fecha_publicacion": datetime.now()
    }


@router.get("/{article_id}", response_model=ArticleResponse, summary="Obtener artículo por ID")
def get_article(article_id: int):
    return {
        "id_articulo": article_id,
        "titulo": "Líquenes comunes",
        "contenido": "Contenido de ejemplo",
        "autor": "Admin",
        "categoria": "General",
        "fecha_publicacion": datetime.now()
    }


@router.put("/{article_id}", response_model=ArticleResponse, summary="Actualizar artículo")
def update_article(article_id: int, payload: ArticleCreate):
    return {
        "id_articulo": article_id,
        "titulo": payload.titulo,
        "contenido": payload.contenido,
        "autor": payload.autor,
        "categoria": payload.categoria,
        "fecha_publicacion": datetime.now()
    }


@router.delete("/{article_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar artículo")
def delete_article(article_id: int):
    return None
