import sys
sys.path.insert(0, '.')

from config.db import SessionLocal
from sqlalchemy import inspect, text

db = SessionLocal()
try:
    inspector = inspect(db.bind)
    print('=== TABLAS ===')
    for table in inspector.get_table_names():
        print(f'  {table}')
    
    print('\n=== ESTRUCTURA liquenpedia ===')
    cols = inspector.get_columns('liquenpedia')
    for col in cols:
        print(f'  {col["name"]}: {col["type"]} nullable={col["nullable"]} default={col.get("default")}')
    
    print('\n=== ESTRUCTURA categorias_articulos ===')
    cols = inspector.get_columns('categorias_articulos')
    for col in cols:
        print(f'  {col["name"]}: {col["type"]} nullable={col["nullable"]} default={col.get("default")}')
    
    print('\n=== CONTEO POR CATEGORÍA ===')
    result = db.execute(text('SELECT categoria, COUNT(*) as cnt FROM liquenpedia GROUP BY categoria ORDER BY categoria'))
    for row in result:
        print(f'  {row.categoria}: {row.cnt}')
    
    print('\n=== CATEGORÍAS EXISTENTES ===')
    result = db.execute(text('SELECT id_categoria, nombre_categoria FROM categorias_articulos ORDER BY nombre_categoria'))
    for row in result:
        print(f'  ID={row.id_categoria}: {row.nombre_categoria}')
    
    print('\n=== TOTAL ARTÍCULOS ===')
    result = db.execute(text('SELECT COUNT(*) FROM liquenpedia'))
    print(f'  Total: {result.scalar()}')
    
finally:
    db.close()