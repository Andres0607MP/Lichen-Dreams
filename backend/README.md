# Backend — Lichen Dreams

Pequeñas instrucciones para inicializar el backend (FastAPI).

Requisitos
- Python 3.8+
- `pip`

Instalación (Linux / macOS / Git Bash)

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

Instalación (Windows PowerShell)

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

Verificación
- Abrir `http://127.0.0.1:8000/docs` para comprobar Swagger UI.
- Endpoint raíz: `GET /` devuelve mensaje de servicio.

Notas
- No subir el archivo `.env` al repositorio.
