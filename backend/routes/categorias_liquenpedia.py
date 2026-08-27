from typing import List, Optional

from fastapi import APIRouter, HTTPException, status, Depends, Query
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import CategoriaArticulo, Usuario
from models.validations import CategoriaArticuloCreate, CategoriaArticuloUpdate, CategoriaArticuloResponse
from routes.liquenpedia import verify_admin

router = APIRouter()


@router.get("", response_model=List[CategoriaArticuloResponse], summary="Listar categorías de artículos")
def list_categorias(
    solo_activas: bool = Query(True),
    db: Session = Depends(get_db),
):
    """Listar todas las categorías de artículos."""
    query = db.query(CategoriaArticulo)
    if solo_activas:
        query = query.filter(CategoriaArticulo.activo == True)
    categorias = query.order_by(CategoriaArticulo.orden, CategoriaArticulo.nombre_categoria).all()
    return categorias


@router.post("", response_model=CategoriaArticuloResponse, status_code=status.HTTP_201_CREATED, summary="Crear categoría")
def create_categoria(
    payload: CategoriaArticuloCreate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(verify_admin),
):
    """Crear una nueva categoría (admin only)."""
    existente = db.query(CategoriaArticulo).filter(
        CategoriaArticulo.nombre_categoria == payload.nombre_categoria
    ).first()
    if existente:
        raise HTTPException(status_code=400, detail="La categoría ya existe")

    categoria = CategoriaArticulo(
        nombre_categoria=payload.nombre_categoria,
        descripcion=payload.descripcion,
        color=payload.color,
        icono=payload.icono,
        orden=payload.orden or 0,
    )
    db.add(categoria)
    db.commit()
    db.refresh(categoria)
    return categoria


@router.get("/{categoria_id}", response_model=CategoriaArticuloResponse, summary="Obtener categoría por ID")
def get_categoria(
    categoria_id: int,
    db: Session = Depends(get_db),
):
    """Obtener una categoría específica."""
    categoria = db.query(CategoriaArticulo).filter(CategoriaArticulo.id_categoria == categoria_id).first()
    if not categoria:
        raise HTTPException(status_code=404, detail="Categoría no encontrada")
    return categoria


@router.put("/{categoria_id}", response_model=CategoriaArticuloResponse, summary="Actualizar categoría")
def update_categoria(
    categoria_id: int,
    payload: CategoriaArticuloUpdate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(verify_admin),
):
    """Actualizar una categoría (admin only)."""
    categoria = db.query(CategoriaArticulo).filter(CategoriaArticulo.id_categoria == categoria_id).first()
    if not categoria:
        raise HTTPException(status_code=404, detail="Categoría no encontrada")

    update_data = payload.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(categoria, key, value)

    db.commit()
    db.refresh(categoria)
    return categoria


@router.delete("/{categoria_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar categoría")
def delete_categoria(
    categoria_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(verify_admin),
):
    """Eliminar una categoría (admin only)."""
    categoria = db.query(CategoriaArticulo).filter(CategoriaArticulo.id_categoria == categoria_id).first()
    if not categoria:
        raise HTTPException(status_code=404, detail="Categoría no encontrada")

    db.delete(categoria)
    db.commit()
    return None
