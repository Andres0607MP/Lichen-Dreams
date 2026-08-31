from fastapi import APIRouter, UploadFile, File, Form, status, Depends, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List, Optional
from sqlalchemy.orm import Session

from config.db import get_db
from config.settings import (
    normalize_image_path,
    logger,
    PERMISSION_CAN_VIEW_PRIVATE_IMAGES,
)
from models.core import Imagen as ImagenModel
from models.core import Usuario
from auth.auth_service import get_current_user, get_current_user_optional, has_permission
from services.upload_service import (
    validate_image,
    save_file,
    resolve_file_path,
    extract_user_id_from_path,
    is_private_image_path,
    IMAGE_TYPE_ARTICLE,
    IMAGE_TYPE_PROFILE,
    IMAGE_TYPE_ANALYSIS,
    IMAGE_TYPE_SPECIES,
)

router = APIRouter()


class ImageResponse(BaseModel):
    id_imagen: int
    id_analisis: Optional[int]
    url: str
    descripcion: Optional[str]

    class Config:
        from_attributes = True


@router.post("/upload", response_model=ImageResponse, summary="Subir imagen")
async def upload_image(
    file: UploadFile = File(...),
    imagen_tipo: str = Form(IMAGE_TYPE_ARTICLE),
    id_analisis: Optional[int] = Form(None),
    db: Session = Depends(get_db),
    current_user: Optional[Usuario] = Depends(get_current_user_optional),
):
    """Sube una imagen clasificada por tipo.

    - imagen_tipo=article: guarda en uploads/articles/ (publico)
    - imagen_tipo=profile: guarda en uploads/profiles/user_{id}/ (privado, requiere auth)
    - imagen_tipo=analysis: guarda en uploads/analyses/user_{id}/ (privado, requiere auth)
    - imagen_tipo=species: guarda en uploads/species/ (publico)
    """
    content, ext = await validate_image(file)

    if imagen_tipo in (IMAGE_TYPE_PROFILE, IMAGE_TYPE_ANALYSIS):
        if current_user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Se requiere autenticacion para subir imagenes de este tipo",
            )

    user_id = current_user.id_usuario if current_user else None
    url_path = save_file(
        content=content,
        extension=ext,
        image_type=imagen_tipo,
        user_id=user_id,
    )

    imagen = ImagenModel(
        id_analisis=id_analisis,
        url=url_path,
        ruta_imagen=url_path,
        descripcion=None,
    )
    db.add(imagen)
    db.commit()
    db.refresh(imagen)

    return imagen


@router.get("/file/{path:path}", summary="Servir imagen privada (propietario o auditor)")
async def serve_private_image(
    path: str,
    current_user: Usuario = Depends(get_current_user),
):
    """Sirve un archivo de imagen privada (profiles/ o analyses/).

    Valida que el usuario autenticado sea el propietario del archivo,
    o que posea el permiso CAN_VIEW_PRIVATE_IMAGES (rol auditor/admin_privado).

    No sirve imagenes publicas (articles/).
    Registra auditoria de accesos no autorizados.
    """
    relative_path = f"/uploads/{path}"

    if not is_private_image_path(relative_path):
        logger.warning(
            "User %s attempted access to non-private path: %s",
            current_user.id_usuario, relative_path,
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Este endpoint solo sirve imagenes privadas",
        )

    file_owner = extract_user_id_from_path(relative_path)
    if file_owner is None:
        logger.warning(
            "User %s attempted access to path without valid user_id: %s",
            current_user.id_usuario, relative_path,
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Path de imagen invalido",
        )

    is_owner = file_owner == current_user.id_usuario
    has_audit_perm = has_permission(current_user, PERMISSION_CAN_VIEW_PRIVATE_IMAGES)

    if not is_owner and not has_audit_perm:
        logger.warning(
            "SECURITY] User %d attempted access to user_%d image: %s",
            current_user.id_usuario, file_owner, relative_path,
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para acceder a esta imagen",
        )

    file_path = resolve_file_path(relative_path)
    if file_path is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Imagen no encontrada",
        )

    media_type = "image/jpeg"
    if file_path.suffix.lower() == ".png":
        media_type = "image/png"

    return FileResponse(str(file_path), media_type=media_type)


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

    file_path = resolve_file_path(img.url or "")
    if file_path is not None:
        try:
            file_path.unlink()
        except Exception:
            pass

    db.delete(img)
    db.commit()
    return None
