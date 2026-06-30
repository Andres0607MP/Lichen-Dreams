from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import Usuario, Sesion
from .password_handler import verify_password
from .jwt_handler import decode_token

# 🔥 CAMBIO IMPORTANTE: Swagger limpio (SIN OAuth2 form)
security = HTTPBearer()


def authenticate_user(db: Session, email: str, password: str):
    user = db.query(Usuario).filter(Usuario.correo == email).first()
    if not user:
        return None
    if not verify_password(password, user.contrasena):
        return None
    return user


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    token = credentials.credentials  # 👈 aquí está el JWT real

    payload = decode_token(token)

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido"
        )

    sub = payload.get("sub")
    sid = payload.get("sid")

    if not sub:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido"
        )

    user = db.query(Usuario).filter(Usuario.correo == sub).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado"
        )

    # validar sesión si existe sid
    if sid:
        ses = db.query(Sesion).filter(
            Sesion.token_sesion == sid,
            Sesion.id_usuario == user.id_usuario
        ).first()

        if not ses or ses.estado_sesion != "active":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Sesión inválida o revocada"
            )

    return user


def require_admin(current_user: Usuario = Depends(get_current_user)):
    if not current_user.rol or current_user.rol.nombre_rol != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acción de administrador requerida"
        )
    return current_user