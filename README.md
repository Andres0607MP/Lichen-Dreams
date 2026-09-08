# Proyecto:

## Lichen-Dreams

### Descripción:

Lichen Dreams es una aplicación móvil desarrollada por aprendices del programa ADSO del SENA, cuyo objetivo es ayudar a las personas a conocer la calidad del aire de su entorno mediante el análisis de líquenes, organismos naturales que funcionan como bioindicadores ambientales.

La aplicación utiliza Inteligencia Artificial y visión artificial para analizar fotografías tomadas desde el celular. El sistema identifica si la imagen corresponde a un líquen y, según su estado y características, estima el nivel de contaminación ambiental del lugar. Además, registra la ubicación GPS para mostrar zonas con mejor o peor calidad del aire en mapas interactivos.

El proyecto busca solucionar el desconocimiento de la población sobre la contaminación ambiental y facilitar el acceso a información ecológica de manera sencilla y tecnológica. También incluye un módulo educativo llamado Liquenpedia, donde los usuarios pueden aprender sobre líquenes y su importancia en el ecosistema.

### Integrantes:

- Hugo Andres Mancera Perez
- Daniel Camilo Luque Briceño
- Saira Yineth Aragon Suarez
- Neyireth Dayana Soriano Ruiz
- Heidy Lizeth Vivas Ramirez

### Tecnologías Utilizadas:

Frontend: Flutter
Backend: FastAPI + Python
Base de Datos: MySQL
ORM: SQLAlchemy
IA y Visión Artificial: TensorFlow, Keras y OpenCV
Autenticación: JWT + Passlib
APIs externas: Google Maps API
Control de versiones: GitHub

### Estructura del Proyecto:

```
proyecto/
├── backend/
│   ├── alembic/
│   │   ├── versions/
│   │   ├── env.py
│   │   └── script.py.mako
│   ├── auth/
│   ├── config/
│   ├── ia/
│   │   ├── datasets/
│   │   ├── entrenamiento/
│   │   └── modelos/
│   ├── models/
│   ├── routes/
│   ├── scripts/
│   └── tests/
├── database/
│   └── scripts/
├── docs/
│   ├── database-schema.md
│   ├── git-workflow.md
│   └── reporte_calidad_inicial.md
└── frontend/
    ├── lib/
    │   ├── config/
    │   ├── screens/
    │   ├── services/
    │   └── widgets/
    ├── test/
    ├── web/
    ├── android/
    ├── ios/
    ├── linux/
    ├── macos/
    └── windows/
    └── assets/
```

### Objetivo del sistema:

Desarrollar una aplicación móvil multiplataforma que permita identificar líquenes mediante Inteligencia Artificial y visión artificial, con el fin de analizar y estimar la calidad del aire en diferentes zonas geográficas.

El sistema busca facilitar el monitoreo ambiental ciudadano a través de la captura y análisis de imágenes, integrando funciones de geolocalización, mapas interactivos y contenido educativo para promover la conciencia ecológica y el cuidado del medio ambiente.
### Estado actual de la inteligencia artificial:

El modelo activo de produccion es la version **V8** (clasificador ambiental de tres clases: liquen saludable, liquen contaminado y liquen desconocido). Cuando la IA clasifica una imagen como desconocida, el sistema informa al usuario y evita registrar el analisis. Las versiones futuras del modelo (por ejemplo V9) son parte de la evolucion posterior al despliegue y no son el modelo activo.

### Instalacion y configuracion:

Para clonar, configurar y ejecutar el proyecto desde cero sigue la guia **SETUP.md** (ver raiz del repositorio). Alli se detallan requisitos, backend/.env, base de datos MySQL, migraciones, backend, frontend Flutter, conexion app-backend, configuracion de Google (Sign-In y Maps) y una checklist de instalacion.
