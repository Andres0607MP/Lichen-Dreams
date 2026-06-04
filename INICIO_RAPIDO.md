# 🎯 COMIENZA AQUÍ - GUÍA RÁPIDA (5 MINUTOS)

## Lo que ya está hecho ✅
- Backend configurado con FastAPI + JWT
- Frontend con Flutter + ApiService mejorado
- Base de datos diseñada
- Documentación completa
- Variables de entorno generadas

## Lo que DEBES HACER AHORA (3 pasos)

### PASO 1: Crear la Base de Datos
```
1. Abre MySQL Workbench
2. Conéctate a localhost
3. File → Open SQL Script
4. Abre: database/scripts/schema.sql
5. Ejecuta (Ctrl+Shift+Enter o ⚡)
```

Si no tienes Workbench, abre PowerShell:
```powershell
mysql -u root -p < database/scripts/schema.sql
```

### PASO 2: Instalar Dependencias
```powershell
# Backend
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Frontend (en nueva terminal)
cd frontend
flutter pub get
```

### PASO 3: Ejecutar el Proyecto
```powershell
# En la raíz del proyecto:
.\start-project.ps1
```

O manualmente en 2 terminales:

**Terminal 1:**
```powershell
cd backend
.\venv\Scripts\Activate.ps1
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

**Terminal 2:**
```powershell
cd frontend
flutter run
```

---

## ✅ Verificación

- Backend en: http://127.0.0.1:8000/docs (Swagger UI)
- Frontend: App Flutter abierta
- Login pantalla visible
- Base de datos con 9 tablas

---

## 📚 Documentación Completa

Ver archivos en la raíz del proyecto:
- `SETUP_PROYECTO.md` - Guía detallada
- `ESTADO_PROYECTO.md` - Estado completo y checklist
- `start-project.ps1` - Script automático

---

## 🚨 Si algo falla

1. Verifica que MySQL está corriendo: `mysql -u root -p -e "SELECT 1;"`
2. Verifica BD creada: `mysql -u root -p lichen_dreams -e "SHOW TABLES;"`
3. Si MySQL tiene contraseña, edita `backend/.env`
4. Si aún no funciona, revisa ESTADO_PROYECTO.md sección "Problemas"

---

## 🎮 Probar Login

1. Abre app Flutter
2. Intenta login (puede fallar porque no hay usuario aún)
3. Si ves errores claros = Backend está conectado ✅

Crear usuario vía API:
```powershell
curl -X POST "http://127.0.0.1:8000/auth/register" `
  -H "Content-Type: application/json" `
  -d '{
    "nombre": "Test",
    "apellido": "User",
    "email": "test@example.com",
    "password": "Test123!@"
  }'
```

---

**¿Listo?** Ejecuta `.\start-project.ps1` y comienza 🚀

---

**Última actualización:** Junio 3, 2026
**Proyecto completado por:** GitHub Copilot
**Estado:** 95% funcional - Falta ejecutar y crear BD manualmente
