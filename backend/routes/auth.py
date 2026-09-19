from datetime import date, datetime, timedelta
from fastapi import APIRouter, HTTPException, status, Depends, Form, Request
from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional, Literal
from sqlalchemy import or_
from sqlalchemy.orm import Session
import secrets
import hashlib
import logging
import uuid

from google.auth.exceptions import TransportError

from config.db import get_db
from config.settings import normalize_image_path, GOOGLE_CLIENT_ID, MAX_ACTIVE_SESSIONS
from models.core import Usuario, Sesion, Role, PasswordResetToken, EmailVerificationToken, RecoveryCode
from auth.password_handler import hash_password, verify_password
from auth.jwt_handler import create_access_token, create_refresh_token, decode_token
from auth.auth_service import authenticate_user, get_current_user
from websocket.connection_manager import connection_manager
from models.validations import PasswordResetRequest, PasswordResetConfirm, PasswordResetResponse, EmailVerificationRequest, EmailVerificationConfirm, RegisterResponse, RecoverWithCodeRequest, RegenerateRecoveryCodeResponse, FcmTokenRequest
from services.email_service import email_service
from services.upload_service import download_and_save_profile_image

router = APIRouter()

# Alfabeto sin caracteres ambiguos (0/O, 1/I/L) para códigos fáciles de copiar.
RECOVERY_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
RECOVERY_CODE_EXPIRATION_DAYS = 90


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
    proveedor: Optional[str] = None

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    user: UserResponse


class GoogleLoginRequest(BaseModel):
    id_token: str
    # 'registro': crea la cuenta si el Google no existe (default).
    # 'login': autentica únicamente cuentas Google ya registradas.
    modo: Literal["login", "registro"] = "registro"


def _parse_client_device(user_agent: str | None):
    """Extrae una etiqueta corta (dispositivo / sistema operativo) del User-Agent."""
    ua = (user_agent or "").lower()
    if 'android' in ua:
        dispositivo, so = 'Móvil', 'Android'
    elif 'iphone' in ua or 'ipad' in ua:
        dispositivo, so = ('Tablet' if 'ipad' in ua else 'Móvil'), 'iOS'
    elif 'windows' in ua:
        dispositivo, so = 'Escritorio', 'Windows'
    elif 'mac os' in ua or 'macintosh' in ua:
        dispositivo, so = 'Escritorio', 'macOS'
    elif 'linux' in ua:
        dispositivo, so = 'Escritorio', 'Linux'
    else:
        dispositivo, so = 'Desconocido', 'Desconocido'
    return dispositivo, so


def _normalize_optional_header(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    return value or None


def _allocate_session(
    db: Session,
    user: Usuario,
    device_id: str | None,
    device_name: str | None,
    user_agent: str | None = None,
    client_ip: str | None = None,
) -> str:
    """Crea una sesión activa nueva dentro de la transacción actual."""
    now = datetime.utcnow()

    try:
        with db.begin_nested():
            # Serializa la asignación por usuario y evita carreras cuando no hay filas activas.
            db.query(Usuario).filter(
                Usuario.id_usuario == user.id_usuario
            ).with_for_update().one()

            expired_sessions = db.query(Sesion).filter(
                Sesion.id_usuario == user.id_usuario,
                Sesion.estado_sesion == "active",
                Sesion.fecha_expiracion.is_not(None),
                Sesion.fecha_expiracion < now,
            ).with_for_update().all()
            for sesion in expired_sessions:
                sesion.estado_sesion = "revoked"
            if expired_sessions:
                db.flush()

            active_sessions = db.query(Sesion).filter(
                Sesion.id_usuario == user.id_usuario,
                Sesion.estado_sesion == "active",
            ).with_for_update().order_by(Sesion.fecha_inicio.asc()).all()

            same_device_sessions = []
            if device_id is not None:
                same_device_sessions = [
                    sesion for sesion in active_sessions
                    if sesion.device_id == device_id
                ]
            for sesion in same_device_sessions:
                sesion.estado_sesion = "revoked"
            if same_device_sessions:
                db.flush()

            active_count = sum(
                1 for sesion in active_sessions
                if sesion.estado_sesion == "active"
            )

            if active_count >= MAX_ACTIVE_SESSIONS:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="SESSION_LIMIT_REACHED",
                    headers={"WWW-Authenticate": "Bearer"},
                )

            sid = uuid.uuid4().hex
            token_hash = _hash_token(sid)
            dispositivo, sistema_operativo = _parse_client_device(user_agent)

            sesion = Sesion(
                token_sesion_hash=token_hash,
                dispositivo=dispositivo,
                sistema_operativo=sistema_operativo,
                ip_usuario=(client_ip or None)[:50] if client_ip else None,
                device_id=device_id,
                nombre_dispositivo=device_name,
                fecha_inicio=now,
                fecha_expiracion=now + timedelta(days=30),
                estado_sesion="active",
                id_usuario=user.id_usuario,
            )

            db.add(sesion)
            db.flush()
    except HTTPException:
        raise

    return sid


def _issue_auth_tokens(
    db: Session,
    user: Usuario,
    device_id: str | None = None,
    device_name: str | None = None,
    user_agent: str | None = None,
    client_ip: str | None = None,
) -> dict:
    """Crea una sesión activa nueva y emite los JWT de Lichen Dreams.

    Respeta el límite de sesiones activas configurado (por defecto 3).
    Si ya se alcanza el límite, rechaza el login sin crear ni revocar sesiones.
    """
    sid = _allocate_session(
        db,
        user,
        device_id=device_id,
        device_name=device_name,
        user_agent=user_agent,
        client_ip=client_ip,
    )

    access = create_access_token(
        subject=user.correo,
        sid=sid,
    )

    refresh = create_refresh_token(
        subject=user.correo,
        sid=sid,
    )

    db.commit()

    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "bearer",
        "user": {
            "id_usuario": user.id_usuario,
            "correo": user.correo,
            "nombre": user.nombre,
            "telefono": user.telefono,
            "foto_perfil": user.foto_perfil,
            "id_rol": user.id_rol,
            "rol": user.rol.nombre_rol if user.rol else None,
            "proveedor": user.proveedor,
        },
    }


@router.post("/login", response_model=TokenResponse, summary="Iniciar sesión")
def login(
    request: Request,
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

    device_id = _normalize_optional_header(request.headers.get("X-Device-ID"))
    device_name = _normalize_optional_header(request.headers.get("X-Device-Name"))

    return _issue_auth_tokens(
        db,
        user,
        device_id=device_id,
        device_name=device_name,
        user_agent=request.headers.get("user-agent"),
        client_ip=request.client.host if request.client else None,
    )


def verify_google_id_token(id_token: str) -> dict:
    """Valida criptográficamente un ID token de Google y devuelve sus claims.

    Usa la librería oficial google-auth (google.oauth2.id_token) que verifica:
    firma, issuer (Google), audience (GOOGLE_CLIENT_ID) y expiración.
    Lanza ValueError ante cualquier token inválido o si no está configurado
    GOOGLE_CLIENT_ID.
    """
    client_id = GOOGLE_CLIENT_ID.strip()
    if not client_id:
        raise ValueError("GOOGLE_CLIENT_ID no está configurado")

    from google.oauth2 import id_token as google_id_token
    from google.auth.transport import requests as google_requests

    req = google_requests.Request()
    info = google_id_token.verify_oauth2_token(id_token, req, audience=client_id)

    if not info.get("sub"):
        raise ValueError("El token no contiene un sub válido")

    return info


@router.post("/google", response_model=TokenResponse, summary="Iniciar sesión con Google")
def google_login(
    request: Request,
    body: GoogleLoginRequest,
    db: Session = Depends(get_db)
):
    """Inicia sesión creando/recuperando un usuario local a partir de un ID token de Google.

    No confía en datos enviados por el cliente: todos los datos del usuario se
    obtienen del token verificado criptográficamente (sub, email, nombre, foto).

    Si ya existe una cuenta (local u otra de Google) con ese correo no se vincula
    automáticamente: se devuelve 409 para que el usuario use su flujo normal.
    """
    try:
        info = verify_google_id_token(body.id_token)
    except TransportError:
        # Diagnóstico temporal: Google no es alcanzable para descargar las claves
        # públicas de verificación (bloqueo de red/firewall en el servidor).
        logging.error("[GOOGLE-DEBUG] TransportError al validar el ID token de Google.")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No se pudo contactar a Google para validar el token. Verifica la conexión del servidor."
        )
    except ValueError as e:
        # Diagnóstico temporal: registrar el motivo real del rechazo (aud,
        # firma, expiración, configuración) sin exponer información al cliente.
        logging.warning("[GOOGLE-DEBUG] ValueError al validar ID token de Google (client_id=%s): %s",
                        ("seteado" if GOOGLE_CLIENT_ID.strip() else "VACIO"),
                        e)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de Google inválido o expirado."
        )

    sub = info.get("sub")
    email = (info.get("email") or "").lower().strip()

    user = db.query(Usuario).filter(
        Usuario.proveedor == "google",
        Usuario.proveedor_id == sub
    ).first()

    if user:
        # La cuenta de Google YA existe.
        if body.modo == "registro":
            # Desde Crear cuenta: no duplicar, indicar que inicie sesión.
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Esta cuenta de Google ya está registrada. Inicia sesión para continuar."
            )
        # Desde Login: sincronizar la foto de Google descargándola localmente
        # (sin sobrescribir una foto personalizada local).
        google_picture = info.get("picture")
        if google_picture:
            current_foto = user.foto_perfil or ""
            is_google_photo = (
                current_foto.startswith("http://")
                or current_foto.startswith("https://")
            )
            if not current_foto or is_google_photo:
                local_path = download_and_save_profile_image(
                    google_picture, user.id_usuario)
                if local_path:
                    user.foto_perfil = local_path
                    db.commit()
                    db.refresh(user)
    elif body.modo == "login":
        # Login con Google NO registrado: rechazar sin crear cuenta ni sesión.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Esta cuenta de Google no está registrada. Crea una cuenta usando 'Continuar con Google' en Crear cuenta."
        )
    else:
        # Registro (Crear cuenta) con Google inexistente: crear cuenta.
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El token de Google no incluye un correo válido."
            )

        existing = db.query(Usuario).filter(Usuario.correo == email).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Ya existe una cuenta con este correo. Inicia sesión con tu correo y contraseña."
            )

        user_role = db.query(Role).filter(Role.nombre_rol == "user").first()
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
            nombre=info.get("given_name") or info.get("name"),
            apellido=info.get("family_name"),
            correo=email,
            contrasena=None,
            foto_perfil=None,
            estado_cuenta="active",
            id_rol=user_role.id_rol,
            proveedor="google",
            proveedor_id=sub
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        # Descargar la foto de Google y guardarla localmente como foto de perfil.
        google_picture = info.get("picture")
        if google_picture:
            local_path = download_and_save_profile_image(
                google_picture, user.id_usuario)
            if local_path:
                user.foto_perfil = local_path
                db.commit()
                db.refresh(user)

    if user.estado_cuenta != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cuenta desactivada. Contacta al administrador."
        )

    # Diagnóstico temporal [GOOGLE-DEBUG]: confirmar el valor real de la foto
    # en el token vs el persistido en la BD (no imprime tokens ni crecenciales).
    logging.info(
        "[GOOGLE-DEBUG] picture presente=%s url=%s | BD usuarios.foto_perfil=%s",
        bool(info.get("picture")),
        (info.get("picture") or "(sin picture)")[:120],
        (user.foto_perfil or "(NULL)"),
    )

    device_id = _normalize_optional_header(request.headers.get("X-Device-ID"))
    device_name = _normalize_optional_header(request.headers.get("X-Device-Name"))

    return _issue_auth_tokens(
        db,
        user,
        device_id=device_id,
        device_name=device_name,
        user_agent=request.headers.get("user-agent"),
        client_ip=request.client.host if request.client else None,
    )


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
        estado_cuenta="active",
        id_rol=user_role.id_rol,
        proveedor="local"
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    raw_code = _store_recovery_code(db, user.id_usuario)
    db.commit()

    return RegisterResponse(
        message="Registro exitoso. Tu cuenta está activa. Guarda tu código de recuperación en un lugar seguro.",
        email=user.correo,
        recovery_code=raw_code,
        requires_email_verification=False,
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
        "rol": current_user.rol.nombre_rol if current_user.rol else None,
        "proveedor": current_user.proveedor
    }


@router.post("/fcm-token", summary="Registrar token FCM de la sesión actual")
def register_fcm_token(
    payload: FcmTokenRequest,
    request: Request,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    authorization = request.headers.get("Authorization", "")
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido")

    token = authorization[7:].strip()
    jwt_payload = decode_token(token)
    sid = jwt_payload.get("sid") if jwt_payload else None
    if not sid:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Sesión inválida")

    sid_hash = hashlib.sha256(sid.encode()).hexdigest()
    sesion = db.query(Sesion).filter(
        Sesion.token_sesion_hash == sid_hash,
        Sesion.id_usuario == current_user.id_usuario,
    ).first()
    if not sesion or sesion.estado_sesion != "active":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Sesión inválida o revocada")

    sesion.fcm_token = payload.fcm_token
    db.commit()
    return {"message": "Token FCM registrado"}


@router.post("/logout", summary="Cerrar sesión")
def logout(
    request: Request,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Revoca únicamente la sesión actual asociada al token."""
    # Extraer token del encabezado Authorization
    authorization = request.headers.get("Authorization")
    sid = None
    if authorization and authorization.startswith("Bearer "):
        token = authorization[7:]
        try:
            payload = decode_token(token)
            if payload:
                sid = payload.get("sid")
        except Exception:
            pass
    if sid:
        sid_hash = hashlib.sha256(sid.encode()).hexdigest()
        sesion = db.query(Sesion).filter(
            Sesion.token_sesion_hash == sid_hash,
            Sesion.id_usuario == current_user.id_usuario
        ).first()
        if sesion:
            sesion.estado_sesion = "revoked"
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
    sid_hash = hashlib.sha256(sid.encode()).hexdigest()
    sesion = db.query(Sesion).filter(
        Sesion.token_sesion_hash == sid_hash
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

    sid_hash = hashlib.sha256(sid.encode()).hexdigest()
    sesion = db.query(Sesion).filter(
        Sesion.token_sesion_hash == sid_hash
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

    # Revocar todas las sesiones activas por seguridad
    from auth.auth_service import revoke_all_sessions
    revoke_all_sessions(current_user.id_usuario, db)

    return None


@router.get("/sessions", summary="Obtener sesiones activas")
def get_sessions(
    request: Request,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Obtiene únicamente las sesiones activas del usuario autenticado."""
    sesiones = db.query(Sesion).filter(
        Sesion.id_usuario == current_user.id_usuario,
        Sesion.estado_sesion == "active"
    ).order_by(Sesion.fecha_inicio.desc()).all()

    current_session_id = None
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[7:]
        payload = decode_token(token)
        if payload:
            sid = payload.get("sid")
            if sid:
                sid_hash = hashlib.sha256(sid.encode()).hexdigest()
                current_sesion = db.query(Sesion).filter(
                    Sesion.token_sesion_hash == sid_hash,
                    Sesion.id_usuario == current_user.id_usuario,
                ).first()
                if current_sesion:
                    current_session_id = current_sesion.id_sesion

    return [
        {
            "id_sesion": s.id_sesion,
            "dispositivo": s.dispositivo,
            "sistema_operativo": s.sistema_operativo,
            "ip_usuario": s.ip_usuario,
            "device_id": s.device_id,
            "nombre_dispositivo": s.nombre_dispositivo,
            "fecha_inicio": s.fecha_inicio.isoformat() if s.fecha_inicio else None,
            "fecha_expiracion": s.fecha_expiracion.isoformat() if s.fecha_expiracion else None,
            "estado_sesion": s.estado_sesion,
            "es_actual": s.id_sesion == current_session_id,
        }
        for s in sesiones
    ]


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Revocar sesión")
async def revoke_session(
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
    await connection_manager.send_session_revoked(sesion.id_sesion)

    return None


def _generate_reset_token() -> str:
    """Generate a cryptographically secure 6-digit numeric code."""
    return ''.join([str(secrets.randbelow(10)) for _ in range(6)])


def _hash_token(token: str) -> str:
    """Hash the token for secure storage."""
    return hashlib.sha256(token.encode()).hexdigest()


def _normalize_recovery_code(code: str) -> str:
    """Normaliza un código de recuperación a su forma canónica (LCHN-XXXX-XXXX-XXXX).

    Es tolerante con espacios, guiones y mayúsculas/minúsculas.
    """
    cleaned = code.strip().upper().replace(' ', '').replace('-', '')
    if len(cleaned) == 16 and cleaned.startswith("LCHN"):
        return f"{cleaned[0:4]}-{cleaned[4:8]}-{cleaned[8:12]}-{cleaned[12:16]}"
    return cleaned


def _generate_recovery_code() -> str:
    """Genera un código de recuperación criptográficamente seguro.

    Formato: LCHN-XXXX-XXXX-XXXX (prefijo fijo + 12 caracteres aleatorios).
    Nunca se registra en logs ni se almacena en texto plano en la base de datos.
    """
    group = lambda n: ''.join(secrets.choice(RECOVERY_CODE_ALPHABET) for _ in range(n))
    return f"LCHN-{group(4)}-{group(4)}-{group(4)}"


def _store_recovery_code(db: Session, user_id: int, days: int = RECOVERY_CODE_EXPIRATION_DAYS) -> str:
    """Genera, hashea y guarda un código de recuperación para el usuario.

    Devuelve el código original (texto plano) una única vez.
    """
    raw_code = _generate_recovery_code()
    code_hash = _hash_token(_normalize_recovery_code(raw_code))

    record = RecoveryCode(
        id_usuario=user_id,
        code_hash=code_hash,
        expires_at=datetime.utcnow() + timedelta(days=days),
    )
    db.add(record)
    return raw_code


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

    if (user.proveedor or "local") == "google":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Esta cuenta utiliza Google y no tiene una contraseña local."
        )

    # Update password
    user.contrasena = hash_password(request.new_password)

    # Mark token as used
    reset_token.used_at = datetime.utcnow()

# Revocar todas las sesiones activas por seguridad
    from auth.auth.service import revoke_all_sessions
    revoke_all_sessions(current_user.id_usuario, db)

    return PasswordResetResponse(
        message="Contraseña actualizada exitosamente. Por favor, inicia sesión con tu nueva contraseña."
    )


@router.post("/recover-with-code", response_model=PasswordResetResponse, summary="Recuperar contraseña con código de recuperación")
def recover_with_code(
    request: RecoverWithCodeRequest,
    db: Session = Depends(get_db)
):
    """Restablecer la contraseña usando el código de recuperación de un solo uso.

    No inicia sesión automáticamente y revoca todas las sesiones activas.
    Utiliza el mensaje genérico como el flujo por correo para no permitir enumerar usuarios.
    """
    canonical_code = _normalize_recovery_code(request.code)
    code_hash = _hash_token(canonical_code)

    record = db.query(RecoveryCode).filter(
        RecoveryCode.code_hash == code_hash,
        RecoveryCode.used_at.is_(None),
        RecoveryCode.expires_at > datetime.utcnow()
    ).first()

    if not record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Código de recuperación inválido, expirado o ya utilizado."
        )

    user = db.query(Usuario).filter(Usuario.id_usuario == record.id_usuario).first()
    if not user or user.estado_cuenta != "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Código de recuperación inválido, expirado o ya utilizado."
        )

    if (user.proveedor or "local") == "google":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Esta cuenta utiliza Google y no tiene una contraseña local."
        )

    # Update password using the same bcrypt mechanism as the rest of the system
    user.contrasena = hash_password(request.new_password)

    # Mark the code as used (single use)
    record.used_at = datetime.utcnow()

    # Invalidate any other unused recovery codes for this user
    db.query(RecoveryCode).filter(
        RecoveryCode.id_usuario == user.id_usuario,
        RecoveryCode.id != record.id,
        RecoveryCode.used_at.is_(None)
    ).update({"used_at": datetime.utcnow()}, synchronize_session=False)

    # Revocar todas las sesiones activas por seguridad
    from auth.auth.service import revoke_all_sessions
    revoke_all_sessions(user.id_usuario, db)

    return PasswordResetResponse(
        message="Contraseña actualizada exitosamente. Por favor, inicia sesión con tu nueva contraseña."
    )


@router.post("/recovery-code/regenerate", response_model=RegenerateRecoveryCodeResponse, summary="Regenerar código de recuperación")
def regenerate_recovery_code(
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Genera un nuevo código de recuperación para el usuario autenticado.

    Invalida cualquier código anterior (se marca como utilizado) y devuelve
    el código nuevo una única vez. El backend no puede mostrar el código
    original posteriormente.
    """
    db.query(RecoveryCode).filter(
        RecoveryCode.id_usuario == current_user.id_usuario,
        RecoveryCode.used_at.is_(None)
    ).update({"used_at": datetime.utcnow()}, synchronize_session=False)

    raw_code = _store_recovery_code(db, current_user.id_usuario)
    db.commit()

    return RegenerateRecoveryCodeResponse(
        message="Tu nuevo código de recuperación se generó correctamente. Guárdalo en un lugar seguro.",
        recovery_code=raw_code
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
