import os
import sys

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from services.analysis_service import AnalysisService


def test_analysis_service_provides_contract_fields_without_database():
    service = AnalysisService()

    result = service.process_analysis(image_url="https://example.com/image.jpg")

    expected_fields = {
        "id",
        "id_usuario",
        "url_imagen",
        "resultado",
        "estado",
        "humedad",
        "calidad_del_aire",
        "recomendacion",
        "fecha_creacion",
    }
    assert expected_fields.issubset(result.keys())
    assert isinstance(result["humedad"], (int, float))
    assert isinstance(result["estado"], str)
    assert result["url_imagen"] == "/image.jpg"
