
from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional, List
from datetime import datetime


class UsuarioCreate(BaseModel):
    
    nombre: str = Field(..., min_length=2, max_length=100)
    apellido: str = Field(..., min_length=2, max_length=100)
    correo: EmailStr
    contrasena: str = Field(..., min_length=8, max_length=255)
    telefono: Optional[str] = Field(None, pattern=r'^\+?1?\d{9,15}$')
    
    @field_validator('contrasena')
    @classmethod
    def validar_contrasena(cls, v):
        
        if not any(c.isupper() for c in v):
            raise ValueError('Contraseña debe tener al menos una mayúscula')
        if not any(c.isdigit() for c in v):
            raise ValueError('Contraseña debe tener al menos un número')
        if not any(not c.isalnum() for c in v):
            raise ValueError('Contraseña debe tener al menos un carácter especial')
        return v


class UsuarioUpdate(BaseModel):
    
    nombre: Optional[str] = Field(None, min_length=2, max_length=100)
    apellido: Optional[str] = Field(None, min_length=2, max_length=100)
    correo: Optional[EmailStr] = None
    telefono: Optional[str] = Field(None, pattern=r'^\+?1?\d{9,15}$')


class UsuarioResponse(BaseModel):
    
    id_usuario: int
    nombre: str
    apellido: str
    correo: str
    telefono: Optional[str] = None
    fecha_registro: datetime
    estado_activo: bool
    
    class Config:
        from_attributes = True


class UbicacionCreate(BaseModel):
   
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)
    direccion: str = Field(..., min_length=5, max_length=255)
    municipio: str = Field(..., min_length=2, max_length=100)
    departamento: str = Field(..., min_length=2, max_length=100)
    pais: str = Field(default="Colombia", min_length=2, max_length=100)


class UbicacionResponse(BaseModel):
   
    id_ubicacion: int
    latitud: float
    longitud: float
    direccion: str
    municipio: str
    departamento: str
    pais: str
    fecha_registro: datetime
    
    class Config:
        from_attributes = True


class AnalisisCreate(BaseModel):
    
    id_modelo: int = Field(..., gt=0)
    id_dataset: Optional[int] = Field(None, gt=0)
    metadata_adicional: Optional[dict] = None


class AnalisisResponse(BaseModel):
   
    id_analisis: int
    id_usuario: int
    id_modelo: int
    resultado: Optional[dict] = None
    estado: str
    fecha_creacion: datetime
    
    class Config:
        from_attributes = True


class ArticuloCreate(BaseModel):
 
    titulo: str = Field(..., min_length=5, max_length=255)
    contenido: str = Field(..., min_length=20, max_length=50000)
    categoria: str = Field(..., min_length=3, max_length=100)
    id_categoria: Optional[int] = None
    autor: str = Field(..., min_length=2, max_length=150)
    imagen_articulo: Optional[str] = None
    estado_publicacion: Optional[str] = Field(None, pattern=r'^(draft|published|archived)$')


class ArticuloUpdate(BaseModel):
    
    titulo: Optional[str] = Field(None, min_length=5, max_length=255)
    contenido: Optional[str] = Field(None, min_length=20, max_length=50000)
    categoria: Optional[str] = Field(None, min_length=3, max_length=100)
    id_categoria: Optional[int] = None
    autor: Optional[str] = Field(None, min_length=2, max_length=150)
    imagen_articulo: Optional[str] = None
    estado_publicacion: Optional[str] = Field(None, pattern=r'^(draft|published|archived)$')


class ArticuloResponse(BaseModel):
    
    id_articulo: int
    titulo: str
    contenido: str
    categoria: str
    id_categoria: Optional[int] = None
    categoria_nombre: Optional[str] = None
    autor: str
    estado_publicacion: str
    fecha_publicacion: datetime
    
    class Config:
        from_attributes = True


class CategoriaArticuloCreate(BaseModel):
    nombre_categoria: str = Field(..., min_length=2, max_length=100)
    descripcion: Optional[str] = None
    color: Optional[str] = Field(None, pattern=r'^#[0-9A-Fa-f]{6}$')
    icono: Optional[str] = None
    orden: Optional[int] = 0


class CategoriaArticuloUpdate(BaseModel):
    nombre_categoria: Optional[str] = Field(None, min_length=2, max_length=100)
    descripcion: Optional[str] = None
    color: Optional[str] = Field(None, pattern=r'^#[0-9A-Fa-f]{6}$')
    icono: Optional[str] = None
    orden: Optional[int] = None
    activo: Optional[bool] = None


class CategoriaArticuloResponse(BaseModel):
    id_categoria: int
    nombre_categoria: str
    descripcion: Optional[str] = None
    color: Optional[str] = None
    icono: Optional[str] = None
    orden: int = 0
    activo: bool = True

    class Config:
        from_attributes = True


class DatasetCreate(BaseModel):
   
    nombre_dataset: str = Field(..., min_length=3, max_length=150)
    tipo_datos: str = Field(..., min_length=2, max_length=50)
    descripcion: Optional[str] = None


class DatasetResponse(BaseModel):
   
    id_dataset: int
    nombre_dataset: str
    ruta_archivo: str
    tipo_datos: str
    fecha_creacion: datetime
    
    class Config:
        from_attributes = True

class ModeloIACreate(BaseModel):

    nombre_modelo: str = Field(..., min_length=3, max_length=150)
    version: str = Field(..., pattern=r'^\d+\.\d+\.\d+$')  # Semver: X.Y.Z
    descripcion: Optional[str] = None


class ModeloIAResponse(BaseModel):
    
    id_modelo: int
    nombre_modelo: str
    version: str
    descripcion: Optional[str] = None
    fecha_creacion: datetime
    
    class Config:
        from_attributes = True



class SesionResponse(BaseModel):
    
    id_sesion: int
    token_sesion: str
    dispositivo: Optional[str]
    ip_usuario: Optional[str]
    fecha_inicio: datetime
    estado_sesion: str
    
    class Config:
        from_attributes = True


class MapPointResponse(BaseModel):
    id: int
    id_usuario: int
    lat: float
    lng: float
    zone_name: str
    air_quality: str
    contamination_level: Optional[str] = None
    species: str
    confidence: float
    date: datetime
    status: str
    visibilidad: str = "private"
    usuario: Optional[dict] = None
    analysis_count: int = 1
    analyses: List[dict] = []

    class Config:
        from_attributes = True


class RoleResponse(BaseModel):

    id_rol: int
    nombre_rol: str
    descripcion: Optional[str]
    nivel_acceso: int

    class Config:
        from_attributes = True


class EspecieLiquenCreate(BaseModel):
    nombre_cientifico: str = Field(..., min_length=1, max_length=100)
    nombre_comun: Optional[str] = Field(None, max_length=100)
    descripcion: Optional[str] = Field(None, max_length=4000)
    color_predominante: Optional[str] = Field(None, max_length=50)
    tipo_crecimiento: Optional[str] = Field(None, max_length=50)
    nivel_tolerancia_contaminacion: Optional[str] = Field(None, max_length=100)
    indicador_calidad_aire: Optional[str] = Field(None, max_length=255)
    habitat: Optional[str] = Field(None, max_length=100)
    imagen_referencia: Optional[str] = Field(None, max_length=4000)

    @field_validator('nombre_cientifico')
    @classmethod
    def _nombre_cientifico_no_vacio(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError('El nombre científico no puede estar vacío ni contener solo espacios')
        return v

    @field_validator(
        'nombre_comun',
        'descripcion',
        'color_predominante',
        'tipo_crecimiento',
        'nivel_tolerancia_contaminacion',
        'indicador_calidad_aire',
        'habitat',
        'imagen_referencia',
        mode='before',
    )
    @classmethod
    def _normalizar_opcionales(cls, v):
        if isinstance(v, str):
            v = v.strip()
            return v if v else None
        return v


class EspecieLiquenUpdate(BaseModel):
    nombre_cientifico: Optional[str] = Field(None, min_length=1, max_length=100)
    nombre_comun: Optional[str] = Field(None, max_length=100)
    descripcion: Optional[str] = Field(None, max_length=4000)
    color_predominante: Optional[str] = Field(None, max_length=50)
    tipo_crecimiento: Optional[str] = Field(None, max_length=50)
    nivel_tolerancia_contaminacion: Optional[str] = Field(None, max_length=100)
    indicador_calidad_aire: Optional[str] = Field(None, max_length=255)
    habitat: Optional[str] = Field(None, max_length=100)
    imagen_referencia: Optional[str] = Field(None, max_length=4000)

    @field_validator('nombre_cientifico')
    @classmethod
    def _nombre_cientifico_no_vacio(cls, v):
        if v is not None:
            v = v.strip()
            if not v:
                raise ValueError('El nombre científico no puede estar vacío ni contener solo espacios')
        return v

    @field_validator(
        'nombre_comun',
        'descripcion',
        'color_predominante',
        'tipo_crecimiento',
        'nivel_tolerancia_contaminacion',
        'indicador_calidad_aire',
        'habitat',
        'imagen_referencia',
        mode='before',
    )
    @classmethod
    def _normalizar_opcionales(cls, v):
        if isinstance(v, str):
            v = v.strip()
            return v if v else None
        return v


class EspecieLiquenResponse(BaseModel):
    id_especie: int
    nombre_cientifico: Optional[str] = None
    nombre_comun: Optional[str] = None
    descripcion: Optional[str] = None
    color_predominante: Optional[str] = None
    tipo_crecimiento: Optional[str] = None
    nivel_tolerancia_contaminacion: Optional[str] = None
    indicador_calidad_aire: Optional[str] = None
    habitat: Optional[str] = None
    imagen_referencia: Optional[str] = None
    fecha_registro: datetime

    class Config:
        from_attributes = True


class ZonaAmbientalCreate(BaseModel):
    nombre_zona: str = Field(..., min_length=2, max_length=100)
    nivel_riesgo: Optional[str] = None
    calidad_promedio_aire: Optional[str] = None
    descripcion: Optional[str] = None


class ZonaAmbientalUpdate(BaseModel):
    nombre_zona: Optional[str] = Field(None, min_length=2, max_length=100)
    nivel_riesgo: Optional[str] = None
    calidad_promedio_aire: Optional[str] = None
    descripcion: Optional[str] = None


class ZonaAmbientalResponse(BaseModel):
    id_zona: int
    nombre_zona: Optional[str] = None
    nivel_riesgo: Optional[str] = None
    calidad_promedio_aire: Optional[str] = None
    descripcion: Optional[str] = None
    fecha_actualizacion: Optional[datetime] = None

    class Config:
        from_attributes = True


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordResetConfirm(BaseModel):
    token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password_strength(cls, value: str) -> str:
        if len(value) < 6:
            raise ValueError("La contraseña debe tener al menos 6 caracteres")
        if not any(not ch.isalnum() for ch in value):
            raise ValueError("La contraseña debe incluir al menos un carácter especial")
        return value


class PasswordResetResponse(BaseModel):
    message: str


class EmailVerificationRequest(BaseModel):
    email: EmailStr


class EmailVerificationConfirm(BaseModel):
    token: str


class RegisterResponse(BaseModel):
    message: str
    email: str
