from fastapi import APIRouter, UploadFile, File, Form, status, Depends, HTTPException
from fastapi.responses import RedirectResponse
from typing import Optional, List
from pydantic import BaseModel
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
    file_exists_in_r2,
    delete_file_r2,
    get_presigned_url_r2,
    extract_user_id_from_path,
    is_private_image_path,
    IMAGE_TYPE_ARTICLE,
    IMAGE_TYPE_PROFILE,
    IMAGE_TYPE_ANALYSIS,
    IMAGE_TYPE_SPECIES,
)
from sqlalchemy.orm import Session
from config.db import get_db


class ImageResponse(BaseModel):
    id_imagen: int
    id_analisis: Optional[int]
    url: str
    descripcion: Optional[str]

    class Config:
        from_attributes = True

private_router = APIRouter()
public_router = APIRouter()


@private_router.post("/upload", response_model=ImageResponse, summary="Subir imagen")
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


@private_router.get("/file/{path:path}", summary="Servir imagen privada (propietario o auditor)")
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

    # Generate a presigned URL for private image (short expiration)
    try:
        signed_url = get_presigned_url_r2(relative_path, expires_in=300)  # 5 minutes
    except HTTPException as e:
        if e.status_code == 404:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Imagen no encontrada",
            )
        else:
            raise

    return RedirectResponse(signed_url)


@private_router.get("", response_model=List[ImageResponse], summary="Listar imÃ¡genes")
def list_images(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    """Lista imÃ¡genes visibles para el usuario autenticado.

    Las imÃ¡genes privadas (profiles/analyses) solo se devuelven a su
    propietario o a roles con permiso CAN_VIEW_PRIVATE_IMAGES.
    """
    items = db.query(ImagenModel).all()

    def _visible(img: ImagenModel) -> bool:
        rel = img.url or ""
        if not is_private_image_path(rel):
            return True  # pÃºblicas: articles/species
        if has_permission(current_user, PERMISSION_CAN_VIEW_PRIVATE_IMAGES):
            return True
        owner = extract_user_id_from_path(rel)
        return owner is not None and owner == current_user.id_usuario

    return [i for i in items if _visible(i)]


@private_router.get("/{image_id}", response_model=ImageResponse, summary="Obtener imagen por ID")
def get_image(
    image_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    img = db.query(ImagenModel).filter(ImagenModel.id_imagen == image_id).first()
    if not img:
        raise HTTPException(status_code=404, detail="Imagen no encontrada")

    rel = img.url or ""
    if is_private_image_path(rel):
        is_owner = extract_user_id_from_path(rel) == current_user.id_usuario
        has_audit_perm = has_permission(current_user, PERMISSION_CAN_VIEW_PRIVATE_IMAGES)
        if not is_owner and not has_audit_perm:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permiso para acceder a esta imagen",
            )
    return img


@private_router.delete("/{image_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar imagen")
def delete_image(
    image_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    """Elimina una imagen.

    Solo el propietario o un rol con permiso CAN_VIEW_PRIVATE_IMAGES puede
    eliminar imÃ¡genes privadas. Las pÃºblicas (articles/species) requieren
    autenticaciÃ³n.
    """
    img = db.query(ImagenModel).filter(ImagenModel.id_imagen == image_id).first()
    if not img:
        raise HTTPException(status_code=404, detail="Imagen no encontrada")

    rel = img.url or ""
    if is_private_image_path(rel):
        is_owner = extract_user_id_from_path(rel) == current_user.id_usuario
        has_audit_perm = has_permission(current_user, PERMISSION_CAN_VIEW_PRIVATE_IMAGES)
        if not is_owner and not has_audit_perm:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permiso para eliminar esta imagen",
            )

    # Delete from R2
    try:
        delete_file_r2(rel)
    except HTTPException as e:
        if e.status_code != 404:
            # Re-raise if it's not a 404 (object not found)
            raise
        # If 404, we continue to delete the DB record

    db.delete(img)
    db.commit()
    return None


@public_router.get("/articles/{path:path}")
async def serve_public_article(path: str):
    """Serve a public article image by redirecting to a presigned URL."""
    relative_path = f"/uploads/articles/{path}"
    try:
        signed_url = get_presigned_url_r2(relative_path, expires_in=3600)  # 1 hour
    except HTTPException as e:
        if e.status_code == 404:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Imagen no encontrada",
            )
        else:
            raise
    return RedirectResponse(signed_url)


@public_router.get("/species/{path:path}")
async def serve_public_species(path: str):
    """Serve a public species image by redirecting to a presigned URL."""
    relative_path = f"/uploads/species/{path}"
    try:
        signed_url = get_presigned_url_r2(relative_path, expires_in=3600)  # 1 hour
    except HTTPException as e:
        if e.status_code == 404:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Imagen no encontrada",
            )
        else:
            raise
    return RedirectResponse(signed_url)