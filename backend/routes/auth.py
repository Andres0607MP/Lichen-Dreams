from datetime import date, datetime, timedelta
from fastapi import APIRouter, HTTPException, status, Depends, Form
from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_
import secrets
import hashlib
from config.db import get_db
from config.settings import normalize_image_path
from models.core import Usuario, Sesion, Role, PasswordResetToken, EmailVerificationToken
from auth.password_handler import hash_password, verify_password
from auth.jwt_handler import create_access_token, create_refresh_token, decode_token
from auth.auth_service import authenticate_user, get_current_user
from models.validations import PasswordResetRequest, PasswordResetConfirm, PasswordResetResponse, EmailVerificationRequest, EmailVerificationConfirm, RegisterResponse
from services.email_service import email_service

router = APIRouter()


def _as_date(value):
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    return value


class LoginRequest(BaseModel):
    email: Optional[str] = None
    username: Optional[str] = None
    password: str


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    name: str
    apellido: Optional[str] = None
    phone: Optional[str] = None
    tipo_documento: Optional[str] = None
    numero_documento: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    foto_perfil: Optional[str] = None

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, value: str) -> str:
        if len(value) < 6:
            raise ValueError("La contraseña debe tener al menos 6 caracteres")
        if not any(not ch.isalnum() for ch in value):
            raise ValueError("La contraseña debe incluir al menos un carácter especial")
        return value


class RefreshRequest(BaseModel):
    refresh_token: str


class UserResponse(BaseModel):
    id_usuario: int
    correo: str
    nombre: Optional[str]
    apellido: Optional[str] = None
    telefono: Optional[str] = None
    tipo_documento: Optional[str] = None
    numero_documento: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    foto_perfil: Optional[str] = None
    estado_cuenta: Optional[str] = None
    id_rol: Optional[int]
    rol: Optional[str]

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    user: UserResponse


@router.post("/login", response_model=TokenResponse, summary="Iniciar sesión")
def login(
    username: Optional[str] = Form(None),
    email: Optional[str] = Form(None),
    password: str = Form(...),
    db: Session = Depends(get_db)
):

    email = email or username

    if not email or not password:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="email y password son requeridos"
        )

    user = authenticate_user(db, email, password)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales inválidas"
        )

    import uuid

    sid = uuid.uuid4().hex

    db.query(Sesion).filter(
        Sesion.id_usuario == user.id_usuario,
        Sesion.estado_sesion == "active"
    ).update({Sesion.estado_sesion: "revoked"}, synchronize_session=False)

    sesion = Sesion(
        token_sesion=sid,
        dispositivo=None,
        ip_usuario=None,
        estado_sesion="active",
        id_usuario=user.id_usuario
    )

    db.add(sesion)
    db.commit()
    db.refresh(sesion)

    access = create_access_token(
        subject=user.correo,
        sid=sid
    )

    refresh = create_refresh_token(
        subject=user.correo,
        sid=sid
    )

    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "bearer",
        "user": {
            "id_usuario": user.id_usuario,
            "correo": user.correo,
            "nombre": user.nombre,
            "telefono": user.telefono,
            "id_rol": user.id_rol,
            "rol": user.rol.nombre_rol if user.rol else None
        }
    }


@router.post(
    "/register",
    response_model=RegisterResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar nuevo usuario"
)
def register(
    request: RegisterRequest,
    db: Session = Depends(get_db)
):

    existing = db.query(Usuario).filter(
        Usuario.correo == request.email
    ).first()

    if existing:
        raise HTTPException(
            status_code=400,
            detail="Usuario ya existe"
        )

    user_role = db.query(Role).filter(
        Role.nombre_rol == "user"
    ).first()

    if not user_role:
        user_role = Role(
            nombre_rol="user",
            descripcion="Usuario normal",
            nivel_acceso=1
        )

        db.add(user_role)
        db.commit()
        db.refresh(user_role)

    user = Usuario(
        nombre=request.name,
        apellido=request.apellido,
        correo=request.email,
        contrasena=hash_password(request.password),
        telefono=request.phone,
        tipo_documento=request.tipo_documento,
        numero_documento=request.numero_documento,
        fecha_nacimiento=request.fecha_nacimiento,
        foto_perfil=normalize_image_path(request.foto_perfil),
        estado_cuenta="inactive",
        id_rol=user_role.id_rol
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Generate email verification token
    raw_token = _generate_reset_token()
    token_hash = _hash_token(raw_token)
    expires_at = datetime.utcnow() + timedelta(minutes=60)

    verification_token = EmailVerificationToken(
        id_usuario=user.id_usuario,
        token_hash=token_hash,
        expires_at=expires_at,
    )
    db.add(verification_token)
    db.commit()

    # Send verification email to the user's email
    email_service.send_verification_email(user.correo, raw_token)

    return RegisterResponse(
        message="Registro exitoso. Por favor, verifica tu correo electrónico para activar tu cuenta.",
        email=user.correo
    )

@router.get("/me", response_model=UserResponse, summary="Obtener información del usuario actual")
def me(current_user: Usuario = Depends(get_current_user)):

    return {
        "id_usuario": current_user.id_usuario,
        "correo": current_user.correo,
        "nombre": current_user.nombre,
        "apellido": current_user.apellido,
        "telefono": current_user.telefono,
        "tipo_documento": current_user.tipo_documento,
        "numero_documento": current_user.numero_documento,
        "fecha_nacimiento": _as_date(current_user.fecha_nacimiento),
        "foto_perfil": current_user.foto_perfil,
        "estado_cuenta": current_user.estado_cuenta,
        "id_rol": current_user.id_rol,
        "rol": current_user.rol.nombre_rol if current_user.rol else None
    }


@router.post("/logout", summary="Cerrar sesión")
def logout(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Revoca TODAS las sesiones activas del usuario autenticado."""
    db.query(Sesion).filter(
        Sesion.id_usuario == current_user.id_usuario,
        Sesion.estado_sesion == "active"
    ).update({Sesion.estado_sesion: "revoked"}, synchronize_session=False)

    db.commit()

    return {
        "message": "Sesión cerrada exitosamente"
    }


@router.post("/refresh", summary="Refresh access token")
def refresh_token(
    request: RefreshRequest,
    db: Session = Depends(get_db)
):
    try:
        payload = decode_token(request.refresh_token)
    except Exception:
        raise HTTPException(
            status_code=401,
            detail="Token inválido"
        )
    if not payload:
        raise HTTPException(
            status_code=401,
            detail="Token inválido"
        )
    sub = payload.get("sub")
    sid = payload.get("sid")
    if not sub or not sid:
        raise HTTPException(
            status_code=401,
            detail="Token inválido"
        )
    sesion = db.query(Sesion).filter(
        Sesion.token_sesion == sid
    ).first()
    if not sesion:
        raise HTTPException(
            status_code=401,
            detail="Sesión no encontrada"
        )
    if sesion.estado_sesion != "active":
        raise HTTPException(
            status_code=401,
            detail="Sesión revocada"
        )
    access = create_access_token(
        subject=sub,
        sid=sid
    )
    return {
        "access_token": access,
        "token_type": "bearer"
    }


@router.post("/logout_refresh", summary="Logout and revoke refresh token")
def logout_refresh(
    request: RefreshRequest,
    db: Session = Depends(get_db)
):

    try:
        payload = decode_token(request.refresh_token)

    except Exception:
        raise HTTPException(
            status_code=401,
            detail="Token inválido"
        )

    if not payload:
        raise HTTPException(
            status_code=401,
            detail="Token inválido"
        )

    sid = payload.get("sid")
    if not sid:
        raise HTTPException(
            status_code=400,
            detail="Refresh token inválido"
        )

    sesion = db.query(Sesion).filter(
        Sesion.token_sesion == sid
    ).first()

    if sesion:
        sesion.estado_sesion = "revoked"
        db.commit()

    return {
        "message": "Sesión revocada"
    }


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password_strength(cls, value: str) -> str:
        if len(value) < 6:
            raise ValueError("La contraseña debe tener al menos 6 caracteres")
        if not any(not ch.isalnum() for ch in value):
            raise ValueError("La contraseña debe incluir al menos un carácter especial")
        return value


class DeleteAccountRequest(BaseModel):
    password: str


@router.post("/change-password", summary="Cambiar contraseña")
def change_password(
    request: ChangePasswordRequest,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cambia la contraseña del usuario autenticado."""
    if not verify_password(request.current_password, current_user.contrasena):
        raise HTTPException(
            status_code=400,
            detail="Contraseña actual incorrecta"
        )

    if request.current_password == request.new_password:
        raise HTTPException(
            status_code=400,
            detail="La nueva contraseña debe ser diferente a la actual"
        )

    current_user.contrasena = hash_password(request.new_password)

    db.query(Sesion).filter(
        Sesion.id_usuario == current_user.id_usuario,
        Sesion.estado_sesion == "active"
    ).update({Sesion.estado_sesion: "revoked"}, synchronize_session=False)

    db.commit()

    return {
        "message": "Contraseña actualizada exitosamente. Por favor, inicia sesión nuevamente."
    }


@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar cuenta")
def delete_account(
    request: DeleteAccountRequest,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Elimina la cuenta del usuario (soft delete)."""
    if not verify_password(request.password, current_user.contrasena):
        raise HTTPException(
            status_code=400,
            detail="Contraseña incorrecta"
        )

    current_user.estado_cuenta = "eliminado"

    db.query(Sesion).filter(
        Sesion.id_usuario == current_user.id_usuario,
        Sesion.estado_sesion == "active"
    ).update({Sesion.estado_sesion: "revoked"}, synchronize_session=False)

    db.commit()

    return None


@router.get("/sessions", summary="Obtener sesiones activas")
def get_sessions(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Obtiene únicamente las sesiones activas del usuario autenticado."""
    sesiones = db.query(Sesion).filter(
        Sesion.id_usuario == current_user.id_usuario,
        Sesion.estado_sesion == "active"
    ).order_by(Sesion.fecha_inicio.desc()).all()

    return [
        {
            "id_sesion": s.id_sesion,
            "dispositivo": s.dispositivo,
            "sistema_operativo": s.sistema_operativo,
            "ip_usuario": s.ip_usuario,
            "fecha_inicio": s.fecha_inicio.isoformat() if s.fecha_inicio else None,
            "fecha_expiracion": s.fecha_expiracion.isoformat() if s.fecha_expiracion else None,
            "estado_sesion": s.estado_sesion,
        }
        for s in sesiones
    ]


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Revocar sesión")
def revoke_session(
    session_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Revoca una sesión específica del usuario autenticado."""
    sesion = db.query(Sesion).filter(
        Sesion.id_sesion == session_id,
        Sesion.id_usuario == current_user.id_usuario
    ).first()

    if not sesion:
        raise HTTPException(
            status_code=404,
            detail="Sesión no encontrada"
        )

    sesion.estado_sesion = "revoked"
    db.commit()

    return None


def _generate_reset_token() -> str:
    """Generate a cryptographically secure 6-digit numeric code."""
    return ''.join([str(secrets.randbelow(10)) for _ in range(6)])


def _hash_token(token: str) -> str:
    """Hash the token for secure storage."""
    return hashlib.sha256(token.encode()).hexdigest()


@router.post("/forgot-password", response_model=PasswordResetResponse, summary="Solicitar recuperación de contraseña")
def forgot_password(
    request: PasswordResetRequest,
    db: Session = Depends(get_db)
):
    """Solicitar un código de recuperación de contraseña.
    
    Siempre devuelve el mismo mensaje genérico para no revelar si el correo existe.
    """
    user = db.query(Usuario).filter(
        or_(
            Usuario.correo == request.email,
            Usuario.correo == request.email.lower()
        )
    ).first()

    if user and user.estado_cuenta == "active":
        # Invalidate any existing unused tokens for this user
        db.query(PasswordResetToken).filter(
            PasswordResetToken.id_usuario == user.id_usuario,
            PasswordResetToken.used_at.is_(None),
            PasswordResetToken.expires_at > datetime.utcnow()
        ).update({"used_at": datetime.utcnow()}, synchronize_session=False)

        # Generate new token
        raw_token = _generate_reset_token()
        token_hash = _hash_token(raw_token)
        expires_at = datetime.utcnow() + timedelta(minutes=30)

        reset_token = PasswordResetToken(
            id_usuario=user.id_usuario,
            token_hash=token_hash,
            expires_at=expires_at,
        )
        db.add(reset_token)
        db.commit()

        # Send email with the raw token
        email_service.send_password_reset_email(user.correo, raw_token)

    # Always return the same message to prevent email enumeration
    return PasswordResetResponse(
        message="Si el correo está registrado, recibirás instrucciones para recuperar tu contraseña."
    )


@router.post("/reset-password", response_model=PasswordResetResponse, summary="Restablecer contraseña con código")
def reset_password(
    request: PasswordResetConfirm,
    db: Session = Depends(get_db)
):
    """Restablecer la contraseña usando el código recibido por correo."""
    token_hash = _hash_token(request.token)

    reset_token = db.query(PasswordResetToken).filter(
        PasswordResetToken.token_hash == token_hash,
        PasswordResetToken.used_at.is_(None),
        PasswordResetToken.expires_at > datetime.utcnow()
    ).first()

    if not reset_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Código inválido o expirado. Solicita uno nuevo."
        )

    user = db.query(Usuario).filter(Usuario.id_usuario == reset_token.id_usuario).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Usuario no encontrado."
        )

    if user.estado_cuenta != "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La cuenta no está activa. Contacta al administrador."
        )

    # Update password
    user.contrasena = hash_password(request.new_password)

    # Mark token as used
    reset_token.used_at = datetime.utcnow()

    # Revoke all active sessions for security
    db.query(Sesion).filter(
        Sesion.id_usuario == user.id_usuario,
        Sesion.estado_sesion == "active"
    ).update({Sesion.estado_sesion: "revoked"}, synchronize_session=False)

    db.commit()

    return PasswordResetResponse(
        message="Contraseña actualizada exitosamente. Por favor, inicia sesión con tu nueva contraseña."
    )


@router.post("/verify-email", response_model=PasswordResetResponse, summary="Verificar correo electrónico")
def verify_email(
    request: EmailVerificationConfirm,
    db: Session = Depends(get_db)
):
    """Verificar el correo electrónico usando el código recibido."""
    token_hash = _hash_token(request.token)

    verification_token = db.query(EmailVerificationToken).filter(
        EmailVerificationToken.token_hash == token_hash,
        EmailVerificationToken.used_at.is_(None),
        EmailVerificationToken.expires_at > datetime.utcnow()
    ).first()

    if not verification_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Código inválido o expirado. Solicita uno nuevo."
        )

    user = db.query(Usuario).filter(Usuario.id_usuario == verification_token.id_usuario).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Usuario no encontrado."
        )

    if user.estado_cuenta == "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La cuenta ya está verificada."
        )

    # Activate user account
    user.estado_cuenta = "active"

    # Mark token as used
    verification_token.used_at = datetime.utcnow()

    # Invalidate any other unused verification tokens for this user
    db.query(EmailVerificationToken).filter(
        EmailVerificationToken.id_usuario == user.id_usuario,
        EmailVerificationToken.id != verification_token.id,
        EmailVerificationToken.used_at.is_(None)
    ).update({"used_at": datetime.utcnow()}, synchronize_session=False)

    db.commit()

    return PasswordResetResponse(
        message="Correo verificado exitosamente. Ahora puedes iniciar sesión."
    )


@router.post("/resend-verification", response_model=PasswordResetResponse, summary="Reenviar código de verificación")
def resend_verification(
    request: EmailVerificationRequest,
    db: Session = Depends(get_db)
):
    """Reenviar el código de verificación al correo del usuario."""
    user = db.query(Usuario).filter(Usuario.correo == request.email).first()

    # Always return the same message to prevent email enumeration
    success_message = "Si el correo está registrado y la cuenta no está verificada, recibirás un nuevo código."

    if not user:
        return PasswordResetResponse(message=success_message)

    if user.estado_cuenta == "active":
        return PasswordResetResponse(message=success_message)

    # Invalidate any existing unused tokens
    db.query(EmailVerificationToken).filter(
        EmailVerificationToken.id_usuario == user.id_usuario,
        EmailVerificationToken.used_at.is_(None),
        EmailVerificationToken.expires_at > datetime.utcnow()
    ).update({"used_at": datetime.utcnow()}, synchronize_session=False)

    # Generate new token
    raw_token = _generate_reset_token()
    token_hash = _hash_token(raw_token)
    expires_at = datetime.utcnow() + timedelta(minutes=60)

    verification_token = EmailVerificationToken(
        id_usuario=user.id_usuario,
        token_hash=token_hash,
        expires_at=expires_at,
    )
    db.add(verification_token)
    db.commit()

    # Send verification email to the user's email
    email_service.send_verification_email(user.correo, raw_token)

    return PasswordResetResponse(message=success_message)
