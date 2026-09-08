import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

opts = Options()
opts.add_argument("--headless=new")
opts.add_argument("--no-sandbox")
opts.add_argument("--disable-gpu")
opts.add_argument("--window-size=1280,900")
driver = webdriver.Chrome(options=opts)
try:
    driver.get("http://127.0.0.1:8080/")
    time.sleep(12)
    # Activar semántica de Flutter web haciendo clic en el placeholder
    driver.execute_script("""
      const ph = document.querySelector('flt-semantics-placeholder');
      if (ph) { ph.dispatchEvent(new MouseEvent('click', {bubbles: true})); ph.focus(); }
    """)
    time.sleep(6)
    placeholders = driver.find_elements(By.TAG_NAME, "flt-semantics-placeholder")
    print("PLACEHOLDERS:", len(placeholders))
    for p in placeholders[:5]:
        print("  ", p.get_attribute("id"), p.get_attribute("role"), p.get_attribute("aria-label"))
    inputs = driver.find_elements(By.TAG_NAME, "input")
    print("INPUTS:", len(inputs))
    for i, inp in enumerate(inputs[:20]):
        try:
            print("  input", i, "type=", inp.get_attribute("type"), "placeholder=", inp.get_attribute("placeholder") or inp.get_attribute("aria-label"))
        except Exception as e:
            print("  err", e)
    flt = driver.find_elements(By.CSS_SELECTOR, "flt-semantics")
    print("FLT-SEMANTICS:", len(flt))
    texts = []
    for f in flt[:30]:
        try:
            label = f.get_attribute("aria-label") or f.get_attribute("role") or f.get_attribute("text")
            texts.append(label)
        except Exception:
            pass
    print("LABELS:", texts[:30])
    driver.save_screenshot("docs/sprint5/evidencias/selenium/probe_login_semantics.png")
    print("screenshot guardada")
finally:
    driver.quit()