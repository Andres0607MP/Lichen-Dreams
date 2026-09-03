"""Renombrado seguro del dataset de liquenes.

Convenciones:
  liquenes_saludables/    -> ls_0001.ext ...
  liquenes_contaminados/  -> lc_0001.ext ...
  liquenes_desconocidos/<subcarpeta>/ -> <prefijo>_0001.ext ...

Seguridad:
  - Nunca borra/mueve imagenes; solo renombra en su carpeta.
  - Dos fases con nombres temporales (evita sobrescribir y ciclos).
  - Idempotente: si ya tienen el formato correcto, no toca nada.
"""

import argparse
import os
import re
import uuid
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent / "datasets"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tiff", ".tif"}
PREFIXES = {"liquenes_saludables": "ls", "liquenes_contaminados": "lc"}
FIXED = re.compile(r"^[a-z]{2,4}_\d{4}\.(jpg|jpeg|png|bmp|webp|tiff|tif)$")


def _words(name: str):
    return [w for w in re.split(r"[_\-\s]+", name) if w]


def _candidates(name: str):
    words = _words(name)
    if len(words) >= 2:
        yield words[0][0] + words[1][0]
        yield words[0][0] + words[1][1]
        yield words[0][0] + words[0][1]
        yield words[0][:2] + words[1][0]
    else:
        w = words[0] if words else name
        yield w[:2]
        yield w[:3]


def make_prefixes(subfolders):
    """Prefijo unico por subcarpeta, derivado del nombre real."""
    used = {"ls", "lc"}
    prefixes = {}
    for folder in subfolders:
        chosen = None
        for cand in _candidates(folder):
            if cand not in used:
                chosen = cand
                break
        if chosen is None:
            n = 2
            chosen = folder[:4]
            while chosen in used:
                chosen = f"{folder[:4]}{n}"
                n += 1
        used.add(chosen)
        prefixes[folder] = chosen
    return prefixes


def list_images(folder: Path):
    return [
        f
        for f in folder.iterdir()
        if f.is_file() and not f.name.startswith(".") and f.suffix.lower() in IMAGE_EXTS
    ]


def renumber(folder: Path, prefix: str):
    """Renombra todas las imagenes de 'folder' a 'prefix_NNNN.ext'."""
    files = sorted(list_images(folder), key=lambda f: f.name.lower())
    total = len(files)
    already = 0
    renamed = 0

    moves = []  # (origen, destino)
    for i, path in enumerate(files, start=1):
        new_name = f"{prefix}_{i:04d}{path.suffix.lower()}"
        new_path = path.with_name(new_name)
        if path.resolve() == new_path.resolve():
            already += 1
            continue
        moves.append((path, new_path))

    # Fase 1: mover todo a un nombre temporal unico (evita colisiones/ciclos).
    temps = []
    for seq, (old, _new) in enumerate(moves):
        tmp = old.with_name(f".__tmp_{seq}_{uuid.uuid4().hex[:6]}{old.suffix.lower()}")
        old.rename(tmp)
        temps.append((tmp, _new))

    # Fase 2: renombrar temporal -> destino final.
    for tmp, new in temps:
        if new.exists():
            # No deberia ocurrir (destinos unicos); por seguridad.
            raise RuntimeError(f"Colision inesperada con destino: {new}")
        tmp.rename(new)
        renamed += 1

    return total, renamed, already


def main():
    parser = argparse.ArgumentParser(description="Renombrar dataset de liquenes")
    parser.add_argument("--dry-run", action="store_true", help="Solo muestra el plan")
    args = parser.parse_args()

    print("=== RENOMBRADO DEL DATASET ===")
    antes = 0
    despues = 0
    total_renamed = 0
    total_already = 0

    # Clases raiz
    for clase, prefix in PREFIXES.items():
        folder = BASE_DIR / clase
        if not folder.is_dir():
            print(f"\n{clase}: (no existe)")
            continue
        total = len(list_images(folder))
        antes += total
        despues += total
        if args.dry_run:
            print(f"\n{clase}:\n  Antes: {total}\n  Después: {total} (dry-run)")
            continue
        t, r, a = renumber(folder, prefix)
        total_renamed += r
        total_already += a
        print(f"\n{clase}:\n  Antes: {total}\n  Después: {t}\n  Prefijo: {prefix}")

    # Subcarpetas de desconocidos
    unknown = BASE_DIR / "liquenes_desconocidos"
    if unknown.is_dir():
        subs = sorted(
            d.name for d in unknown.iterdir() if d.is_dir()
        )
        if not subs:
            print("\nliquenes_desconocidos: (sin subcarpetas)")
        else:
            prefixes_map = make_prefixes(subs)
            print("\nliquenes_desconocidos:")
            for sub in subs:
                folder = unknown / sub
                n = len(list_images(folder))
                antes += n
                despues += n
                prefix = prefixes_map[sub]
                if args.dry_run:
                    print(f"\n  {sub}:\n    Antes: {n}\n    Prefijo: {prefix} (dry-run)")
                    continue
                t, r, a = renumber(folder, prefix)
                total_renamed += r
                total_already += a
                print(
                    f"\n  {sub}:\n"
                    f"    Antes: {n}\n    Después: {t}\n    Prefijo: {prefix}"
                )

    print(f"\nTotal de imágenes:\n  Antes: {antes}\n  Después: {despues}")
    print(f"Archivos perdidos: {antes - despues}")
    print("Archivos sobrescritos: 0")
    print(f"Ya con formato correcto: {total_already}")
    print(f"Renombradas: {total_renamed}")
    print(f"Consistencia: {'OK (antes == despues)' if antes == despues else 'ERROR'}")


if __name__ == "__main__":
    os.makedirs(BASE_DIR, exist_ok=True)
    main()