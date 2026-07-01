from sqlalchemy.orm import sessionmaker
from .database import engine
from models.base import Base  # Base único y compartido con todos los modelos

# Session local factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    """Dependency that yields a DB session and ensures it's closed."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
