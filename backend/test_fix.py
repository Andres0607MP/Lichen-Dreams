#!/usr/bin/env python
"""Test script to verify the fix"""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from config.db import SessionLocal
from models.core import Usuario

try:
    db = SessionLocal()
    # Try to query usuarios - this should work now
    users = db.query(Usuario).limit(1).all()
    print("✓ Query successful!")
    print(f"✓ Database connection working")
    print(f"✓ No more 'Unknown column' errors")
    db.close()
except Exception as e:
    print(f"✗ Error: {e}")
    sys.exit(1)
