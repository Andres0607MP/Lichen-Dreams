import requests, re
r = requests.get("http://127.0.0.1:8080/", timeout=15)
print("STATUS", r.status_code)
print(re.findall(r'src="([^"]+)"', r.text))
print(r.text[:1500])