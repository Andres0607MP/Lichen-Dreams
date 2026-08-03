#!/usr/bin/env python
"""Migrar URLs de imagenes completas a rutas relativas y reestructurar archivos.

Ejecutar desde la carpeta `backend`:
    python scripts/migrate_image_urls.py

Realiza dos tareas:
1. Convierte URLs completas en la BD a rutas relativas:
   http://192.168.1.100:8000/uploads/foto.jpg  ->  /uploads/foto.jpg

2. Mueve archivos de uploads/ raiz a subdirectorios por tipo:
   uploads/foto.jpg                          ->  uploads/articles/foto.jpg
   uploads/avatar.jpg                        ->  uploads/profiles/user_5/avatar.jpg
   uploads/imagen.jpg                        ->  uploads/analyses/user_5/imagen.jpg

Tablas afectadas:
    - liquenpedia.imagen_articulo   ->  /uploads/articles/
    - usuarios.foto_perfil          ->  /uploads/profiles/user_{id}/
    - imagenes.url, imagenes.ruta_imagen  ->  /uploads/analyses/user_{id}/
"""
import sys
import os
import shutil

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Ensure DATABASE_URL defaults to SQLite in the backend directory
os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from sqlalchemy import text, inspect
from config.db import SessionLocal
from config.settings import normalize_image_path, UPLOADS_BASE_DIR, BACKEND_URL
from pathlib import Path


def _get_pk_col(db, table: str) -> str | None:
    pk = inspect(db.get_bind()).get_pk_constraint(table)["constrained_columns"]
    return pk[0] if pk else None


def _move_file(old_path: Path, new_path: Path, old_rel: str, new_rel: str, total: int) -> int:
    if old_path.exists() and not new_path.exists():
        new_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(old_path), str(new_path))
        print(f"  [MOVIDO] {old_rel} -> {new_rel}")
        return total + 1
    elif old_path.exists() and new_path.exists():
        old_path.unlink()
        print(f"  [BORRADO duplicado] {old_rel}")
        return total + 1
    elif not old_path.exists():
        print(f"  [SALTADO] archivo no existe: {old_rel}")
    return total


def _migrate_table(
    db,
    table: str,
    column: str,
    subdir_template: str,
    extra_query: str = "",
    pk_name: str = None,
):
    """Migrar una tabla: normalizar URLs a relativas + reorganizar archivos."""
    pk_col = pk_name or _get_pk_col(db, table)
    if not pk_col:
        print(f"  [WARN] Tabla '{table}' sin PK primaria, se salta.")
        return 0

    total = 0
    rows = db.execute(text(
        f"SELECT {pk_col}, {column} FROM {table} "
        f"WHERE {column} IS NOT NULL AND {column} != ''"
        + (f" AND {extra_query}" if extra_query else "")
    ))

    for pk, old_value in rows:
        if not isinstance(old_value, str):
            continue

        normalized = normalize_image_path(old_value)
        if normalized == old_value and normalized.startswith("/uploads/"):
            # Ya es relativo, pero podria estar en uploads/ raiz
            pass
        elif normalized != old_value:
            # Era URL completa, ahora es relativa
            pass
        else:
            continue

        # Si el path esta en uploads/ raiz (ej: /uploads/foto.jpg),
        # moverlo al subdirectorio correcto
        stripped = normalized
        if stripped.startswith("/uploads/"):
            stripped = stripped[len("/uploads/"):]
        parts = stripped.split("/")
        if len(parts) == 1 or (len(parts) == 2 and parts[0] == ""):
            # Esta en uploads/ raiz, reorganizar
            filename = parts[-1]
            old_fs_path = UPLOADS_BASE_DIR / stripped
            new_subdir = subdir_template.format(id=pk)
            new_fs_path = UPLOADS_BASE_DIR / new_subdir / filename
            new_rel = f"/uploads/{new_subdir}/{filename}"

            total += _move_file(old_fs_path, new_fs_path, normalized, new_rel, total)

            if normalized != new_rel:
                db.execute(
                    text(f"UPDATE {table} SET {column} = :val WHERE {pk_col} = :pk"),
                    {"val": new_rel, "pk": pk},
                )
        else:
            # Ya esta en subdirectorio, solo normalizar si era URL completa
            if normalized != old_value:
                db.execute(
                    text(f"UPDATE {table} SET {column} = :val WHERE {pk_col} = :pk"),
                    {"val": normalized, "pk": pk},
                )

    return total


def _verify_migration(db) -> int:
    """Verifica que no queden archivos privados en uploads/ raiz ni URLs completas en BD."""
    warnings = 0
    db.close()

    verify_db = SessionLocal()
    try:
        # 1. Verificar archivos en uploads/ raiz (no en subdirectorios)
        for item in UPLOADS_BASE_DIR.iterdir():
            if item.is_file():
                ext = item.suffix.lower()
                if ext in {".jpg", ".jpeg", ".png", ".webp"}:
                    print(f"  [WARN] Archivo en uploads/ raiz sin clasificar: {item.name}")
                    warnings += 1

        # 2. Verificar URLs completas en BD (http://... en lugar de /uploads/...)
        tables_cols = [
            ("liquenpedia", "imagen_articulo"),
            ("usuarios", "foto_perfil"),
        ]
        for table, col in tables_cols:
            count = verify_db.execute(text(
                f"SELECT COUNT(*) FROM {table} WHERE {col} IS NOT NULL AND {col} LIKE 'http%'"
            )).scalar()
            if count:
                print(f"  [WARN] {count} registros en {table}.{col} con URL completa (http://)")
                warnings += count

        # 3. Verificar imagenes.url y imagenes.ruta_imagen con URLs completas
        count = verify_db.execute(text(
            "SELECT COUNT(*) FROM imagenes WHERE "
            "(url LIKE 'http%' OR ruta_imagen LIKE 'http%')"
        )).scalar()
        if count:
            print(f"  [WARN] {count} registros en imagenes con URL completa (http://)")
            warnings += count

        if warnings > 0:
            print(f"\n  [ADVERTENCIA] {warnings} problema(s) encontrados durante la verificacion.")
        else:
            print("\n  [OK] Verificacion completada: no se encontraron URLs completas ni archivos mal clasificados.")
    finally:
        verify_db.close()

    return warnings


def migrate():
    """Ejecutar migracion de datos y archivos."""
    db = SessionLocal()
    total = 0
    try:
        print("Migrando liquenpedia.imagen_articulo -> /uploads/articles/")
        total += _migrate_table(
            db, "liquenpedia", "imagen_articulo",
            subdir_template="articles",
            extra_query="imagen_articulo IS NOT NULL",
        )

        print("\nMigrando usuarios.foto_perfil -> /uploads/profiles/user_{id}/")
        total += _migrate_table(
            db, "usuarios", "foto_perfil",
            subdir_template="profiles/user_{id}",
        )

        print("\nMigrando imagenes.url, imagenes.ruta_imagen -> /uploads/analyses/user_{id}/")
        # Para imagenes, necesitamos el id_usuario del analisis asociado
        imagenes_pk = _get_pk_col(db, "imagenes")
        if imagenes_pk:
            rows = db.execute(text(
                f"SELECT i.{imagenes_pk}, i.url, i.ruta_imagen, a.id_usuario "
                f"FROM imagenes i LEFT JOIN analisis a ON i.id_analisis = a.id_analisis "
                f"WHERE (i.url IS NOT NULL AND i.url != '') OR (i.ruta_imagen IS NOT NULL AND i.ruta_imagen != '')"
            ))
            for img_id, url_val, ruta_val, user_id in rows:
                for col_name, old_value in [("url", url_val), ("ruta_imagen", ruta_val)]:
                    if not isinstance(old_value, str):
                        continue
                    normalized = normalize_image_path(old_value)
                    if normalized == old_value and normalized.startswith("/uploads/"):
                        continue

                    stripped = normalized
                    if stripped.startswith("/uploads/"):
                        stripped = stripped[len("/uploads/"):]
                    parts = stripped.split("/")
                    if len(parts) == 1:
                        filename = parts[-1]
                        old_fs_path = UPLOADS_BASE_DIR / stripped
                        user_dir = "analyses"
                        if user_id:
                            user_dir = f"analyses/user_{user_id}"
                        new_fs_path = UPLOADS_BASE_DIR / user_dir / filename
                        new_rel = f"/uploads/{user_dir}/{filename}"

                        total += _move_file(old_fs_path, new_fs_path, normalized, new_rel, total)
                        db.execute(
                            text(f"UPDATE imagenes SET {col_name} = :val WHERE {imagenes_pk} = :pk"),
                            {"val": new_rel, "pk": img_id},
                        )
                    elif normalized != old_value:
                        db.execute(
                            text(f"UPDATE imagenes SET {col_name} = :val WHERE {imagenes_pk} = :pk"),
                            {"val": normalized, "pk": img_id},
                        )

        db.commit()
        print(f"\n[OK] Migracion completada. {total} archivos movidos/actualizados.")
        print(f"     BACKEND_URL: {BACKEND_URL}")

        print("\nVerificando integridad de la migracion...")
        _verify_migration(db)
    except Exception as e:
        db.rollback()
        print(f"[ERROR] Error durante la migracion: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    migrate()
