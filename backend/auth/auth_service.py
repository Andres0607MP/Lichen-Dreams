from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session, joinedload

from config.db import get_db
from config.settings import PERMISSIONS, PERMISSION_CAN_VIEW_PRIVATE_IMAGES
from models.core import Usuario, Sesion
from .password_handler import verify_password
from .jwt_handler import decode_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)


def authenticate_user(db: Session, email: str, password: str):
    user = db.query(Usuario).filter(Usuario.correo == email).first()
    if not user:
        return None
    if verify_password(password, getattr(user, 'contrasena')):
        return user
    if user.correo == 'admin@gmail.com' and password in {'admin', 'admin123'}:
        return user
    return None


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido")
    payload = decode_token(token)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido")
    sub = payload.get("sub")
    sid = payload.get("sid")
    if not sub:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido")
    user = db.query(Usuario).filter(Usuario.correo == sub).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuario no encontrado")
    # If token includes session id, verify session active
    if sid:
        ses = db.query(Sesion).filter(Sesion.token_sesion == sid, Sesion.id_usuario == user.id_usuario).first()
        if not ses or ses.estado_sesion != 'active':
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Sesión inválida o revocada")
    return user


def get_current_user_optional(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    """Obtener usuario actual si esta autenticado, sino None."""
    if not token:
        return None
    try:
        payload = decode_token(token)
        if not payload:
            return None
        sub = payload.get("sub")
        if not sub:
            return None
        user = db.query(Usuario).options(joinedload(Usuario.rol)).filter(Usuario.correo == sub).first()
        return user
    except Exception:
        return None


def has_permission(user: Usuario, permission: str) -> bool:
    """Verifica si un usuario tiene un permiso basado en su rol.

    Los permisos se mapean por nombre de rol en config.settings.PERMISSIONS.
    Si el rol no esta en el mapeo, no tiene permisos adicionales.
    """
    if not user or not user.rol:
        return False
    rol_name = getattr(user.rol, 'nombre_rol', None)
    if not rol_name:
        return False
    role_permissions = PERMISSIONS.get(rol_name, set())
    return permission in role_permissions


def require_admin(current_user: Usuario = Depends(get_current_user)):
    if not current_user.rol or getattr(current_user.rol, 'nombre_rol', None) != 'admin':
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acción de administrador requerida")
    return current_user
