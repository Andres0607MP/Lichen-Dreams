import os
os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")
from fastapi.testclient import TestClient
from main import app
from services.upload_service import get_presigned_url_r2, _r2_key_from_path, normalize_image_path, file_exists_in_r2
from config.db import SessionLocal
from models.core import Imagen

client = TestClient(app, follow_redirects=True)

# Upload
files = {"file": ("test.jpg", b"\xff\xd8\xff\xe0" + b"article-data", "image/jpeg")}
data = {"imagen_tipo": "article"}
r = client.post("/imagenes/upload", files=files, data=data)
print("Upload status:", r.status_code)
print("Upload response:", r.json())
if r.status_code != 200:
    print("Upload failed")
    exit(1)
image_url = r.json().get("url", "")
print("Image URL:", image_url)

# Check existence
normalized = normalize_image_path(image_url)
key = _r2_key_from_path(normalized)
print("Normalized:", normalized)
print("Key:", key)
exists = file_exists_in_r2(normalized)
print("File exists in R2:", exists)

# Get presigned URL via the service (direct)
try:
    signed_url = get_presigned_url_r2(image_url, expires_in=3600)
    print("Presigned URL (direct):", signed_url)
except Exception as e:
    print("Error getting presigned URL (direct):", e)

# Now try to get the image via the TestClient (this goes through the public_router)
print("Getting image via TestClient...")
r2 = client.get(image_url)
print("Image GET status:", r2.status_code)
print("Image GET response:", r2.text[:200] if r2.text else "")

# Also check via direct DB query
db = SessionLocal()
try:
    img = db.query(Imagen).filter(Imagen.url == image_url).first()
    print("Image in DB:", img is not None)
    if img:
        print("Image ID:", img.id_imagen)
finally:
    db.close()
