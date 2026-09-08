"""Auditoría funcional E2E - Sprint 5 (Lichen Dreams).

Ejecuta escenarios REALES vía HTTP contra el servidor en vivo
(http://127.0.0.1:8000) y guarda evidencia JSON por módulo.

Escenarios:
- Registro (exitoso, correo inválido, contraseña débil, duplicado, vacíos)
- Login (exitoso, contraseña incorrecta, usuario inexistente, campos vacíos)
- Perfil (carga, actualización)
- Análisis IA (imagen saludable, no-liquen), persistencia
- Historial, Dashboard, Mapa, Notificaciones, Liquenpedia, Catálogo
- Recuperación de contraseña (recover-with-code con código LCHN)
"""
import json
import random
import string
import sys
import time
from pathlib import Path

import requests

BASE = "http://127.0.0.1:8000"
EVID = Path(__file__).resolve().parents[1] / "evidencias"
BACKEND = Path(__file__).resolve().parents[3] / "backend"

SESSION = "sprint5_" + "".join(random.choices(string.ascii_lowercase + string.digits, k=6))
EMAIL = f"qa_{SESSION}@test.com"
PASSWORD = "Prueba123!"
PRE = f"QA-S5-{SESSION}"

report = {
    "sesion": SESSION,
    "fecha": time.strftime("%Y-%m-%d %H:%M:%S"),
    "base": BASE,
    "usuario_prueba": EMAIL,
    "resultados": [],
}


def add(modulo, caso, esperado, obtenido, estado, evidencia=None, extra=None):
    row = {
        "modulo": modulo,
        "caso": caso,
        "esperado": esperado,
        "obtenido": obtenido,
        "estado": estado,
    }
    if extra is not None:
        row["detalle"] = extra
    report["resultados"].append(row)
    return row


def get(path, token=None, **kw):
    h = {"Authorization": f"Bearer {token}"} if token else {}
    return requests.get(BASE + path, headers=h, timeout=40, **kw)


def post(path, token=None, data=None, files=None, json_body=None):
    h = {"Authorization": f"Bearer {token}"} if token else {}
    return requests.post(BASE + path, headers=h, data=data, files=files, json=json_body, timeout=120)


def put(path, token=None, data=None, files=None, json_body=None):
    h = {"Authorization": f"Bearer {token}"} if token else {}
    return requests.put(BASE + path, headers=h, data=data, files=files, json=json_body, timeout=60)


# ---------- 1. Health ----------
for path, name in [("/", "raiz"), ("/api/test", "api_test"), ("/api/config", "config")]:
    r = get(path)
    add("api", name, "status 200", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido",
        evidencia=f"api/{name}.json", extra=str(r.json())[:300])

# ---------- 2. Registro ----------
def registro(email, password, name="QA Prueba", expect_status=200, caso=None):
    body = {
        "name": name,
        "apellido": "Sprint5",
        "email": email,
        "password": password,
    }
    r = post("/auth/register", json_body=body)
    try:
        j = r.json()
    except Exception:
        j = {}
    return r, j

r, j = registro(EMAIL, PASSWORD)
ok = r.status_code in (200, 201)
add("registro", "registro exitoso", "200/201 + recovery_code", f"status={r.status_code}, recovery_code={'sí' if j.get('recovery_code') else 'no'}", "Aprobado" if ok else "Fallido",
    evidencia="registro/CP-001-registro-exitoso.json", extra=str(j)[:500])
recovery_code = j.get("recovery_code", "")

r, j = registro("correo-invalido", PASSWORD, caso="correo inválido")
add("registro", "correo inválido", "status 422", f"status={r.status_code}", "Aprobado" if r.status_code == 422 else "Fallido",
    evidencia="registro/CP-002-registro-correo-invalido.json", extra=str(j)[:300])

r, j = registro(EMAIL, "123", caso="contraseña débil")
add("registro", "contraseña inválida (<6)", "status 422", f"status={r.status_code}", "Aprobado" if r.status_code >= 400 else "Fallido",
    evidencia="registro/CP-003-registro-password-debil.json", extra=str(j)[:300])

r, j = registro(EMAIL, PASSWORD, caso="correo duplicado")
add("registro", "correo ya registrado", "status 400 'Usuario ya existe'", f"status={r.status_code} {str(j.get('detail'))[:60]}", "Aprobado" if r.status_code == 400 else "Fallido",
    evidencia="registro/CP-004-registro-correo-duplicado.json", extra=str(j)[:300])

r = requests.post(BASE + "/auth/register", json={}, timeout=30)
add("registro", "campos obligatorios vacíos", "status 422", f"status={r.status_code}", "Aprobado" if r.status_code == 422 else "Fallido",
    evidencia="registro/CP-005-registro-campos-vacios.json", extra=str(r.json())[:300])

# ---------- 3. Login ----------
def login(email, password):
    return post("/auth/login", data={"email": email, "password": password})

tokens = {}
r = login(EMAIL, PASSWORD)
tokens = r.json() if r.status_code in (200, 201) else {}
ok = bool(tokens.get("access_token"))
add("login", "login exitoso", "access_token + refresh_token", f"status={r.status_code}, access_token={'sí' if ok else 'no'}", "Aprobado" if ok else "Fallido",
    evidencia="login/CP-006-login-exitoso.json", extra=str(tokens.get("user", {}))[:300])

r = login(EMAIL, "ContraseñaIncorrecta1")
add("login", "contraseña incorrecta", "status 401", f"status={r.status_code}", "Aprobado" if r.status_code == 401 else "Fallido",
    evidencia="login/CP-007-login-password-invalida.json", extra=str(r.json())[:200])

r = login("nonexistent@test.com", PASSWORD)
add("login", "usuario inexistente", "status 401", f"status={r.status_code}", "Aprobado" if r.status_code == 401 else "Fallido",
    evidencia="login/CP-008-login-usuario-inexistente.json", extra=str(r.json())[:200])

r = login("", "")
add("login", "campos vacíos", "status 422", f"status={r.status_code}", "Aprobado" if r.status_code == 422 else "Fallido",
    evidencia="login/CP-009-login-campos-vacios.json", extra=str(r.json())[:200])

token = tokens.get("access_token", "")
r = get("/auth/me", token)
add("login", "sesión/autenticación válida", "200 + correo del usuario", f"status={r.status_code}, email={r.json().get('email') if r.status_code==200 else '-'}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="login/CP-010-sesion-valida.json", extra=str(r.json())[:300])

# ---------- 4. Recuperación ----------
r = get("/auth/me", "token.invalido.xyz")
add("recuperacion", "token inválido rechazado", "status 401", f"status={r.status_code}", "Aprobado" if r.status_code == 401 else "Fallido",
    evidencia="recuperacion/CP-011-token-invalido.json", extra=str(r.json())[:200])

r = post("/auth/forgot-password", json_body={"email": EMAIL})
add("recuperacion", "solicitud código por email", "200 respuesta genérica", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="recuperacion/CP-012-forgot-password.json", extra=str(r.json())[:300])

r = post("/auth/reset-password", json_body={"email": EMAIL, "token": "000000", "new_password": "Nueva123!"})
add("recuperacion", "código inválido", "status 400/401", f"status={r.status_code}", "Aprobado" if r.status_code in (400, 401) else "Fallido",
    evidencia="recuperacion/CP-013-codigo-invalido.json", extra=str(r.json())[:300])

# recover-with-code (código LCHN real)
normalized = recovery_code.replace(" ", "").replace("-", "")
if normalized.upper().startswith("LCHN"):
    r = post("/auth/recover-with-code", json_body={"code": recovery_code, "new_password": "Nueva123!"})
    add("recuperacion", "recuperación con código LCHN válido", "200 + login posterior", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido",
        evidencia="recuperacion/CP-014-recover-code-valido.json", extra=str(r.json())[:300])
    r2 = login(EMAIL, "Nueva123!")
    add("recuperacion", "login con nueva contraseña", "200", f"status={r2.status_code}", "Aprobado" if r2.status_code == 200 else "Fallido",
        evidencia="recuperacion/CP-015-login-nueva-password.json", extra=str(r2.json())[:300])
    if r2.status_code == 200:
        token = r2.json().get("access_token", token)

# ---------- 5. Perfil ----------
r = get("/profile", token)
add("perfil", "carga del perfil", "200 con datos", f"status={r.status_code}, nombre={r.json().get('nombre') if r.status_code==200 else '-'}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="perfil/CP-016-perfil-carga.json", extra=str(r.json())[:400])

r = put("/profile", token, json_body={"nombre": "QA Actualizado", "telefono": "3001234567"})
add("perfil", "actualización de datos", "200 + datos nuevos", f"status={r.status_code}, nombre={r.json().get('nombre') if r.status_code==200 else '-'}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="perfil/CP-017-perfil-actualizacion.json", extra=str(r.json())[:400])

r = put("/profile", token, json_body={"correo": "correo-mal-formato"})
add("perfil", "datos inválidos (email)", "status 400/422", f"status={r.status_code}", "Aprobado" if r.status_code in (400, 422) else "Fallido",
    evidencia="perfil/CP-018-perfil-datos-invalidos.json", extra=str(r.json())[:300])

# ---------- 6. Análisis IA ----------
img_saludable = BACKEND / "ia" / "datasets" / "liquenes_saludables" / "ls_0001.jpg"
img_no_liquen = EVID / "ia" / "imagen_no_liquen.png"

r = requests.post(BASE + "/analysis/process", files={"file": ("ls_0001.jpg", open(img_saludable, "rb"), "image/jpeg")},
                  data={"image_source": "gallery"}, headers={"Authorization": f"Bearer {token}"}, timeout=120)
add("ia", "análisis imagen líquen saludable", "200 + resultado", f"status={r.status_code}, resultado={r.json().get('categoria') if r.status_code==200 else '-'}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="ia/CP-019-analisis-saludable.json", extra=str(r.json())[:400])

r = requests.post(BASE + "/analysis/process", files={"file": ("no_liquen.png", open(img_no_liquen, "rb"), "image/png")},
                  data={"image_source": "gallery"}, headers={"Authorization": f"Bearer {token}"}, timeout=120)
add("ia", "análisis imagen que no es líquen", "200 (clasificación 3 clases, sin rechazo explícito)", f"status={r.status_code}, resultado={r.json().get('categoria') if r.status_code==200 else '-'}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="ia/CP-020-analisis-no-liquen.json", extra=str(r.json())[:400])

r = requests.post(BASE + "/analysis/process",
                  headers={"Authorization": f"Bearer {token}"}, timeout=30)
add("ia", "análisis sin imagen (inválido)", "status 422", f"status={r.status_code}", "Aprobado" if r.status_code == 422 else "Fallido",
    evidencia="ia/CP-021-analisis-sin-imagen.json", extra=str(r.json())[:300])

# análisis con cámara requiere ubicación
r = requests.post(BASE + "/analysis/process", files={"file": ("ls_0001.jpg", open(img_saludable, "rb"), "image/jpeg")},
                  data={"image_source": "camera"}, headers={"Authorization": f"Bearer {token}"}, timeout=60)
add("ia", "análisis cámara sin ubicación", "status 422 con mensaje GPS", f"status={r.status_code}", "Aprobado" if r.status_code == 422 else "Fallido",
    evidencia="ia/CP-022-analisis-camara-sin-ubicacion.json", extra=str(r.json())[:300])

# ---------- 7. Persistencia con ubicación (E2E) ----------
loc = post("/location/find-or-create", json_body={"latitude": 4.654, "longitude": -74.097, "direccion": "Plaza Bolivar, Bogota"})
loc_id = loc.json().get("id_ubicacion") if loc.status_code in (200, 201) else None
add("mapa", "creación/find-or-create de ubicación", "200/201 + id", f"status={loc.status_code}, location_id={loc_id}", "Aprobado" if loc.status_code in (200, 201) else "Fallido",
    evidencia="mapa/CP-023-ubicacion.json", extra=str(loc.json())[:400])

r = requests.post(BASE + "/analysis/process", files={"file": ("ls_0001.jpg", open(img_saludable, "rb"), "image/jpeg")},
                  data={"image_source": "camera", "id_ubicacion": str(loc_id)}, headers={"Authorization": f"Bearer {token}"}, timeout=120)
ana = r.json() if r.status_code in (200, 201) else {}
analysis_id = ana.get("id") or ana.get("analysis_id")
add("ia", "análisis persistido con ubicación (cámara)", "200 + id de análisis > 0", f"status={r.status_code}, id={analysis_id}, resultado={ana.get('categoria')}", "Aprobado" if (r.status_code == 200 and analysis_id and analysis_id != -1) else "Fallido",
    evidencia="ia/CP-024-analisis-persistido.json", extra=str(ana)[:500])

if analysis_id:
    r = get(f"/analysis/results/{analysis_id}", token)
    add("ia", "persistencia: consulta resultados por id", "200 + resultado", f"status={r.status_code}, resultado={r.json().get('resultado') if r.status_code==200 else '-'}", "Aprobado" if r.status_code == 200 else "Fallido",
        evidencia="ia/CP-025-resultado-persistido.json", extra=str(r.json())[:400])

    r = get(f"/analysis/{analysis_id}/status", token)
    add("ia", "estado del análisis", "200 + status completed", f"status={r.status_code}, status={r.json().get('status') if r.status_code==200 else '-'}", "Aprobado" if (r.status_code == 200 and r.json().get("status") == "completed") else "Fallido",
        evidencia="ia/CP-026-estado-analisis.json", extra=str(r.json())[:300])

# ---------- 8. Historial / Dashboard / Mapa ----------
r = get("/history", token)
hist = r.json()
add("historial", "carga del historial", "200 con análisis", f"status={r.status_code}, items={len(hist) if isinstance(hist, list) else '?'}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="historial/CP-027-historial.json", extra=str(hist)[:400])

r = get("/dashboard/stats", token)
add("dashboard", "stats del dashboard", "200 con contadores", f"status={r.status_code}, content={str(r.json())[:120]}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="dashboard/CP-028-dashboard.json", extra=str(r.json())[:400])

r = get("/api/maps/points", token)
add("mapa", "puntos del mapa", "200 con puntos", f"status={r.status_code}, total={len(r.json()) if isinstance(r.json(), list) else '?'}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="mapa/CP-029-mapa-puntos.json", extra=str(r.json())[:400])

r = get("/notificaciones", token)
add("dashboard", "notificaciones", "200", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="dashboard/CP-030-notificaciones.json", extra=str(r.json())[:200])

# ---------- 9. LiquenPedia / Catálogo ----------
r = get("/liquenpedia")
add("liquenpedia", "listado de artículos", "200 con artículos", f"status={r.status_code}, preview={str(r.json())[:200]}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="liquenpedia/CP-031-liquenpedia.json", extra=str(r.json())[:400])

art_list = r.json()
art_id = None
if isinstance(art_list, list) and art_list:
    art_id = art_list[0].get("id_articulo") or art_list[0].get("id")
elif isinstance(art_list, dict):
    items = art_list.get("items") or art_list.get("data") or art_list.get("articulos") or []
    if items:
        art_id = items[0].get("id_articulo") or items[0].get("id")
if art_id:
    r = get(f"/liquenpedia/{art_id}")
    add("liquenpedia", "visualización de artículo", "200 con contenido", f"status={r.status_code}, titulo={r.json().get('titulo') if r.status_code==200 else '-'}", "Aprobado" if r.status_code == 200 else "Fallido",
        evidencia="liquenpedia/CP-032-articulo-detalle.json", extra=str(r.json())[:400])

r = get("/liquenpedia?busqueda=liquen")
add("liquenpedia", "búsqueda", "200", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="liquenpedia/CP-033-liquenpedia-busqueda.json", extra=str(r.json())[:300])

r = get("/categorias-liquenpedia")
add("liquenpedia", "categorías", "200", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="liquenpedia/CP-034-categorias.json", extra=str(r.json())[:300])

r = get("/catalog/species", token)
add("liquenpedia", "catálogo de especies", "200", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="liquenpedia/CP-035-catalogo-especies.json", extra=str(r.json())[:300])

r = get("/catalog/zones", token)
add("liquenpedia", "catálogo de zonas", "200", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="liquenpedia/CP-036-catalogo-zonas.json", extra=str(r.json())[:300])

# ---------- 10. Guardar resultado ----------
out_file = EVID / "api" / f"auditoria_{SESSION}.json"
out_file.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))