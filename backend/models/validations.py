
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
    """Validación para creación de ubicación"""
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
    autor: str = Field(..., min_length=2, max_length=150)


class ArticuloUpdate(BaseModel):
    
    titulo: Optional[str] = Field(None, min_length=5, max_length=255)
    contenido: Optional[str] = Field(None, min_length=20, max_length=50000)
    categoria: Optional[str] = Field(None, min_length=3, max_length=100)
    estado_publicacion: Optional[str] = Field(None, pattern=r'^(draft|published|archived)$')


class ArticuloResponse(BaseModel):
    
    id_articulo: int
    titulo: str
    contenido: str
    categoria: str
    autor: str
    estado_publicacion: str
    fecha_publicacion: datetime
    
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


class RoleResponse(BaseModel):
    
    id_rol: int
    nombre_rol: str
    descripcion: Optional[str]
    nivel_acceso: int
    
    class Config:
        from_attributes = True
