from fastapi import APIRouter, UploadFile, File, status
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

router = APIRouter()


class ImageResponse(BaseModel):
    id_imagen: int
    id_analisis: Optional[int]
    url: str
    descripcion: Optional[str]


@router.post("/upload", response_model=ImageResponse, summary="Subir imagen")
async def upload_image(file: UploadFile = File(...)):
    return {
        "id_imagen": 1,
        "id_analisis": None,
        "url": f"/uploads/{file.filename}",
        "descripcion": "Imagen subida (mock)"
    }


@router.get("", response_model=List[ImageResponse], summary="Listar imágenes")
def list_images():
    return [
        {
            "id_imagen": 1,
            "id_analisis": 1,
            "url": "https://example.com/image1.jpg",
            "descripcion": "Imagen de ejemplo"
        }
    ]


@router.get("/{image_id}", response_model=ImageResponse, summary="Obtener imagen por ID")
def get_image(image_id: int):
    return {
        "id_imagen": image_id,
        "id_analisis": 1,
        "url": "https://example.com/image1.jpg",
        "descripcion": "Imagen de ejemplo"
    }


@router.delete("/{image_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar imagen")
def delete_image(image_id: int):
    return None
