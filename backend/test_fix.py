#!/usr/bin/env python
"""Script de diagnóstico temporal; no ejecuta pytest ni interfiere con la suite."""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from config.db import SessionLocal
from models.core import Usuario

try:
    db = SessionLocal()
    db.query(Usuario).limit(1).all()
    print("Diagnóstico OK")
    db.close()
except Exception as e:
    print(f"Diagnóstico falló: {e}")
