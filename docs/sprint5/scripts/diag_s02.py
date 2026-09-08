"""Diagnóstico S-02: login con credenciales incorrectas, capturando cada
segundo si aparece el SnackBar de error (banner oscuro inferior).
"""
import time
from pathlib import Path
from PIL import Image

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

BASE = "http://127.0.0.1:8080"
EVID = Path("docs/sprint5/evidencias/selenium")


def dark_band_frac(driver, tolerance=12):
    js = driver.execute_script("return {w: window.innerWidth, h: window.innerHeight};")
    return None  # placeholder


def make_driver():
    opts = Options()
    for a in ["--headless=new", "--no-sandbox", "--disable-gpu", "--disable-software-rasterizer",
              "--disable-dev-shm-usage", "--force-device-scale-factor=1", "--window-size=1360,900"]:
        opts.add_argument(a)
    return webdriver.Chrome(options=opts)


d = make_driver()
try:
    d.get(BASE)
    time.sleep(20)
    d.execute_async_script("""
      const done = arguments[arguments.length-1];
      let tries=0;
      const iv=setInterval(()=>{
        tries++;
        const ph=document.querySelector('flt-semantics-placeholder');
        if(ph){ clearInterval(iv); ph.dispatchEvent(new MouseEvent('click',{bubbles:true})); done(true); }
        else if(tries>300){ clearInterval(iv); done(false); }
      },150);
    """)
    time.sleep(20)
    inps = d.find_elements(By.TAG_NAME, "input")
    print("inputs:", len(inps), flush=True)
    if len(inps) >= 2:
        inps[0].clear(); inps[0].send_keys("usuario_no_existe@test.com")
        time.sleep(0.4)
        inps[1].clear(); inps[1].send_keys("Incorrecta123!")
        time.sleep(1.5)
        # encontrar botón login
        btn = None
        for b in d.find_elements(By.CSS_SELECTOR, "flt-semantics[role='button']"):
            try:
                if "iniciar" in (b.text or "").lower():
                    btn = b
                    break
            except Exception:
                pass
        print("boton encontrado:", btn is not None, flush=True)
        if btn is not None:
            print("disabled:", btn.get_attribute("aria-disabled"), flush=True)
            btn.click()
            print("CLIC HECHO", flush=True)
        # monitoreo 12 s: captura semántica + pixel + screenshot
        from_path = EVID / "CP-203-r2-sel-login-incorrecto-error.png"
        for i in range(1, 13):
            time.sleep(1)
            try:
                txt = d.execute_script("""
                  const out=[];
                  document.querySelectorAll('flt-semantics').forEach(n=>{
                    const a=n.getAttribute('aria-label');
                    const t=(n.textContent||'').trim();
                    if(a&&a.trim()) out.push(a.trim());
                    if(t) out.push(t);
                  });
                  return Array.from(new Set(out)).join(' | ');
                """)
            except Exception as e:
                txt = f"ERR {e}"
            lower = txt.lower()
            if any(s in lower for s in ["credencial", "inválid", "invalida", "error"]):
                print(f"t={i}s SEMANTICA_CONTIENE_ERROR: {txt[:150]}", flush=True)
            d.save_screenshot(str(EVID / f"s2_t{i}.png"))
            # fracción banda inferior
            img = Image.open(str(EVID / f"s2_t{i}.png")).convert("RGB")
            w, h = img.size
            y0, y1 = int(h * 0.82), int(h * 0.99)
            dark = 0
            total = 0
            for y in range(y0, y1, 3):
                for x in range(0, w, 4):
                    r, g, b = img.getpixel((x, y))
                    total += 1
                    if 25 <= r <= 100 and 25 <= g <= 100 and 25 <= b <= 100 and abs(r - g) <= 12 and abs(g - b) <= 12:
                        dark += 1
            frac = round(dark / max(total, 1), 4)
            print(f"t={i}s frac_banda={frac}", flush=True)
        # captura final
        d.save_screenshot(str(from_path))
        print("FINAL", flush=True)
finally:
    d.quit()
print("FIN+")