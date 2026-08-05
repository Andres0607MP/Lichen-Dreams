import sys
from pathlib import Path
project_root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(project_root))
from services.analysis_service import AnalysisService
from config.db import SessionLocal
from sqlalchemy import text

svc = AnalysisService()
with SessionLocal() as db:
    row = db.execute(text('SELECT id_analisis FROM analisis ORDER BY fecha DESC LIMIT 1')).fetchone()
    if not row:
        print('NO_ANALYSIS')
    else:
        aid = row[0]
        res = svc.get_results(aid)
        keys = ['id','url_imagen','imagen_url','image_url','imagen_base64','image_base64']
        print('analysis_id:', aid)
        for k in keys:
            v = res.get(k)
            if v is None:
                print(f'{k}: None')
            elif isinstance(v,str) and len(v)>200:
                print(f'{k}: (string len {len(v)})')
            else:
                print(f'{k}: {v}')
