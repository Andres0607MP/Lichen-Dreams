from jose import jwt, JWTError
from datetime import datetime, timedelta
import os
from dotenv import load_dotenv

load_dotenv()

SECRET_KEY = os.getenv("JWT_SECRET", "secret_key")
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_HOURS = int(os.getenv("JWT_EXPIRE_HOURS", "2"))


def create_access_token(subject: str, expires_delta: int = None, sid: str = None):
    to_encode = {"sub": str(subject)}
    if sid:
        to_encode.update({"sid": sid})
    expire = datetime.utcnow() + timedelta(hours=(expires_delta or ACCESS_TOKEN_EXPIRE_HOURS))
    to_encode.update({"exp": expire})
    token = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return token


def create_refresh_token(subject: str, sid: str, expires_days: int = 30):
    to_encode = {"sub": str(subject), "sid": sid}
    expire = datetime.utcnow() + timedelta(days=expires_days)
    to_encode.update({"exp": expire})
    token = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return token


def decode_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None