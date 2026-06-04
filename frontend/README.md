# Frontend — Lichen Dreams

Aplicación móvil Flutter para análisis de líquenes y estimación de calidad del aire.

## Requisitos

- Flutter 3.0+
- Dart 3.0+
- Android SDK (para emulador/dispositivo Android)
- iOS SDK (para macOS/iOS)

## Instalación

### Windows/Linux/macOS

```bash
flutter pub get
```

### Configurar conexión con backend

En `lib/config/app_config.dart`, la URL del backend se configura dinámicamente:

- **Android (emulador):** `http://10.0.2.2:8000`
- **Web/Desktop:** `http://127.0.0.1:8000`

O con parámetro:

```bash
flutter run --dart-define=API_BASE_URL=http://tu-ip:8000
```

## Ejecución

```bash
# Web (Chrome)
flutter run -d chrome

# Windows (desktop)
flutter run -d windows

# Android emulator
flutter run -d emulator
```

## Estructura

```
lib/
├── config/          # Configuración (URLs, temas)
├── routes/          # Rutas de navegación
├── screens/         # Pantallas principales
├── services/        # Servicios (API, autenticación)
├── widgets/         # Componentes reutilizables
└── main.dart        # Punto de entrada
```

## Pantallas principales

- **Login:** Autenticación con correo y contraseña
- **Dashboard:** Panel principal con funcionalidades
- **Análisis:** Captura y análisis de imágenes
- **Historial:** Consulta de análisis anteriores
- **Mapa:** Visualización de zonas analizadas
- **Liquenpedia:** Módulo educativo

## Verificación

```bash
flutter doctor
```

Confirmar que Flutter esté completamente configurado.

## Documentación completa

Ver: `../README.md`
