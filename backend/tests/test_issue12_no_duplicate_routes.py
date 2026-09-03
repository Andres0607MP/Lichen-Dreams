import os
import re
import sys

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from main import app


sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))


def _collect_route_paths(application):
    """Recoge todos los paths de rutas, incluyendo routers incluidos."""
    paths = []
    for route in application.routes:
        if hasattr(route, "path") and route.path:
            paths.append(route.path)
        if hasattr(route, "original_router"):
            context = getattr(route, "include_context", None)
            prefix = getattr(context, "prefix", "") if context else ""
            for sub in route.original_router.routes:
                if hasattr(sub, "path") and sub.path:
                    paths.append((prefix or "") + sub.path)
    return paths


def test_no_parallel_analysis_or_history_routes_are_exposed():
    route_paths = _collect_route_paths(app)

    analysis_paths = [str(path) for path in route_paths if str(path).startswith("/analysis")]
    history_paths = [str(path) for path in route_paths if str(path).startswith("/history")]

    assert analysis_paths, "Debe existir al menos una ruta oficial de análisis"
    assert history_paths, "Debe existir al menos una ruta oficial de historial"

    forbidden_pattern = re.compile(r"(analysis|history)(?:[_-]?v\d+|[_-]?copy|[_-]?duplicate|2)", re.IGNORECASE)
    for path in analysis_paths + history_paths:
        assert not forbidden_pattern.search(path), f"Ruta paralela o redundante detectada: {path}"
