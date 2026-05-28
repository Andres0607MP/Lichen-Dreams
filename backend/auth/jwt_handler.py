from jose import jwt
from datetime import datetime, timedelta

SECRET_KEY = "secret_key"
ALGORITHM = "HS256"

def create_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(hours=2)

    to_encode.update({"exp": expire})

    token = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

    return token