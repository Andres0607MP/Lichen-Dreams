from fastapi import FastAPI
from dotenv import load_dotenv
import os
from config.database import engine

load_dotenv()

DB_HOST = os.getenv("DB_HOST")
JWT_SECRET = os.getenv("JWT_SECRET")

app = FastAPI()

@app.on_event("startup")
def startup():
    try:
        connection = engine.connect()
        print("Conexion exitosa a MySQL")
        connection.close()
    except Exception as e:
        print("Error de conexion:", e)

@app.get("/")
def root():
    return {
        "message": "Lichen Dreams API funcionando",
        "db_host": DB_HOST
    }