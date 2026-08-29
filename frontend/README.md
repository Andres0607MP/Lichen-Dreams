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

## Configurar conexión con backend

La URL del backend se configura mediante la variable de entorno `API_BASE_URL` usando `--dart-define` al ejecutar la aplicación. También se puede definir mediante variables de entorno en el archivo de lanzamiento según la plataforma.

Ejemplos comunes:

- **Android (emulador):** `--dart-define=API_BASE_URL=http://10.0.2.2:8000`
- **iOS (simulador):** `--dart-define=API_BASE_URL=http://127.0.0.1:8000`
- **Web (Chrome):** `--dart-define=API_BASE_URL=http://127.0.0.1:8000`
- **Windows (desktop):** `--dart-define=API_BASE_URL=http://127.0.0.1:8000`

Además, para el inicio de sesión con Google se debe proporcionar el **Google Client ID** (id de la aplicación web en Google Cloud Console) que debe coincidir con el configurado en el backend:

```bash
flutter run --dart-define=GOOGLE_CLIENT_ID=TU_CLIENT_ID_AQUI
```

## Ejecución

```bash
# Web (Chrome)
flutter run -d chrome

# Windows (desktop)
flutter run -d windows

# Android emulator
flutter run -d emulator

# iOS simulator (requiere macOS)
flutter run -d ios
```

## Estructura

```
lib/
├── config/          # Configuración (URLs, temas, AppConfig)
├── screens/         # Pantallas principales (Login, Dashboard, Análisis, Historial, Mapa, Liquenpedia)
├── services/        # Servicios (API, autenticación, navegación)
├── widgets/         # Componentes reutilizables
└── main.dart        # Punto de entrada
```

## Pantallas principales

- **Login:** Autenticación con correo y contraseña, y con Google Sign-In.
- **Dashboard:** Panel principal con acceso rápido a funcionalidades.
- **Análisis:** Captura o selección de imagen, envío al backend para procesamiento con IA y visualización de resultados.
- **Historial:** Consulta de análisis realizados previamente.
- **Mapa:** Visualización de zonas analizadas en un mapa interactivo (Google Maps).
- **Liquenpedia:** Módulo educativo con información sobre líquenes y su importancia como bioindicadores.

## Verificación

```bash
flutter doctor
```

Confirmar que Flutter esté completamente configurado.

## Pruebas

Ejecutar las pruebas unitarias y de widget con:

```bash
flutter test
```

## Assets

Los recursos estáticos (imágenes, íconos, audio) están definidos en `pubspec.yaml` bajo la sección `assets`, incluyendo:

- `assets/logo/`
- `assets/background/`
- `assets/audio/`

## Documentación completa

Ver: `../README.md`
