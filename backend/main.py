from fastapi import FastAPI
from dotenv import load_dotenv
import os

load_dotenv()

DB_HOST = os.getenv("DB_HOST")
JWT_SECRET = os.getenv("JWT_SECRET")

app = FastAPI()

@app.get("/")
def root():
    return {
        "message": "Lichen Dreams API funcionando",
        "db_host": DB_HOST
    }