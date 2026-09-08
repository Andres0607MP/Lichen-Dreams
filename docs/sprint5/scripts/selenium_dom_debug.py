import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

opts = Options()
opts.add_argument("--headless=new")
opts.add_argument("--no-sandbox")
opts.add_argument("--disable-gpu")
opts.add_argument("--window-size=1360,900")
driver = webdriver.Chrome(options=opts)
try:
    driver.get("http://127.0.0.1:8080/")
    time.sleep(10)
    driver.execute_script("""
      const ph = document.querySelector('flt-semantics-placeholder');
      if (ph) { ph.dispatchEvent(new MouseEvent('click', {bubbles:true})); }
    """)
    time.sleep(6)
    nodes = driver.find_elements(By.CSS_SELECTOR, "flt-semantics")
    print("NODOS flt-semantics:", len(nodes))
    etiquetados = 0
    for n in nodes[:40]:
        try:
            html = n.get_attribute("outerHTML")
        except Exception:
            continue
        if html and len(html) < 400:
            etiquetados += 1
            print(html[:220])
        if etiquetados >= 10:
            break
    print("---inputs---")
    for i in driver.find_elements(By.TAG_NAME, "input")[:2]:
        print(i.get_attribute("outerHTML")[:160])
finally:
    driver.quit()