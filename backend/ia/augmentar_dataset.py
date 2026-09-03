"""Dataset augmentation para liquenes (clase contaminado - prioridad lcp_).

Regenera liquenes_contaminados hasta 500 imagenes usando SOLO como fuente las
imagenes prioritarias 'lcp_*'. Las 'lc_*' NO se usan como fuente. Las variantes
augmentadas se nombran 'lcp_aug_NNNN.jpg', no se sobrescriben y no se vuelven a
usar como fuente. No toca saludables ni desconocidos ni originales.

Uso:
    python ia/augmentar_dataset.py
"""
import random
import sys
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps

BASE_DIR = Path(__file__).resolve().parent / "datasets"
TARGET = 500
CLASS_FOLDER = BASE_DIR / "liquenes_contaminados"
SRC_PREFIX = "lcp_"
AUG_PREFIX = "lcp_aug_"
OUT_EXT = ".jpg"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tiff", ".tif"}


def is_image(f: Path) -> bool:
    return f.is_file() and f.suffix.lower() in IMAGE_EXTS


def inventory():
    files = sorted([f for f in CLASS_FOLDER.iterdir() if is_image(f)], key=lambda p: p.name)
    lcp = [f for f in files if f.name.startswith(SRC_PREFIX) and AUG_PREFIX not in f.name]
    lcp_aug = [f for f in files if f.name.startswith(AUG_PREFIX)]
    lc = [f for f in files if f.name.startswith("lc_") and AUG_PREFIX not in f.name and SRC_PREFIX not in f.name]
    return files, lcp, lcp_aug, lc


def max_aug_index():
    m = 0
    for f in CLASS_FOLDER.glob(f"{AUG_PREFIX}*{OUT_EXT}"):
        try:
            m = max(m, int(f.stem.rsplit("_", 1)[-1]))
        except ValueError:
            continue
    return m


def random_transform(img: Image.Image) -> Image.Image:
    # Pequeño zoom/crop
    scale = random.uniform(0.92, 1.0)
    w, h = img.size
    nw, nh = int(w * scale), int(h * scale)
    x0 = random.randint(0, max(0, w - nw))
    y0 = random.randint(0, max(0, h - nh))
    img = img.crop((x0, y0, x0 + nw, y0 + nh)).resize((w, h), Image.BILINEAR)

    # Pequeña rotación
    img = img.rotate(random.uniform(-10, 10), resample=Image.BILINEAR, expand=False)

    if random.random() < 0.4:
        img = ImageOps.mirror(img)

    if random.random() < 0.6:
        img = ImageEnhance.Brightness(img).enhance(random.uniform(0.85, 1.15))
    if random.random() < 0.6:
        img = ImageEnhance.Contrast(img).enhance(random.uniform(0.85, 1.15))
    if random.random() < 0.5:
        img = ImageEnhance.Color(img).enhance(random.uniform(0.8, 1.2))
    if random.random() < 0.3:
        img = img.filter(ImageFilter.UnsharpMask(radius=2, percent=80))
    return img


def main():
    if not CLASS_FOLDER.is_dir():
        print(f"Error: carpeta inexistente {CLASS_FOLDER}")
        sys.exit(1)

    files, lcp, lcp_aug, lc = inventory()
    current = len(files)
    needed = TARGET - current

    print("=== DATASET AUGMENTATION (contaminados - lcp_*) ===")
    print(f"Total actual de contaminados: {current}")
    print(f"Cantidad de lcp_*: {len(lcp)}")
    print(f"Cantidad de lc_*: {len(lc)}")
    print(f"Cantidad de aumentadas existentes: {len(lcp_aug)}")
    print(f"Objetivo: {TARGET}")
    print(f"Faltan para llegar a 500: {max(0, needed)}")
    print(f"Cantidad que se generará: {max(0, needed)}")

    if needed <= 0:
        print("Objetivo ya alcanzado. No se generaron imágenes.")
        return

    if not lcp:
        print(f"NO HAY suficientes lcp_* para generar. Disponibles: {len(lcp)} lcp_*; "
              f"faltan {needed} imágenes. No se usa lc_* como fuente. Proceso detenido.")
        sys.exit(1)

    start = max_aug_index() + 1
    generated = 0
    failed = 0
    for i in range(needed):
        src = random.choice(lcp)
        out = CLASS_FOLDER / f"{AUG_PREFIX}{start + i:04d}{OUT_EXT}"
        try:
            with Image.open(src) as img:
                img = ImageOps.exif_transpose(img)
                if img.mode != "RGB":
                    img = img.convert("RGB")
                random_transform(img).save(out, "JPEG", quality=92)
            generated += 1
        except Exception as e:
            failed += 1
            print(f"  Advertencia: no se pudo procesar {src.name}: {e}")

    total_after = len([f for f in CLASS_FOLDER.iterdir() if is_image(f)])
    print(f"\nImágenes generadas: {generated} (fallos: {failed})")
    print(f"Total final de contaminados: {total_after}")
    print(f"Originales conservadas: sí")
    print(f"Duplicados: 0")


if __name__ == "__main__":
    random.seed()
    main()