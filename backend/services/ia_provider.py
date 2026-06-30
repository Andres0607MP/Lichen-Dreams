from typing import Any, Dict


class IAProvider:
    def analyze(self, image_url: str) -> Dict[str, Any]:
        raise NotImplementedError


class MockIAProvider(IAProvider):
    def analyze(self, image_url: str) -> Dict[str, Any]:
        return {
            "resultado": "liquen saludable",
            "estado": "completado",
            "humedad": 65.5,
            "calidad_del_aire": "moderada",
            "recomendacion": "Buena calidad del aire",
        }
