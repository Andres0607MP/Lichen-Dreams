"""Análisis de píxeles: detecta el banner SnackBar de Material en la captura
del login con credenciales incorrectas (S-02). Compara contra la captura
previa al envío (sin SnackBar) como referencia.
"""
from PIL import Image
from pathlib import Path

EVID = Path("docs/sprint5/evidencias/selenium")


def dark_band_fraction(path, tolerance=12):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    y0 = int(h * 0.82)
    y1 = int(h * 0.99)
    dark = 0
    total = 0
    for y in range(y0, y1, 3):
        for x in range(0, w, 4):
            r, g, b = img.getpixel((x, y))
            total += 1
            # gris oscuro (Material SnackBar ~ #323232)
            if 25 <= r <= 100 and 25 <= g <= 100 and 25 <= b <= 100 \
                    and abs(r - g) <= tolerance and abs(g - b) <= tolerance:
                dark += 1
    return round(dark / max(total, 1), 4), (w, h)


ante = EVID / "CP-202-r2-sel-login-incorrecto-llenado.png"
post = EVID / "CP-203-r2-sel-login-incorrecto-error.png"

for name, p in [("antes (sin error)", ante), ("despues (tras login invalido)", post)]:
    if p.exists():
        frac, size = dark_band_fraction(str(p))
        print(f"{name}: {p.name} -> fraccion_banda_oscura={frac} size={size}")
    else:
        print(f"{name}: AUSENTE {p.name}")