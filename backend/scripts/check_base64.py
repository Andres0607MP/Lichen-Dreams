import sys
from pathlib import Path
project_root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(project_root))
from services.analysis_service import AnalysisService
from config.db import SessionLocal
from sqlalchemy import text
svc=AnalysisService()
with SessionLocal() as db:
    row=db.execute(text('SELECT id_analisis FROM analisis ORDER BY fecha DESC LIMIT 1')).fetchone()
    if not row:
        print('NO')
    else:
        aid=row[0]
        res=svc.get_results(aid)
        b=res.get('imagen_base64') or res.get('image_base64')
        if not b:
            print('no base64')
        else:
            print('len',len(b))
            print('prefix',b[:50])
            print('startswith /9j/', b.startswith('/9j/'))
