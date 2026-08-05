# AGENTS.md

## Frontend (Flutter/Dart)

### Analyze / Lint
```bash
cd frontend
dart analyze .
# or
flutter analyze
```

### Run tests
```bash
cd frontend
flutter test
```

### Build for Android (pass API_BASE_URL)
```bash
cd frontend
flutter build apk --dart-define=API_BASE_URL=http://TU_IP:8000
```

## Backend (FastAPI/Python)

### Syntax check
```bash
cd backend
python -c "import ast; ast.parse(open('file.py').read()); print('OK')"
```

### Import check
```bash
cd backend
python -c "from routes.liquenpedia import router; print('OK')"
```

### Run tests
```bash
cd backend
python -m pytest tests/
```

### Migration script
```bash
cd backend
python scripts/migrate_image_urls.py
```

### Run server
```bash
cd backend
uvicorn main:app --reload
```
