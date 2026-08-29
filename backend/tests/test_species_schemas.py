import pytest
from pydantic import ValidationError

from models.validations import EspecieLiquenCreate, EspecieLiquenUpdate


def test_create_requiere_nombre_cientifico():
    with pytest.raises(ValidationError):
        EspecieLiquenCreate(descripcion="Solo descripción")

    with pytest.raises(ValidationError):
        EspecieLiquenCreate(nombre_cientifico=None)


def test_create_normaliza_con_espacios():
    creada = EspecieLiquenCreate(
        nombre_cientifico="  Xanthoria parietina  ",
        nombre_comun="   Líquen anaranjado   ",
        habitat="   ",
    )
    assert creada.nombre_cientifico == "Xanthoria parietina"
    assert creada.nombre_comun == "Líquen anaranjado"
    assert creada.habitat is None


def test_create_rechaza_nombre_solo_espacios():
    with pytest.raises(ValidationError):
        EspecieLiquenCreate(nombre_cientifico="   ")


def test_create_aplica_limites_longitud():
    with pytest.raises(ValidationError):
        EspecieLiquenCreate(nombre_cientifico="x" * 101)
    with pytest.raises(ValidationError):
        EspecieLiquenCreate(nombre_cientifico="ok", tipo_crecimiento="y" * 51)
    with pytest.raises(ValidationError):
        EspecieLiquenCreate(nombre_cientifico="ok", indicador_calidad_aire="y" * 256)


def test_update_normaliza_y_distingue_campos_enviados():
    update = EspecieLiquenUpdate(nombre_cientifico="  Usnea sp.  ", nombre_comun="")
    assert update.nombre_cientifico == "Usnea sp."
    assert update.nombre_comun is None
    assert "nombre_cientifico" in update.model_fields_set
    assert "nombre_comun" in update.model_fields_set
    assert "descripcion" not in update.model_fields_set


def test_update_rechaza_nombre_solo_espacios():
    with pytest.raises(ValidationError):
        EspecieLiquenUpdate(nombre_cientifico="   ")


def test_update_acepta_none_y_vacio():
    update_vacio = EspecieLiquenUpdate()
    assert "nombre_cientifico" not in update_vacio.model_fields_set
    update_none = EspecieLiquenUpdate(nombre_cientifico=None, habitat=None)
    assert update_none.nombre_cientifico is None
    assert "habitat" in update_none.model_fields_set