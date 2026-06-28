from fastapi import APIRouter, UploadFile, File, status, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
import os
import uuid

from config.db import get_db
from models.core import Imagen as ImagenModel

router = APIRouter()

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), '..', 'uploads')
os.makedirs(UPLOAD_DIR, exist_ok=True)


class ImageResponse(BaseModel):
    id_imagen: int
    id_analisis: Optional[int]
    url: str
    descripcion: Optional[str]

    class Config:
        from_attributes = True


@router.post("/upload", response_model=ImageResponse, summary="Subir imagen")
async def upload_image(file: UploadFile = File(...), id_analisis: Optional[int] = None, db: Session = Depends(get_db)):
    filename = file.filename
    ext = os.path.splitext(filename)[1]
    unique_name = f"{uuid.uuid4().hex}{ext}"
    dest_path = os.path.join(UPLOAD_DIR, unique_name)

    with open(dest_path, "wb") as f:
        content = await file.read()
        f.write(content)

    url_path = f"/uploads/{unique_name}"

    imagen = ImagenModel(id_analisis=id_analisis, url=url_path, descripcion=None)
    db.add(imagen)
    db.commit()
    db.refresh(imagen)

    return imagen


@router.get("", response_model=List[ImageResponse], summary="Listar imágenes")
def list_images(db: Session = Depends(get_db)):
    items = db.query(ImagenModel).all()
    return items


@router.get("/{image_id}", response_model=ImageResponse, summary="Obtener imagen por ID")
def get_image(image_id: int, db: Session = Depends(get_db)):
    img = db.query(ImagenModel).filter(ImagenModel.id_imagen == image_id).first()
    if not img:
        raise HTTPException(status_code=404, detail="Imagen no encontrada")
    return img


@router.delete("/{image_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar imagen")
def delete_image(image_id: int, db: Session = Depends(get_db)):
    img = db.query(ImagenModel).filter(ImagenModel.id_imagen == image_id).first()
    if not img:
        raise HTTPException(status_code=404, detail="Imagen no encontrada")

    # eliminar archivo fisico si existe
    file_rel = img.url.replace('/uploads/', '')
    file_path = os.path.join(UPLOAD_DIR, file_rel)
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
    except Exception:
        pass

    db.delete(img)
    db.commit()
    return None
