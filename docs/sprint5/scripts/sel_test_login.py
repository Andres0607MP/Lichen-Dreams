import time, random, string
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
import requests

BASE = "http://127.0.0.1:8080"
SUF = "".join(random.choices(string.ascii_lowercase, k=5))
EMAIL = f"sel_x_{SUF}@test.com"
PASS = "Testing123!"
requests.post("http://127.0.0.1:8000/auth/register",
              json={"name": "Sel", "apellido": "X", "email": EMAIL, "password": PASS}, timeout=30)

opts = Options()
for a in ["--headless=new", "--no-sandbox", "--disable-gpu", "--disable-software-rasterizer",
          "--disable-dev-shm-usage", "--window-size=1360,900"]:
    opts.add_argument(a)
d = webdriver.Chrome(options=opts)
t0 = time.time()
try:
    d.get(BASE)
    time.sleep(10)
    d.execute_script("""const ph=document.querySelector('flt-semantics-placeholder');
      if(ph){ph.dispatchEvent(new MouseEvent('click',{bubbles:true}));}""")
    time.sleep(5)
    for _ in range(6):
        if len(d.find_elements(By.TAG_NAME, "input")) >= 2:
            break
        time.sleep(2)
    inps = d.find_elements(By.TAG_NAME, "input")
    print("inputs:", len(inps), "|= t=%.1fs" % (time.time() - t0))
    inps[0].send_keys(EMAIL)
    time.sleep(0.5)
    inps[1].send_keys(PASS)
    time.sleep(1)

    # Imprimir estado del botón login
    for b in d.find_elements(By.CSS_SELECTOR, "flt-semantics[role='button']"):
        label = (b.text or "")
        if "iniciar" in label.lower():
            print("boton login:", "aria-disabled=", b.get_attribute("aria-disabled"),
                  "tabindex=", b.get_attribute("tabindex"), "flt-tappable=", b.get_attribute("flt-tappable"))
    d.save_screenshot("docs/sprint5/evidencias/selenium/x01_login_lleno.png")

    # clic
    ok = False
    for _ in range(20):
        for b in d.find_elements(By.CSS_SELECTOR, "flt-semantics[role='button']"):
            try:
                if "iniciar" in (b.text or "").lower():
                    if b.get_attribute("aria-disabled") == "true":
                        pass
                    else:
                        b.click()
                        ok = True
                        break
            except Exception:
                pass
        if ok:
            break
        time.sleep(0.7)
    print("click ok:", ok)
    for _ in range(120):
        if "dashboard" in d.current_url or "home" in d.current_url:
            break
        time.sleep(0.8)
    print("URL final:", d.current_url, "| t=%.1fs" % (time.time() - t0))
    d.save_screenshot("docs/sprint5/evidencias/selenium/x02_login_post.png")
finally:
    try:
        d.quit()
    except Exception:
        pass
print("FIN")