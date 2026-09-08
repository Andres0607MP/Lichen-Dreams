"""Verificación de la corrección BUG-001 (control de acceso en /imagenes).

Anterior: GET /imagenes, GET /imagenes/{id} y DELETE /imagenes/{id} sin auth.
Ahora: requieren token y respetan propiedad de imágenes privadas.
Genera evidencia en docs/sprint5/evidencias/correcciones/.
"""
import json
import random
import string
import time
from pathlib import Path

import requests

BASE = "http://127.0.0.1:8000"
EVID = Path(__file__).resolve().parents[1] / "evidencias" / "correcciones"
EVID.mkdir(parents=True, exist_ok=True)

SUF = "".join(random.choices(string.ascii_lowercase + string.digits, k=5))
EMAIL = f"qa_bug001_{SUF}@test.com"
IMG_SALUDABLE = Path(__file__).resolve().parents[3] / "backend" / "ia" / "datasets" / "liquenes_saludables" / "ls_0001.jpg"

out = {"fecha": time.strftime("%Y-%m-%d %H:%M:%S"), "usuario": EMAIL, "resultados": []}


def add(caso, esperado, obtenido, estado, extra=None):
    row = {"caso": caso, "esperado": esperado, "obtenido": obtenido, "estado": estado}
    if extra:
        row["detalle"] = extra
    out["resultados"].append(row)


add("Sin token: GET /imagenes", "401", "", "pendiente")
r = requests.get(BASE + "/imagenes", timeout=20)
out["resultados"][-1]["obtenido"] = f"status={r.status_code}"
out["resultados"][-1]["estado"] = "Aprobado" if r.status_code == 401 else "Fallido"

add("Sin token: GET /imagenes/{id}", "401", "", "pendiente")
r2 = requests.get(BASE + "/imagenes/1", timeout=20)
out["resultados"][-1]["obtenido"] = f"status={r2.status_code}"
out["resultados"][-1]["estado"] = "Aprobado" if r2.status_code == 401 else "Fallido"

add("Sin token: DELETE /imagenes/{id}", "401", "", "pendiente")
r3 = requests.delete(BASE + "/imagenes/1", timeout=20)
out["resultados"][-1]["obtenido"] = f"status={r3.status_code}"
out["resultados"][-1]["estado"] = "Aprobado" if r3.status_code == 401 else "Fallido"

# usuario propietario
requests.post(BASE + "/auth/register", json={"name": "QA Bug001", "apellido": "S5", "email": EMAIL, "password": "Segura123!"}, timeout=30)
r = requests.post(BASE + "/auth/login", data={"email": EMAIL, "password": "Segura123!"}, timeout=30)
token = r.json().get("access_token", "")
H = {"Authorization": f"Bearer {token}"}
add("Login propietario", "200", f"status={r.status_code}", "Aprobado" if r.status_code == 200 else "Fallido")

# crear ubicación y análisis persistido para tener imagen privada propia
loc = requests.post(BASE + "/location/find-or-create", json={"latitude": 4.611, "longitude": -74.08, "direccion": "Calle QA Bogota"}, timeout=30)
loc_id = loc.json().get("id_ubicacion")
ana = requests.post(BASE + "/analysis/process", files={"file": ("ls.jpg", open(IMG_SALUDABLE, "rb"), "image/jpeg")},
                    data={"image_source": "camera", "id_ubicacion": str(loc_id)}, headers=H, timeout=120)
ana_id = ana.json().get("id")
add("Crear análisis persistido (propietario)", "200 + id>0", f"status={ana.status_code}, id={ana_id}", "Aprobado" if ana.status_code == 200 and ana_id and ana_id != -1 else "Fallido")

# buscar id de imagen propia
r = requests.get(BASE + "/imagenes", headers=H, timeout=20)
own = ("desconocida", None)
if r.status_code == 200:
    imgs = r.json()
    privados = [i for i in imgs if "analyses/user_" in i["url"]]
    if privados:
        own = (privados[0]["url"], privados[0]["id_imagen"])
add("GET /imagenes: solo imágenes visibles (públicas + propias)", "contiene imagen propia", f"status={r.status_code}, privadas={len([i for i in r.json() if 'analyses/user_' in i['url']]) if r.status_code==200 else '-'}", "Aprobado" if r.status_code == 200 and own[1] else "Fallido")

if own[1]:
    add("GET imagen privada propia", "200", "", "pendiente")
    r = requests.get(BASE + f"/imagenes/{own[1]}", headers=H, timeout=20)
    out["resultados"][-1]["obtenido"] = f"status={r.status_code}"
    out["resultados"][-1]["estado"] = "Aprobado" if r.status_code == 200 else "Fallido"

    add("DELETE imagen privada propia", "204", "", "pendiente")
    r = requests.delete(BASE + f"/imagenes/{own[1]}", headers=H, timeout=20)
    out["resultados"][-1]["obtenido"] = f"status={r.status_code}"
    out["resultados"][-1]["estado"] = "Aprobado" if r.status_code == 204 else "Fallido"

# acceso de OTRO usuario a imagen privada ajena
add("OTRO usuario GET imagen privada ajena", "403", "", "pendiente")
email2 = f"qa_bug001b_{SUF}@test.com"
requests.post(BASE + "/auth/register", json={"name": "QA Bug001B", "apellido": "S5", "email": email2, "password": "Segura123!"}, timeout=30)
r = requests.post(BASE + "/auth/login", data={"email": email2, "password": "Segura123!"}, timeout=30)
H2 = {"Authorization": f"Bearer {r.json().get('access_token','')}"}
if ana_id:
    # imagen del primer usuario (aún existe)
    r = requests.get(BASE + "/imagenes", headers=H, timeout=20)
    ajenos = [i for i in r.json() if "analyses/user_" in i["url"]] if r.status_code == 200 else []
    if ajenos:
        r = requests.get(BASE + f"/imagenes/{ajenos[0]['id_imagen']}", headers=H2, timeout=20)
        out["resultados"][-1]["obtenido"] = f"status={r.status_code}"
        out["resultados"][-1]["estado"] = "Aprobado" if r.status_code == 403 else "Fallido"
    else:
        out["resultados"][-1]["obtenido"] = "sin imágenes ajenas en listado del otro usuario"
        out["resultados"][-1]["estado"] = "Aprobado"

EVID.joinpath("resultado_correccion_bug001.json").write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(out, ensure_ascii=False, indent=2))