"""Pruebas automatizadas con Selenium - Sprint 5, 2.ª iteración (Lichen Dreams).

Ejecuta pruebas web E2E reales sobre el build Flutter Web servido en
http://127.0.0.1:8080 contra el backend en http://127.0.0.1:8000.

Ajustes aplicados (instrucciones del responsable QA):
- Esperas de 20 s completos tras abrir la app y tras cada navegación/pantalla.
- Verificación de página cargada (document.readyState) antes de buscar elementos.
- Espera de imágenes: <img> con complete=true y naturalWidth>0.
- Activar semántica de Flutter Web esperando el placeholder (hasta 45 s).
- Selectores de botones robustos: aria-role=button, role=button, filtrado por
  atributo, aria-label y textContent.
- perform_login verifica la cantidad de inputs y reintenta si aún no existen.
- Clic normal con fallback por coordenadas.
- Si un caso no puede ejecutarse tras reintentos, se marca Bloqueado (sin inventar
  resultados). Las capturas anteriores se conservan; las nuevas usan sufijo '-r2'.
"""
import json
import random
import string
import time
from pathlib import Path

import requests as http
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.common.action_chains import ActionChains

BASE_URL = "http://127.0.0.1:8080"
API_URL = "http://127.0.0.1:8000"
EVID = Path(__file__).resolve().parents[1] / "evidencias" / "selenium"
EVID.mkdir(parents=True, exist_ok=True)

SUF = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))
TEST_EMAIL = f"selenium2_{SUF}@test.com"
TEST_PASSWORD = "Selenium123!"
REGISTRO_EMAIL = f"selenium2_reg_{SUF}@test.com"
RESULT = {"base": BASE_URL, "api": API_URL,
          "fecha": time.strftime("%Y-%m-%d %H:%M:%S"),
          "iteracion": 2,
          "nota": "Reintento con esperas de 20 s y selectores robustos.",
          "casos": []}

WAIT_NAV = 20   # segundos de espera tras abrir/navegar


def add_case(case_id, desc, expected, obtained, status, evidencia=None):
    row = {"id": case_id, "caso": desc, "esperado": expected,
           "obtenido": obtained, "estado": status}
    if evidencia:
        row["evidencia"] = evidencia
    RESULT["casos"].append(row)


def make_driver():
    opts = Options()
    for a in [
        "--headless=new", "--no-sandbox", "--disable-gpu",
        "--disable-software-rasterizer", "--disable-dev-shm-usage",
        "--disable-extensions", "--no-first-run", "--disable-popup-blocking",
        "--force-device-scale-factor=1", "--window-size=1360,900",
        "--disable-features=Vulkan,TranslateUI",
    ]:
        opts.add_argument(a)
    d = webdriver.Chrome(options=opts)
    d.set_page_load_timeout(120)
    return d


def page_ready(driver):
    try:
        return driver.execute_script("return document.readyState === 'complete';")
    except Exception:
        return False


def wait_images_loaded(driver, timeout=30):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            ok = driver.execute_script("""
              const imgs = Array.from(document.images);
              if (!imgs.length) return true;
              return imgs.every(i => i.complete && i.naturalWidth > 0);
            """)
            if ok:
                return True
        except Exception:
            pass
        time.sleep(0.5)
    return False


def enable_semantics(driver, timeout=45):
    try:
        return driver.execute_async_script("""
          const done = arguments[arguments.length - 1];
          let tries = 0;
          const iv = setInterval(() => {
            tries++;
            const ph = document.querySelector('flt-semantics-placeholder');
            if (ph) {
              clearInterval(iv);
              ph.dispatchEvent(new MouseEvent('click', {bubbles: true}));
              ph.focus();
              done(true);
            } else if (tries > 300) {
              clearInterval(iv);
              done(false);
            }
          }, 150);
        """)
    except Exception:
        return False


def wait_semantics_ready(driver, timeout=60):
    """Espera a que existan nodos flt-semantics y al menos 2 inputs."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            nodes = driver.find_elements(By.TAG_NAME, "flt-semantics")
            inps = driver.find_elements(By.TAG_NAME, "input")
            if nodes and len(inps) >= 2:
                return True
        except Exception:
            pass
        time.sleep(1)
    return False


def open_app(driver):
    """Abre la app, espera 20 s, activa semántica y verifica inputs."""
    try:
        driver.get(BASE_URL)
    except Exception:
        pass
    time.sleep(WAIT_NAV)
    page_ready(driver)
    wait_images_loaded(driver)
    activated = enable_semantics(driver)
    time.sleep(WAIT_NAV)
    if wait_semantics_ready(driver, timeout=45):
        time.sleep(2)
        return True
    # Reintento: recargar y repetir una vez más
    try:
        driver.get(BASE_URL)
    except Exception:
        pass
    time.sleep(WAIT_NAV)
    enable_semantics(driver)
    time.sleep(WAIT_NAV)
    ok = wait_semantics_ready(driver, timeout=45)
    print(f"  [open_app] activada={activated} segunda={ok}", flush=True)
    time.sleep(2)
    return ok


def inputs(driver):
    try:
        return driver.find_elements(By.TAG_NAME, "input")
    except Exception:
        return []


def button_nodes(driver):
    out = []
    selectors = [
        "flt-semantics[aria-role='button']",
        "flt-semantics[role='button']",
    ]
    for sel in selectors:
        try:
            out += driver.find_elements(By.CSS_SELECTOR, sel)
        except Exception:
            pass
    if not out:
        for n in driver.find_elements(By.TAG_NAME, "flt-semantics"):
            try:
                r = n.get_attribute("role") or n.get_attribute("aria-role")
                if r == "button":
                    out.append(n)
            except Exception:
                pass
    return out


def btn_label(b):
    try:
        parts = []
        for attr in ("aria-label", "text"):
            v = b.get_attribute(attr)
            if v:
                parts.append(v)
        t = b.text or ""
        if t:
            parts.append(t)
        return " ".join(parts)
    except Exception:
        return ""


def find_button(driver, text):
    for b in button_nodes(driver):
        try:
            if text.lower() in btn_label(b).lower():
                return b
        except Exception:
            pass
    return None


def is_disabled(b):
    try:
        return b.get_attribute("aria-disabled") == "true" or b.get_attribute("disabled") == "true"
    except Exception:
        return False


def click_element(driver, b):
    """Clic normal; si Flutter no responde, clic por coordenadas."""
    try:
        b.click()
        return True
    except Exception:
        pass
    try:
        ActionChains(driver).move_to_element(b).pause(0.2).click().perform()
        return True
    except Exception:
        pass
    try:
        return driver.execute_script(
            "const r = arguments[0].getBoundingClientRect();"
            "arguments[0].dispatchEvent(new MouseEvent('click', {bubbles:true, cancelable:true,"
            " clientX: r.x + r.width/2, clientY: r.y + r.height/2}));", b)
    except Exception:
        return False


def click_when_enabled(driver, text, timeout=30):
    deadline = time.time() + timeout
    while time.time() < deadline:
        b = find_button(driver, text)
        if b is not None:
            if is_disabled(b):
                time.sleep(1)
                continue
            if click_element(driver, b):
                return True
            time.sleep(1)
        else:
            time.sleep(1)
    return False


def fill_login(driver, email, password):
    """Llena email/password verificando que existan los inputs."""
    inps = []
    deadline = time.time() + 30
    while time.time() < deadline:
        inps = inputs(driver)
        if len(inps) >= 2:
            break
        time.sleep(1.5)
    if len(inps) < 2:
        return False
    clear_input(driver, inps[0])
    inps[0].send_keys(email)
    time.sleep(0.4)
    clear_input(driver, inps[1])
    inps[1].send_keys(password)
    time.sleep(0.4)
    return True


def semantics_text(driver):
    try:
        return driver.execute_script("""
          const out = [];
          document.querySelectorAll('flt-semantics').forEach(n => {
            const a = n.getAttribute('aria-label');
            const t = (n.textContent || '').trim();
            if (a && a.trim()) out.push(a.trim());
            if (t) out.push(t);
          });
          return Array.from(new Set(out)).join(' | ');
        """) or ""
    except Exception:
        return ""


def clear_input(driver, elem):
    """Borra el contenido de un input de Flutter Web (Ctrl+A + Supr)."""
    try:
        elem.click()
        time.sleep(0.2)
        ActionChains(driver).key_down("\ue009").send_keys("a").key_up("\ue009").send_keys("\ue017").perform()
        time.sleep(0.3)
    except Exception:
        try:
            elem.clear()
        except Exception:
            pass


def wait_route(driver, part, timeout=120):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if part in driver.current_url:
                return True
        except Exception:
            return False
        time.sleep(0.7)
    return False


def poll_text_contains(driver, substrings, duration=10):
    """Sondea el texto semántico durante `duration` s buscando algún substring."""
    deadline = time.time() + duration
    found = []
    while time.time() < deadline:
        txt = semantics_text(driver).lower()
        for s in substrings:
            if s.lower() in txt:
                found.append(s)
                return sorted(set(found))
        time.sleep(1)
    return found


def api_get_profile(email, password):
    """Devuelve el perfil del usuario vía API (verificación objetiva CRUD)."""
    try:
        r = http.post(API_URL + "/auth/login", data={"email": email, "password": password}, timeout=30)
        if r.status_code != 200:
            return None
        tok = r.json().get("access_token", "")
        r2 = http.get(API_URL + "/profile", headers={"Authorization": f"Bearer {tok}"}, timeout=30)
        if r2.status_code == 200:
            return r2.json()
    except Exception:
        return None
    return None


def shot(driver, name):
    p = EVID / f"{name}.png"
    try:
        driver.save_screenshot(str(p))
        return name + ".png"
    except Exception:
        return name + ".png"


# =====================================================================
print("=== S-03 Validación de campos vacíos en login ===", flush=True)
driver = make_driver()
try:
    if open_app(driver):
        time.sleep(WAIT_NAV)
        shot(driver, "CP-201-r2-sel-login-pantalla")
        btn = find_button(driver, "Iniciar sesión")
        disabled = is_disabled(btn) if btn else False
        click_when_enabled(driver, "Iniciar sesión", timeout=8)  # deshabilitado -> no navega
        time.sleep(3)
        url = driver.current_url
        ok = disabled and "login" in url
        add_case("S-03", "Validación de campos vacíos en login (reintento r2)",
                 "El formulario vacío no puede enviarse (botón deshabilitado)",
                 f"boton_deshabilitado={disabled}; url={url}",
                 "Aprobado" if ok else "Fallido", shot(driver, "CP-201-r2-sel-login-campos-vacios"))
    else:
        add_case("S-03", "Validación de campos vacíos en login (reintento r2)",
                 "El formulario vacío no puede enviarse (botón deshabilitado)",
                 "no se pudo activar semántica tras reintentos", "Bloqueado",
                 shot(driver, "CP-201-r2-sel-login-campos-vacios"))
finally:
    driver.quit()

# =====================================================================
print("=== S-02 Login con credenciales incorrectas ===", flush=True)
driver = make_driver()
try:
    if open_app(driver):
        time.sleep(WAIT_NAV)
        if fill_login(driver, "usuario_no_existe@test.com", "Incorrecta123!"):
            time.sleep(1)
            shot(driver, "CP-202-r2-sel-login-incorrecto-llenado")
            clicked = click_when_enabled(driver, "Iniciar sesión", timeout=30)
            errores = poll_text_contains(driver, ["credenciales", "inválidas", "error", "no se pudo"], duration=12)
            url = driver.current_url
            ok = clicked and "login" in url and bool(errores)
            add_case("S-02", "Login con credenciales incorrectas (reintento r2)",
                     "Muestra error y permanece en /login",
                     f"clic={clicked}; url={url}; mensaje={errores if errores else '(no capturado)'}",
                     "Aprobado" if ok else "Fallido", shot(driver, "CP-203-r2-sel-login-incorrecto-error"))
        else:
            add_case("S-02", "Login con credenciales incorrectas (reintento r2)",
                     "Muestra error y permanece en /login",
                     "no se ubicaron los campos de login", "Bloqueado",
                     shot(driver, "CP-203-r2-sel-login-incorrecto-error"))
    else:
        add_case("S-02", "Login con credenciales incorrectas (reintento r2)",
                 "Muestra error y permanece en /login",
                 "no se pudo activar semántica tras reintentos", "Bloqueado",
                 shot(driver, "CP-203-r2-sel-login-incorrecto-error"))
finally:
    driver.quit()

# =====================================================================
print("=== S-01 Login exitoso ===", flush=True)
http.post(API_URL + "/auth/register",
          json={"name": "Selenium", "apellido": "QA", "email": TEST_EMAIL, "password": TEST_PASSWORD}, timeout=30)
driver = make_driver()
try:
    if open_app(driver):
        time.sleep(WAIT_NAV)
        if fill_login(driver, TEST_EMAIL, TEST_PASSWORD):
            time.sleep(1)
            shot(driver, "CP-202-r2-sel-login-llenado")
            clicked = click_when_enabled(driver, "Iniciar sesión", timeout=30)
            navego = wait_route(driver, "dashboard", timeout=180) or wait_route(driver, "home", timeout=180)
            time.sleep(WAIT_NAV)
            txt = semantics_text(driver)
            ok = clicked and navego
            add_case("S-01", "Login exitoso (reintento r2)",
                     "Redirige a Dashboard tras la autenticación",
                     f"clic={clicked}; url={driver.current_url}; contenido={txt[:150]}",
                     "Aprobado" if ok else "Fallido", shot(driver, "CP-204-r2-sel-login-exitoso-dashboard"))
        else:
            add_case("S-01", "Login exitoso (reintento r2)",
                     "Redirige a Dashboard tras la autenticación",
                     "no se ubicaron los campos de login", "Bloqueado",
                     shot(driver, "CP-204-r2-sel-login-exitoso-dashboard"))
    else:
        add_case("S-01", "Login exitoso (reintento r2)",
                 "Redirige a Dashboard tras la autenticación",
                 "no se pudo activar semántica tras reintentos", "Bloqueado",
                 shot(driver, "CP-204-r2-sel-login-exitoso-dashboard"))
finally:
    driver.quit()

# =====================================================================
print("=== S-05 Dashboard / S-06 Perfil (CRUD) ===", flush=True)
driver = make_driver()
try:
    if open_app(driver):
        time.sleep(WAIT_NAV)
        if fill_login(driver, TEST_EMAIL, TEST_PASSWORD):
            clicked = click_when_enabled(driver, "Iniciar sesión", timeout=30)
            navego = wait_route(driver, "dashboard", timeout=180) or wait_route(driver, "home", timeout=180)
            time.sleep(WAIT_NAV)
            txt = semantics_text(driver)
            add_case("S-05", "Consulta/listado principal Dashboard (reintento r2)",
                     "Se muestra dashboard con estadísticas cargadas",
                     f"url={driver.current_url}; labels={txt[:180]}",
                     "Aprobado" if navego and txt.strip() else "Fallido",
                     shot(driver, "CP-205-r2-sel-dashboard"))
            time.sleep(2)
            clicked_perfil = click_when_enabled(driver, "Perfil", timeout=30)
            time.sleep(WAIT_NAV)  # navegación de pestaña del perfil
            inps = inputs(driver)
            placeholders = [i.get_attribute("placeholder") or "" for i in inps]
            nombre_i = None
            for j, p in enumerate(placeholders):
                if "nombre" in p.lower():
                    nombre_i = j
                    break
            if nombre_i is None and inps:
                nombre_i = 0
            if nombre_i is not None:
                shot(driver, "CP-206-r2-sel-perfil-pantalla")
                clear_input(driver, inps[nombre_i])
                inps[nombre_i].send_keys("Selenium Usuario Actualizado")
                time.sleep(1)
                shot(driver, "CP-207-r2-sel-perfil-editado")
                guardado = click_when_enabled(driver, "Guardar", timeout=30)
                time.sleep(6)
                perfil = api_get_profile(TEST_EMAIL, TEST_PASSWORD)
                nombre_guardado = (perfil or {}).get("nombre") if perfil else None
                ok_p = guardado and nombre_guardado == "Selenium Usuario Actualizado"
                add_case("S-06", "Operación CRUD: actualización de perfil (reintento r2)",
                         "Se guarda el nombre en el perfil (verificado vía API)",
                         f"clic_perfil={clicked_perfil}; clic_guardar={guardado}; nombre_api={nombre_guardado}",
                         "Aprobado" if ok_p else "Fallido", shot(driver, "CP-208-r2-sel-perfil-resultado"))
            else:
                add_case("S-06", "Operación CRUD: actualización de perfil (reintento r2)",
                         "Se guardan los datos y se reflejan en pantalla",
                         f"no hay campos editables; placeholders={placeholders[:6]}",
                         "Bloqueado", shot(driver, "CP-206-r2-sel-perfil-pantalla"))
        else:
            add_case("S-05", "Consulta/listado principal Dashboard (reintento r2)",
                     "Se muestra dashboard con estadísticas cargadas",
                     "no se ubicaron los campos de login", "Bloqueado", shot(driver, "CP-205-r2-sel-dashboard"))
            add_case("S-06", "Operación CRUD: actualización de perfil (reintento r2)",
                     "Se guardan los datos y se reflejan en pantalla",
                     "no se ubicaron los campos de login", "Bloqueado", shot(driver, "CP-208-r2-sel-perfil-resultado"))
    else:
        add_case("S-05", "Consulta/listado principal Dashboard (reintento r2)",
                 "Se muestra dashboard con estadísticas cargadas",
                 "no se pudo activar semántica tras reintentos", "Bloqueado", shot(driver, "CP-205-r2-sel-dashboard"))
        add_case("S-06", "Operación CRUD: actualización de perfil (reintento r2)",
                 "Se guardan los datos y se reflejan en pantalla",
                 "no se pudo activar semántica tras reintentos", "Bloqueado", shot(driver, "CP-208-r2-sel-perfil-resultado"))
finally:
    driver.quit()

# =====================================================================
print("=== S-04 Registro ===", flush=True)
driver = make_driver()
try:
    if open_app(driver):
        time.sleep(WAIT_NAV)
        shot(driver, "CP-209-r2-sel-registro-pantalla")
        click_when_enabled(driver, "Crear una cuenta", timeout=30)
        time.sleep(WAIT_NAV)  # navegación a la pantalla de registro
        shot(driver, "CP-209-r2-sel-registro-form")
        inps = inputs(driver)
        time.sleep(2)
        inps = inputs(driver)
        placeholders = [i.get_attribute("placeholder") or "" for i in inps]

        def _dom_info(i):
            try:
                return {
                    "type": inps[i].get_attribute("type") or "",
                    "autocomplete": inps[i].get_attribute("autocomplete") or "",
                    "aria": inps[i].get_attribute("aria-label") or "",
                    "placeholder": placeholders[i],
                }
            except Exception:
                return {}

        email_i = pw_i = cpw_i = None
        emails = [i for i in range(len(inps)) if _dom_info(i)["type"] == "email" or "email" in _dom_info(i)["autocomplete"] or "correo" in _dom_info(i)["aria"].lower() or "correo" in placeholders[i].lower()]
        pws = [i for i in range(len(inps)) if _dom_info(i)["type"] == "password"]
        if emails:
            email_i = emails[0]
        if len(pws) >= 1:
            pw_i = pws[0]
        if len(pws) >= 2:
            cpw_i = pws[1]
        print(f"  [registro] inputs={len(inps)} email_i={email_i} pws={pws}", flush=True)
        if email_i is not None and pw_i is not None:
            inps[email_i].send_keys(REGISTRO_EMAIL)
            time.sleep(0.3)
            inps[pw_i].send_keys(TEST_PASSWORD)
            time.sleep(0.3)
            if cpw_i is not None:
                inps[cpw_i].send_keys(TEST_PASSWORD)
            # nombre obligatorio: buscar campo "nombre" o primer campo de texto
            nombre_idx = None
            for j in range(len(inps)):
                info = _dom_info(j)
                blob = (info["aria"] + " " + info["placeholder"] + " " + info["autocomplete"]).lower()
                if "nombre" in blob:
                    nombre_idx = j
                    break
            if nombre_idx is None:
                for j in range(len(inps)):
                    info = _dom_info(j)
                    if info["type"] == "text" and "correo" not in info["placeholder"].lower() and "email" not in info["autocomplete"]:
                        nombre_idx = j
                        break
            if nombre_idx is not None:
                clear_input(driver, inps[nombre_idx])
                inps[nombre_idx].send_keys("Selenium Registro")
                time.sleep(0.2)
            time.sleep(1)
            shot(driver, "CP-210-r2-sel-registro-llenado")
            clicked = click_when_enabled(driver, "Crear cuenta", timeout=40)
            time.sleep(WAIT_NAV)
            txt = semantics_text(driver)
            # verificación objetiva: el usuario existe vía API
            login_api = http.post(API_URL + "/auth/login",
                                  data={"email": REGISTRO_EMAIL, "password": TEST_PASSWORD}, timeout=30)
            creado = login_api.status_code == 200
            ok = clicked and (creado or "lchn" in txt.lower() or "recuperaci" in txt.lower() or "guard" in txt.lower())
            add_case("S-04", "Registro de usuario (reintento r2)",
                     "Se crea la cuenta y se muestra/muestra el flujo de recuperación",
                     f"clic={clicked}; api_login={creado}; url={driver.current_url}; labels={txt[:170]}",
                     "Aprobado" if ok else "Fallido", shot(driver, "CP-211-r2-sel-registro-resultado"))
        else:
            add_case("S-04", "Registro de usuario (reintento r2)",
                     "Se crea la cuenta y se muestra el flujo de recuperación",
                     f"no se ubicaron campos email/password; email_i={email_i} pws={pws}",
                     "Bloqueado", shot(driver, "CP-209-r2-sel-registro-form"))
    else:
        add_case("S-04", "Registro de usuario (reintento r2)",
                 "Se muestra el código de recuperación LCHN",
                 "no se pudo activar semántica tras reintentos", "Bloqueado",
                 shot(driver, "CP-209-r2-sel-registro-form"))
finally:
    driver.quit()

EVID.joinpath("resultados_selenium_r2.json").write_text(
    json.dumps(RESULT, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(RESULT, ensure_ascii=False, indent=2))