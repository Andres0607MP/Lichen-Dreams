import os
os.environ.setdefault('DATABASE_URL', 'sqlite:///./test.db')
from unittest.mock import patch
from fastapi.testclient import TestClient
from main import app
from services import upload_service
from config.db import SessionLocal
from models.core import Imagen

# Wrapper to log calls to get_presigned_url_r2
original_get_presigned_url_r2 = upload_service.get_presigned_url_r2
def logging_get_presigned_url_r2(relative_path, expires_in=300):
    print(f'[DEBUG] get_presigned_url_r2 called with relative_path={relative_path!r}, expires_in={expires_in}')
    try:
        result = original_get_presigned_url_r2(relative_path, expires_in)
        print(f'[DEBUG] get_presigned_url_r2 returning: {result}')
        return result
    except Exception as e:
        print(f'[DEBUG] get_presigned_url_r2 raised exception: {e!r}')
        raise

# Apply the patch
upload_service.get_presigned_url_r2 = logging_get_presigned_url_r2

client = TestClient(app, follow_redirects=True)

# Replicate the test: test_public_article_image_without_auth
print('\\n--- Starting test replication ---')
# Subir imagen publica (no requiere auth)
files = {'file': ('test.jpg', b'\\xff\\xd8\\xff\\xe0' + b'article-data', 'image/jpeg')}
data = {'imagen_tipo': 'article'}
r = client.post('/imagenes/upload', files=files, data=data)
print(f'Upload status: {r.status_code}')
print(f'Upload response: {r.json()}')
assert r.status_code == 200, f'Upload failed: {r.text}'
image_url = r.json().get('url', '')
print(f'Image URL: {image_url}')
assert '/uploads/articles/' in image_url

# Acceder sin autenticacion
print('\\n--- Calling GET on image URL ---')
r = client.get(image_url)
print(f'GET status: {r.status_code}')
print(f'GET response: {r.text[:200]}')
assert r.status_code == 200, f'Expected 200 for public image without auth, got {r.status_code}: {r.text}'
print('\\n--- Test passed ---')
