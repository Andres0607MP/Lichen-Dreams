"""Revisor visual manual de las 94 etiquetas criticas de Lichen Dreams.

Herramienta LOCAL de curacion manual. NO clasifica, NO modifica el dataset.
Sirve las imagenes originales en modo SOLO LECTURA y guarda las decisiones
humanas en `revision_94_resultados.csv`.

Uso:
    python ia/auditoria_2026/revisor_94.py            # inicia el servidor
    python ia/auditoria_2026/revisor_94.py --check    # solo valida y sale
    python ia/auditoria_2026/revisor_94.py --port 8700 --no-browser

Dependencias: solo la biblioteca estandar de Python (3.8+). Windows y Linux.
"""
import argparse
import csv
import json
import sys
import threading
import webbrowser
from datetime import datetime, UTC
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent.parent       # backend/
DATASETS = BASE / "ia" / "datasets"
AUDIT = Path(__file__).resolve().parent                    # ia/auditoria_2026/
CRITICAS = AUDIT / "revision_94_criticas.csv"
RESULTADOS = AUDIT / "revision_94_resultados.csv"

CLASE_FOLDER = {
    "saludable": DATASETS / "liquenes_saludables",
    "contaminado": DATASETS / "liquenes_contaminados",
    "desconocido": DATASETS / "liquenes_desconocidos",
}
EXT_MIME = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png",
            ".bmp": "image/bmp", ".webp": "image/webp", ".tif": "image/tiff", ".tiff": "image/tiff"}

DECISIONES = ("mantener", "cambiar_a_saludable", "cambiar_a_contaminado",
              "cambiar_a_desconocido", "dudoso")


# ---------------------------------------------------------------------------
# Carga y validacion
# ---------------------------------------------------------------------------
def registrar_error(msgs, texto):
    msgs.append(str(texto))
    print(f"[ERROR] {texto}")


def validar_criticas(rows):
    """Devuelve lista de errores de validacion (vacia si todo OK)."""
    errores = []
    if len(rows) != 94:
        registrar_error(errores, f"Se esperaban 94 filas, hay {len(rows)}")
    vistos = set()
    duplicados = set()
    for r in rows:
        archivo = r["archivo"].strip()
        if archivo in vistos:
            duplicados.add(archivo)
        vistos.add(archivo)
        clase = r["clase_actual"].strip()
        categoria = r["categoria"].strip()
        if clase not in CLASE_FOLDER:
            registrar_error(errores, f"clase_actual desconocida en {archivo}: {clase}")
            continue
        base = CLASE_FOLDER[clase]
        if clase == "desconocido":
            if categoria and categoria != "-":
                base = base / categoria
        ruta = base / archivo
        r["_ruta"] = ruta
        if not ruta.is_file():
            registrar_error(errores, f"Imagen no existe: {ruta}")
    if duplicados:
        registrar_error(errores, f"Archivos duplicados en la lista: {sorted(duplicados)}")
    return errores


def cargar_criticas():
    """Lee revision_94_criticas.csv, valida y ordena por prioridad 1..4."""
    if not CRITICAS.exists():
        raise FileNotFoundError(f"No existe {CRITICAS}. Ejecuta primero la generacion del CSV.")
    with open(CRITICAS, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    errores = validar_criticas(rows)
    if errores:
        print("\nExisten errores de validacion. Corrige el CSV o el dataset antes de revisar.")
        sys.exit(1)

    # orden de prioridad: P1 saludables, P2 lc, P3 lcp, P4 lcp_aug
    def tier(r):
        clase, cat = r["clase_actual"].strip(), r["categoria"].strip()
        if clase == "saludable":
            return 1
        if cat == "lc":
            return 2
        if cat == "lcp":
            return 3
        if cat == "lcp_aug":
            return 4
        return 5
    rows.sort(key=lambda r: (tier(r), r["archivo"]))
    for i, r in enumerate(rows, start=1):
        r["_idx"] = i
        r["_prioridad_n"] = tier(r)
    return rows


def estado_desde_csv():
    """Decisiones ya guardadas (si el CSV de resultados existe)."""
    estado = {}
    if RESULTADOS.exists():
        with open(RESULTADOS, encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                estado[r["archivo"]] = (r.get("decision_humana", ""), r.get("observaciones", ""))
    return estado


def escribir_resultados(rows, estado):
    """Conserva toda la informacion original y anade decision/observaciones."""
    fechas = {}
    if RESULTADOS.exists():
        with open(RESULTADOS, encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                fechas[r["archivo"]] = r.get("fecha_revision", "")
    with open(RESULTADOS, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["archivo", "clase_actual", "categoria", "motivo_auditoria",
                    "sugerencia_estadistica", "confianza_estadistica", "prioridad",
                    "decision_humana", "observaciones", "revisado", "fecha_revision"])
        for r in rows:
            decision, obs = estado.get(r["archivo"], ("", ""))
            w.writerow([r["archivo"], r["clase_actual"], r["categoria"],
                        r["motivo_auditoria"], r["sugerencia_estadistica"],
                        r["confianza_estadistica"], r["prioridad"],
                        decision, obs,
                        "si" if decision else "",
                        fechas.get(r["archivo"], "")])


# ---------------------------------------------------------------------------
# Servidor HTTP local (solo lectura del dataset)
# ---------------------------------------------------------------------------
class RevisorHandler(BaseHTTPRequestHandler):
    rows = []
    estado = {}

    def log_message(self, *a):
        pass

    def _json(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/img"):
            self._serve_image()
        elif self.path.startswith("/api/state"):
            self._serve_state()
        else:
            self._serve_index()

    def do_POST(self):
        if self.path.startswith("/api/save"):
            try:
                n = int(self.headers.get("Content-Length", "0"))
                data = json.loads(self.rfile.read(n).decode("utf-8"))
            except Exception as e:
                self._json({"ok": False, "error": f"json invalido: {e}"}, 400)
                return
            self._save_decision(data)
        else:
            self._json({"ok": False, "error": "ruta desconocida"}, 404)

    # -- paginas ------------------------------------------------------------
    def _serve_index(self):
        html = self._pagina_html()
        body = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_state(self):
        estado = estado_desde_csv()
        conteos = {d: 0 for d in DECISIONES}
        for archivo in (r["archivo"] for r in self.rows):
            d = estado.get(archivo, ("", ""))[0]
            if d:
                conteos[d] += 1
        revisadas = sum(conteos.values())
        self._json({
            "total": len(self.rows),
            "revisadas": revisadas,
            "pendientes": len(self.rows) - revisadas,
            "conteos": conteos,
            "estado": {a: estado.get(a, ("", ""))[0] for a in (r["archivo"] for r in self.rows)},
        })

    def _serve_image(self):
        from urllib.parse import urlparse, parse_qs
        q = parse_qs(urlparse(self.path).query)
        try:
            idx = int(q.get("i", ["-1"])[0]) - 1
            r = self.rows[idx]
        except (ValueError, IndexError):
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"imagen no encontrada")
            return
        ruta = Path(str(r["_ruta"]))
        if not ruta.is_file():
            self.send_response(404)
            self.end_headers()
            self.wfile.write(("no existe " + str(ruta)).encode("utf-8"))
            return
        mime = EXT_MIME.get(ruta.suffix.lower(), "application/octet-stream")
        try:
            with open(ruta, "rb") as f:
                data = f.read()
        except OSError as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode("utf-8"))
            return
        self.send_response(200)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _save_decision(self, data):
        idx = int(data.get("index", -1)) - 1
        try:
            rows = self.rows[idx]
        except (ValueError, IndexError):
            self._json({"ok": False, "error": "indice invalido"}, 400)
            return
        decision = str(data.get("decision", "")).strip()
        if decision and decision not in DECISIONES:
            self._json({"ok": False, "error": f"decision invalida: {decision}"}, 400)
            return
        obs = str(data.get("observaciones", "")).strip()
        archivo = rows["archivo"]
        self.estado[archivo] = (decision, obs)
        escribir_resultados(self.rows, self.estado)  # guardado inmediato
        self._json({"ok": True, "guardado": archivo, "decision": decision})

    # -- html ---------------------------------------------------------------
    def _pagina_html(self):
        estado = estado_desde_csv()
        cards = []
        for r in self.rows:
            decision, obs = estado.get(r["archivo"], ("", ""))
            cards.append({
                "i": r["_idx"],
                "archivo": r["archivo"],
                "clase": r["clase_actual"],
                "categoria": r["categoria"],
                "prioridad": r["prioridad"],
                "prioridad_n": r["_prioridad_n"],
                "motivo": r["motivo_auditoria"],
                "sugerencia": r["sugerencia_estadistica"],
                "confianza": r["confianza_estadistica"],
                "decision": decision,
                "obs": obs,
            })
        datos = json.dumps(cards, ensure_ascii=False)
        return HTML_TEMPLATE.replace("__DATOS__", datos)

    # -----------------------------------------------------------------------
    def version_string(self):
        return "revisor-94"


def main():
    ap = argparse.ArgumentParser(description="Revisor visual manual de 94 etiquetas criticas")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--no-browser", action="store_true")
    ap.add_argument("--check", action="store_true", help="valida y termina sin servir")
    args = ap.parse_args()

    print("=== REVISOR 94 — curacion manual de etiquetas ===")
    print("Cargando y validando revision_94_criticas.csv ...")
    rows = cargar_criticas()
    print(f"OK: {len(rows)} filas validas, 0 duplicados, todas las imagenes existen.")

    if args.check:
        print("Check OK: dataset no modificado, listo para revision.")
        print("Nota: revision_94_resultados.csv se creara la primera vez que se guarde una decision.")
        return

    RevisorHandler.rows = rows
    RevisorHandler.estado = estado_desde_csv()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), RevisorHandler)
    url = f"http://127.0.0.1:{args.port}"
    print(f"Servidor listo: {url}")
    print("El dataset solo se LEE. Las decisiones se guardan en:")
    print(f"  {RESULTADOS}")
    if not args.no_browser:
        threading.Timer(0.8, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nDetenido.")


HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Revisor 94 — Lichen Dreams</title>
<style>
:root { --fondo:#101418; --panel:#1b222b; --borde:#2c3946; --texto:#e6edf3;
        --dim:#9fb1c1; --ok:#2ea44f; --sal:#4caf7d; --cont:#c1892e; --desc:#8b94a3; --dud:#c05b3d; }
* { box-sizing:border-box; }
body { margin:0; font-family:Segoe UI, Roboto, Arial, sans-serif; background:var(--fondo); color:var(--texto); }
.top { position:sticky; top:0; background:var(--panel); border-bottom:1px solid var(--borde);
       padding:10px 18px; display:flex; align-items:center; gap:16px; flex-wrap:wrap; z-index:5; }
.top h1 { font-size:17px; margin:0; }
.chip { background:#26303b; border-radius:14px; padding:3px 10px; font-size:12px; }
.chip b { color:#fff; }
.nav-bar { display:flex; gap:8px; align-items:center; flex-wrap:wrap; }
button { background:#2b3848; color:var(--texto); border:1px solid var(--borde); border-radius:7px;
         padding:6px 14px; font-size:13px; cursor:pointer; }
button:hover { background:#35465c; }
button:disabled { opacity:.4; cursor:default; }
.grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(56px, 1fr)); gap:5px;
        padding:0 18px 10px; max-width:1200px; }
.sel { border:1px solid var(--borde); border-radius:5px; padding:4px 0; text-align:center;
       font-size:11px; cursor:pointer; background:#1b222b; }
.sel.rev { border-color:var(--ok); color:var(--ok); }
.sel.cur { outline:2px solid #7ab8f0; }
.sel.p1 { border-left:3px solid #e53e3e; } .sel.p2 { border-left:3px solid #e0a030; }
.sel.p3 { border-left:3px solid #8a6fd4; } .sel.p4 { border-left:3px solid #5fa8d3; }
.mid { display:flex; gap:18px; padding:0 18px 30px; max-width:1200px; flex-wrap:wrap; }
.card { background:var(--panel); border:1px solid var(--borde); border-radius:10px;
        padding:16px; flex:2 1 560px; min-width:360px; }
.card img { max-width:100%; max-height:560px; border-radius:8px; display:block; margin:0 auto 12px;
            background:#000; }
.meta { font-size:13px; line-height:1.65; }
.meta .k { color:var(--dim); }
.lbl { display:inline-block; border-radius:13px; padding:2px 12px; font-size:12px; font-weight:600; margin:2px 4px 2px 0; }
.lbl.saludable { background:#174d33; color:#7ce8ab; }
.lbl.contaminado { background:#5c3a0e; color:#f2c068; }
.lbl.desconocido { background:#333a44; color:#aab6c2; }
.lbl.aug { background:#2a3b52; color:#9fd0f0; }
.form { flex:1 1 300px; min-width:280px; }
.dec { display:flex; flex-direction:column; gap:8px; }
.dec label { border:1px solid var(--borde); border-radius:7px; padding:9px 12px; cursor:pointer;
             font-size:14px; display:flex; gap:10px; align-items:center; background:#1b222b; }
.dec label input { accent-color:var(--ok); }
textarea { width:100%; min-height:90px; margin-top:10px; background:#141b23; color:var(--texto);
           border:1px solid var(--borde); border-radius:7px; padding:8px; font-family:inherit; }
.save-msg { color:var(--ok); font-size:12px; margin-top:6px; min-height:16px; }
.hint { color:var(--dim); font-size:12px; margin-top:8px; line-height:1.5; }
.aug-warn { border:1px solid #c0742e; background:#3a2a12; color:#ffd9a6; border-radius:7px;
            padding:8px 10px; font-size:12px; margin-top:8px; }
</style>
</head>
<body>
<div class="top">
  <h1>Revisor 94 — Lichen Dreams</h1>
  <div class="nav-bar">
    <button id="btnPrimero">«</button>
    <button id="btnAnterior">‹</button>
    <span id="lblPos">1 / 94</span>
    <button id="btnSiguiente">›</button>
    <button id="btnUltimo">»</button>
    <button id="btnAuto">autoguardado: SÍ</button>
    <span class="chip">Revisadas: <b id="cRev">0</b> / <span id="cTot">94</span></span>
    <span class="chip">Pendientes: <b id="cPen">94</b></span>
  </div>
</div>
<div class="grid" id="miniGrid"></div>
<div class="mid">
  <div class="card">
    <img id="imgGrande" alt="imagen" src="">
    <div class="meta" id="meta"></div>
    <div id="augWarn"></div>
  </div>
  <div class="form">
    <h3>Decisión humana</h3>
    <div class="dec" id="deciones"></div>
    <textarea id="obs" placeholder="Observaciones (motivo de la decision)..."></textarea>
    <button id="btnGuardar" style="margin-top:10px;width:100%">Guardar decisión</button>
    <div class="save-msg" id="saveMsg"></div>
    <div class="hint" id="hint"></div>
  </div>
</div>
<script>
const DATOS = __DATOS__;
let i = 0;
let guardado = true;

const $ = id => document.getElementById(id);

function selHTML(s) {
  return `<div class="sel ${s.decision ? 'rev' : ''} p${s.prioridad_n}" data-i="${s.i}">${s.i}</div>`;
}
function rellenarGrid() {
  $("miniGrid").innerHTML = DATOS.map(selHTML).join("");
  [...document.querySelectorAll(".sel")].forEach(e => e.onclick = () => irA(+e.dataset.i));
}
function marcarActual() {
  [...document.querySelectorAll(".sel")].forEach(e => e.classList.remove("cur"));
  const el = document.querySelector(`.sel[data-i="${i}"]`);
  if (el) el.classList.add("cur");
}
function cargarEstado() {
  fetch("/api/state").then(r => r.json()).then(s => {
    $("cRev").textContent = s.revisadas;
    $("cPen").textContent = s.pendientes;
    $("cTot").textContent = s.total;
    [...document.querySelectorAll(".sel")].forEach(e => {
      const d = s.estado[DATOS[+e.dataset.i - 1].archivo];
      e.classList.toggle("rev", !!d);
    });
  });
}
function mostrar() {
  const d = DATOS[i - 1];
  $("lblPos").textContent = `${i} / ${DATOS.length}`;
  $("imgGrande").src = `/img?i=${i}`;
  $("imgGrande").alt = d.archivo;
  $("meta").innerHTML = `
    <div><span class="k">Archivo:</span> <b>${d.archivo}</b></div>
    <div><span class="k">Clase actual:</span> <span class="lbl ${d.clase==='contaminado'?'contaminado':d.clase==='saludable'?'saludable':'desconocido'}">${d.clase.toUpperCase()}</span></div>
    <div><span class="k">Categoría/origen:</span> ${d.categoria || '-'}</div>
    <div><span class="k">Prioridad:</span> ${d.prioridad} (grupo ${d.prioridad_n})</div>
    <div><span class="k">Motivo auditoría:</span> ${d.motivo}</div>
    <div><span class="k">Sugerencia estadística:</span> <b>${d.sugerencia}</b> <span class="k">(confianza ${d.confianza})</span></div>`;
  const aug = document.getElementById("augWarn");
  aug.innerHTML = d.categoria === 'lcp_aug'
    ? `<div class="aug-warn">AUMENTADA — NO REPRESENTA NUEVA DIVERSIDAD BIOLÓGICA.<br>Decide basándote en su imagen fuente/original.</div>` : '';
  const decs = ["mantener","cambiar_a_saludable","cambiar_a_contaminado","cambiar_a_desconocido","dudoso"];
  $("deciones").innerHTML = decs.map(x => {
    const chk = d.decision === x ? 'checked' : '';
    return `<label><input type="radio" name="dec" value="${x}" ${chk}> <span>${x}</span></label>`;
  }).join("");
  $("obs").value = d.obs || "";
  $("saveMsg").textContent = d.decision ? `Guardado: ${d.decision}` : "";
  $("hint").textContent = d.clase === 'saludable'
    ? "¿Parece un liquen sano/vivo? Si presenta deterioro/marcas cafés del PROPIO liquen → cambiar_a_contaminado. Si no parece liquen → cambiar_a_desconocido. Duda → dudoso."
    : "¿Parece un liquen realmente deteriorado/contaminado? Si se ve sano → cambiar_a_saludable. Si no parece liquen → cambiar_a_desconocido. El marrón del fondo NO cuenta. Duda → dudoso.";
  marcarActual();
  guardado = true;
}
function guardar(next) {
  const d = DATOS[i - 1];
  const dec = document.querySelector('input[name="dec"]:checked');
  const decision = dec ? dec.value : "";
  const obs = $("obs").value.trim();
  fetch("/api/save", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({index: i, decision, observaciones: obs})
  }).then(r => r.json()).then(res => {
    if (res.ok) {
      d.decision = decision;
      d.obs = obs;
      guardado = true;
      $("saveMsg").textContent = `Guardado: ${decision || '(vacío)'}`;
      cargarEstado();
    } else {
      $("saveMsg").textContent = "ERROR: " + res.error;
    }
  });
}
function irA(n) {
  if (!guardado) guardar(false);
  i = Math.max(1, Math.min(DATOS.length, n));
  mostrar();
}
document.addEventListener("DOMContentLoaded", () => {
  rellenarGrid();
  mostrar();
  cargarEstado();
  $("btnPrimero").onclick = () => irA(1);
  $("btnAnterior").onclick = () => irA(i - 1);
  $("btnSiguiente").onclick = () => irA(i + 1);
  $("btnUltimo").onclick = () => irA(DATOS.length);
  $("btnGuardar").onclick = () => guardar(false);
  document.addEventListener("keydown", e => {
    if (e.key === "ArrowRight") irA(i + 1);
    if (e.key === "ArrowLeft") irA(i - 1);
  });
  $("deciones").addEventListener("change", () => { guardado = false; guardar(false); });
  $("obs").addEventListener("change", () => { guardado = false; guardar(false); });
});
</script>
</body>
</html>
"""


if __name__ == "__main__":
    main()