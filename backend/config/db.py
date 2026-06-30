from sqlalchemy.orm import sessionmaker
from sqlalchemy.orm import declarative_base
from .database import engine

# Session local factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Declarative base for models
Base = declarative_base()

def get_db():
    """Dependency that yields a DB session and ensures it's closed."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
