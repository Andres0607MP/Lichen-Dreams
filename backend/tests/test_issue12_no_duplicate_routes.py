import os
import re
import sys

from main import app


sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))


def test_no_parallel_analysis_or_history_routes_are_exposed():
    route_paths = [route.path for route in app.routes if hasattr(route, "path")]

    analysis_paths = [path for path in route_paths if path.startswith("/analysis")]
    history_paths = [path for path in route_paths if path.startswith("/history")]

    assert analysis_paths, "Debe existir al menos una ruta oficial de análisis"
    assert history_paths, "Debe existir al menos una ruta oficial de historial"

    forbidden_pattern = re.compile(r"(analysis|history)(?:[_-]?v\d+|[_-]?copy|[_-]?duplicate|2)", re.IGNORECASE)
    for path in analysis_paths + history_paths:
        assert not forbidden_pattern.search(path), f"Ruta paralela o redundante detectada: {path}"
