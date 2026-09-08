import time, random, string
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
import requests

BASE = "http://127.0.0.1:8080"
SUF = "".join(random.choices(string.ascii_lowercase, k=5))
EMAIL = f"sel_f_{SUF}@test.com"
PASS = "Testing123!"
requests.post("http://127.0.0.1:8000/auth/register",
              json={"name": "Sel", "apellido": "F", "email": EMAIL, "password": PASS}, timeout=30)

opts = Options()
for a in ["--headless=new", "--no-sandbox", "--disable-gpu", "--disable-software-rasterizer",
          "--disable-dev-shm-usage", "--window-size=1360,900"]:
    opts.add_argument(a)
d = webdriver.Chrome(options=opts)

T0 = time.time()


def poll_click_placeholder():
    return d.execute_async_script("""
      const done = arguments[arguments.length-1];
      const attempts = [];
      let tries = 0;
      const iv = setInterval(() => {
        tries++;
        const ph = document.querySelector('flt-semantics-placeholder');
        if (ph) {
          clearInterval(iv);
          ph.dispatchEvent(new MouseEvent('click', {bubbles:true}));
          ph.focus();
          done(true);
        } else if (tries > 100) {
          clearInterval(iv);
          done(false);
        }
      }, 150);
    """)


def try_load():
    for at in range(5):
        try:
            d.get(BASE)
        except Exception:
            pass
        time.sleep(6)
        ok = poll_click_placeholder()
        time.sleep(4)
        for _ in range(5):
            if len(d.find_elements(By.TAG_NAME, "input")) >= 2:
                return True
            time.sleep(2)
        print(f"  intento {at+1}: placeholder_click={ok}, sin inputs", flush=True)
    return False


try:
    if not try_load():
        print("RESULTADO=BLOQUEADO_activacion_semantica")
    else:
        inps = d.find_elements(By.TAG_NAME, "input")
        print("inputs:", len(inps), flush=True)
        inps[0].send_keys(EMAIL)
        time.sleep(0.4)
        inps[1].send_keys(PASS)
        time.sleep(1)
        d.save_screenshot("docs/sprint5/evidencias/selenium/f01_login_llenado.png")
        # esperar que el botón deje de estar deshabilitado
        habilitado = False
        for _ in range(15):
            for b in d.find_elements(By.CSS_SELECTOR, "flt-semantics[role='button']"):
                try:
                    if "iniciar" in (b.text or "").lower():
                        if b.get_attribute("aria-disabled") != "true":
                            habilitado = True
                except Exception:
                    pass
            if habilitado:
                break
            time.sleep(1)
        print("boton_habilitado:", habilitado, flush=True)
        if not habilitado:
            print("RESULTADO=FALLIDO_boton_sigue_deshabilitado")
        else:
            for b in d.find_elements(By.CSS_SELECTOR, "flt-semantics[role='button']"):
                try:
                    if "iniciar" in (b.text or "").lower():
                        b.click()
                        break
                except Exception:
                    pass
            for _ in range(120):
                if "dashboard" in d.current_url or "home" in d.current_url:
                    break
                time.sleep(0.8)
            print("URL:", d.current_url, "| t=%.0fs" % (time.time() - T0), flush=True)
            navego = "dashboard" in d.current_url or "home" in d.current_url
            time.sleep(6)
            d.save_screenshot("docs/sprint5/evidencias/selenium/f02_login_exitoso.png")
            labels = []
            for n in d.find_elements(By.TAG_NAME, "flt-semantics")[:60]:
                try:
                    t = n.get_attribute("aria-label") or n.text
                    if t and t.strip():
                        labels.append(t.strip()[:50])
                except Exception:
                    pass
            print("LABELS:", labels[:20], flush=True)
            print("RESULTADO=" + ("OK_navego" if navego else "FALLIDO_no_navego"))
finally:
    try:
        d.quit()
    except Exception:
        pass
print("FIN")