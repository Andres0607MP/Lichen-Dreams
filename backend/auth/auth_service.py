from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from config.db import get_db
from models.core import Usuario
from .password_handler import verify_password
from .jwt_handler import decode_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def authenticate_user(db: Session, email: str, password: str):
	user = db.query(Usuario).filter(Usuario.correo == email).first()
	if not user:
		return None
	if not verify_password(password, getattr(user, 'contraseña')):
		return None
	return user


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
	payload = decode_token(token)
	if not payload:
		raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido")
	sub = payload.get("sub")
	if not sub:
		raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido")
	user = db.query(Usuario).filter(Usuario.correo == sub).first()
	if not user:
		raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuario no encontrado")
	return user
