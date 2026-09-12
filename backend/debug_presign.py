import os

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from services.upload_service import get_presigned_url_r2

from main import app

from fastapi.testclient import TestClient

client = TestClient(app, follow_redirects=True)



# Upload a file first

files = {"file": ("test.jpg", b"\\xff\\xd8\\xff\\xe0" + b"article-data", "image/jpeg")}

data = {"imagen_tipo": "article"}

r = client.post("/imagenes/upload", files=files, data=data)

print("Upload status:", r.status_code)

print("Upload response:", r.json())

if r.status_code != 200:

    print("Upload failed")

    exit(1)

image_url = r.json().get("url", "")

print("Image URL:", image_url)



# Now try to get presigned URL

try:

    signed_url = get_presigned_url_r2(image_url, expires_in=3600)

    print("Presigned URL:", signed_url)

except Exception as e:

    print("Error getting presigned URL:", e)

