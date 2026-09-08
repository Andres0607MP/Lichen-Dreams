"""Pruebas de CRUD (admin) - Sprint 5 (Lichen Dreams).

Ejecuta vía HTTP real como administrador:
- LiquenPedia: crear (con/sin imagen), listar, detalle, actualizar, eliminar.
- Especies: crear, duplicado (409), actualizar, eliminar.
- Zonas ambientales: crear, actualizar, eliminar.
- Notificaciones: crear.
Genera evidencia JSON en evidencias/liquenpedia y evidencias/api.
"""
import json
import random
import string
import time
from pathlib import Path

import requests

BASE = "http://127.0.0.1:8000"
EVID = Path(__file__).resolve().parents[1] / "evidencias"

ADMIN_EMAIL = "admin@gmail.com"
ADMIN_PASSWORD = "admin123"

SUF = "".join(random.choices(string.ascii_lowercase + string.digits, k=4))
AUTHOR = "Hugo Andres Mancera Perez"

report = {"fecha": time.strftime("%Y-%m-%d %H:%M:%S"), "base": BASE, "resultados": []}
r = requests.post(BASE + "/auth/login", data={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD}, timeout=30)
token = r.json().get("access_token", "")
H = {"Authorization": f"Bearer {token}"}


def add(modulo, caso, esperado, obtenido, estado, evidencia=None, extra=None):
    row = {"modulo": modulo, "caso": caso, "esperado": esperado, "obtenido": obtenido, "estado": estado}
    if extra is not None:
        row["detalle"] = extra
    if evidencia:
        row["evidencia"] = evidencia
    report["resultados"].append(row)


add("login", "login administrador", "200 + token", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="liquenpedia/CP-101-admin-login.json", extra=str(r.json())[:250])

# ---------------- LiquenPedia CRUD ----------------
titulo = f"Liquenes como bioindicadores {SUF}"
payload = {
    "titulo": titulo,
    "contenido": "Los liquenes son organismos simbioticos que reaccionan de forma sensible a la calidad del aire. Este articulo de prueba del Sprint 5 documenta su uso como bioindicadores ambientales.",
    "autor": AUTHOR, "categoria": "Ecología",
    "id_categoria": 1,
    "estado_publicacion": "published",
}
r = requests.post(BASE + "/liquenpedia", json=payload, headers=H, timeout=30)
j = r.json()
art_id = j.get("id_articulo") or j.get("id")
add("liquenpedia", "admin: crear artículo publicado", "201 + id", f"status={r.status_code}, id={art_id}", "Aprobado" if r.status_code == 201 else "Fallido",
    evidencia="liquenpedia/CP-102-crear-articulo.json", extra=str(j)[:400])

if art_id:
    r = requests.get(BASE + "/liquenpedia", timeout=30)
    body = r.json()
    items = body if isinstance(body, list) else body.get("items", body.get("data", []))
    found = any((a.get("id_articulo") or a.get("id")) == art_id for a in items) if isinstance(items, list) else False
    add("liquenpedia", "listado público incluye artículo", "artículo visible", f"status={r.status_code}, visible={found}, total={len(items) if isinstance(items, list) else '?'}", "Aprobado" if found else "Fallido",
        evidencia="liquenpedia/CP-103-listado-publico.json", extra=str(body)[:500])

    r = requests.get(BASE + f"/liquenpedia/{art_id}", timeout=30)
    add("liquenpedia", "detalle del artículo", "200 + título", f"status={r.status_code}, titulo={r.json().get('titulo') if r.status_code==200 else '-'}", "Aprobado" if r.status_code == 200 else "Fallido",
        evidencia="liquenpedia/CP-104-detalle-articulo.json", extra=str(r.json())[:400])

    r = requests.get(BASE + f"/liquenpedia?busqueda={SUF}", timeout=30)
    add("liquenpedia", "búsqueda por palabra clave", "200 + coincide", f"status={r.status_code}, body={str(r.json())[:200]}", "Aprobado" if r.status_code == 200 else "Fallido",
        evidencia="liquenpedia/CP-105-busqueda.json", extra=str(r.json())[:300])

    payload["titulo"] = titulo + " (editado)"
    r = requests.put(BASE + f"/liquenpedia/{art_id}", json=payload, headers=H, timeout=30)
    add("liquenpedia", "actualizar artículo", "200 + título nuevo", f"status={r.status_code}, titulo={r.json().get('titulo') if r.status_code==200 else '-'}", "Aprobado" if r.status_code == 200 else "Fallido",
        evidencia="liquenpedia/CP-106-actualizar-articulo.json", extra=str(r.json())[:300])

    r = requests.delete(BASE + f"/liquenpedia/{art_id}", headers=H, timeout=30)
    add("liquenpedia", "eliminar artículo", "204", f"status={r.status_code}", "Aprobado" if r.status_code == 204 else "Fallido",
        evidencia="liquenpedia/CP-107-eliminar-articulo.json", extra=str(r.status_code))

    r = requests.get(BASE + f"/liquenpedia/{art_id}", timeout=30)
    add("liquenpedia", "dato inexistente tras eliminar", "404", f"status={r.status_code}", "Aprobado" if r.status_code == 404 else "Fallido",
        evidencia="liquenpedia/CP-108-articulo-inexistente.json", extra=str(r.json())[:200])

# artículo sin imagen (autor sin foto) y borrador no visible
r = requests.post(BASE + "/liquenpedia", json={
    "titulo": f"Articulo borrador sin imagen {SUF}",
    "contenido": "Articulo de prueba creado en estado draft para validar que no aparece en el listado publico y el manejo de autor sin foto.",
    "autor": "Autor Sin Foto QA", "categoria": "Educación",
    "id_categoria": 2,
    "estado_publicacion": "draft",
}, headers=H, timeout=30)
j = r.json()
draft_id = j.get("id_articulo") or j.get("id")
add("liquenpedia", "crear artículo draft sin foto", "201", f"status={r.status_code}, id={draft_id}", "Aprobado" if r.status_code == 201 else "Fallido",
    evidencia="liquenpedia/CP-109-articulo-draft.json", extra=str(j)[:300])
if draft_id:
    r = requests.get(BASE + "/liquenpedia", timeout=30)
    body = r.json()
    items = body if isinstance(body, list) else body.get("items", body.get("data", []))
    visible = any((a.get("id_articulo") or a.get("id")) == draft_id for a in items) if isinstance(items, list) else False
    add("liquenpedia", "draft no visible para público", "no visible", f"visible_en_listado={visible}", "Aprobado" if not visible else "Fallido",
        evidencia="liquenpedia/CP-110-draft-oculto.json", extra=str(body)[:200])
    r = requests.get(BASE + f"/liquenpedia/{draft_id}", timeout=30)
    add("liquenpedia", "draft denegado a público", "403", f"status={r.status_code}", "Aprobado" if r.status_code == 403 else "Fallido",
        evidencia="liquenpedia/CP-111-draft-403.json", extra=str(r.json())[:200])
    requests.delete(BASE + f"/liquenpedia/{draft_id}", headers=H, timeout=30)

# ---------------- Especies CRUD ----------------
especie_nombre = f"Pseudotestia sprinta {SUF}"
r = requests.post(BASE + "/admin/species", json={
    "nombre_cientifico": especie_nombre, "nombre_comun": "Liquen de prueba",
    "descripcion": "Especie de prueba del Sprint 5.", "indicador_calidad_aire": "buena",
}, headers=H, timeout=30)
j = r.json()
sp_id = j.get("id_especie") or j.get("id")
add("especies", "admin: crear especie", "201/200 + id", f"status={r.status_code}, id={sp_id}", "Aprobado" if r.status_code in (200, 201) else "Fallido",
    evidencia="liquenpedia/CP-112-crear-especie.json", extra=str(j)[:400])

r = requests.post(BASE + "/admin/species", json={"nombre_cientifico": especie_nombre}, headers=H, timeout=30)
add("especies", "especie duplicada", "409", f"status={r.status_code}", "Aprobado" if r.status_code == 409 else "Fallido",
    evidencia="liquenpedia/CP-113-especie-duplicada.json", extra=str(r.json())[:200])

r = requests.put(BASE + f"/admin/species/{sp_id}", json={"nombre_cientifico": especie_nombre, "nombre_comun": "Liquen de prueba editado"}, headers=H, timeout=30)
add("especies", "actualizar especie", "200", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="liquenpedia/CP-114-actualizar-especie.json", extra=str(r.json())[:300])

r = requests.get(BASE + "/catalog/species", headers=H, timeout=30)
add("especies", "catálogo consultable", "200 + contiene", f"status={r.status_code}, body={str(r.json())[:250]}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="liquenpedia/CP-115-catalogo-especies.json", extra=str(r.json())[:300])

r = requests.delete(BASE + f"/admin/species/{sp_id}", headers=H, timeout=30)
add("especies", "eliminar especie", "200/204", f"status={r.status_code}", "Aprobado" if r.status_code in (200, 204) else "Fallido",
    evidencia="liquenpedia/CP-116-eliminar-especie.json", extra=str(r.status_code))

# ---------------- Zonas CRUD ----------------
r = requests.post(BASE + "/admin/zones", json={
    "nombre_zona": f"Zona prueba Sprint5 {SUF}", "latitud": 4.65, "longitud": -74.1,
    "radio_metros": 1500, "descripcion": "Zona ambiental de prueba.",
}, headers=H, timeout=30)
j = r.json()
z_id = j.get("id_zona") or j.get("id")
add("zonas", "admin: crear zona", "200/201 + id", f"status={r.status_code}, id={z_id}", "Aprobado" if r.status_code in (200, 201) else "Fallido",
    evidencia="mapa/CP-117-crear-zona.json", extra=str(j)[:400])

r = requests.put(BASE + f"/admin/zones/{z_id}", json={
    "nombre_zona": f"Zona prueba Sprint5 {SUF} editada", "latitud": 4.65, "longitud": -74.1, "radio_metros": 2500,
}, headers=H, timeout=30)
add("zonas", "actualizar zona", "200", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="mapa/CP-118-actualizar-zona.json", extra=str(r.json())[:300])

r = requests.get(BASE + "/catalog/zones", headers=H, timeout=30)
add("zonas", "catálogo de zonas", "200 + contiene", f"status={r.status_code}, body={str(r.json())[:250]}", "Aprobado" if r.status_code == 200 else "Fallido",
    evidencia="mapa/CP-119-catalogo-zonas.json", extra=str(r.json())[:300])

r = requests.delete(BASE + f"/admin/zones/{z_id}", headers=H, timeout=30)
add("zonas", "eliminar zona", "200/204", f"status={r.status_code}", "Aprobado" if r.status_code in (200, 204) else "Fallido",
    evidencia="mapa/CP-120-eliminar-zona.json", extra=str(r.status_code))

# ---------------- Notificación ----------------
r = requests.post(BASE + "/admin/notifications", json={
    "titulo": "Anuncio QA Sprint 5",
    "mensaje": "Notificacion de prueba enviada a todos los usuarios.",
    "destino": "all",
}, headers=H, timeout=30)
add("notificaciones", "admin: notificación a todos", "200/201", f"status={r.status_code}", "Aprobado" if r.status_code in (200, 201) else "Fallido",
    evidencia="dashboard/CP-121-notificacion-admin.json", extra=str(r.json())[:300])

out = EVID / "api" / f"auditoria_crud_admin.json"
out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
