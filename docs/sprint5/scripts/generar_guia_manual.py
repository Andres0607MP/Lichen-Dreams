# -*- coding: utf-8 -*-
"""Genera GUIA_EVIDENCIAS_MANUALES.txt (Sprint 5) y crea evidencias/manuales/.

Caso a caso indica qué hacer en la aplicación Android, en qué momento tomar
el pantallazo y con qué nombre guardarlo. No inventa capturas ni resultados.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT_TXT = ROOT / "docs" / "sprint5" / "GUIA_EVIDENCIAS_MANUALES.txt"
MANUALES = ROOT / "docs" / "sprint5" / "evidencias" / "manuales"
MANUALES.mkdir(parents=True, exist_ok=True)

PIE_FINAL = """RESULTADO A REGISTRAR:
Completar únicamente después de ejecutar realmente la prueba.

ESTADO:
[ ] Aprobado
[ ] Fallido
[ ] Bloqueado
[ ] No ejecutado

OBSERVACIÓN:
No marcar Aprobado únicamente porque el endpoint/API funcione. Debe existir
evidencia visual real si el caso se presenta como prueba manual de la aplicación.

----------------------------------------------------------------------"""


def block(caso, nombre, modulo, objetivo, pre, pasos, momento, captura, sugerido, obs=""):
    s = f"""
======================================================================
CASO: {caso}
NOMBRE: {nombre}
MÓDULO: {modulo}
======================================================================

OBJETIVO:
{objetivo}

PRECONDICIONES:
"""
    for p in pre:
        s += f"* {p}\n"
    s += "\nPASOS:\n"
    for i, p in enumerate(pasos, start=1):
        s += f"{i}. {p}\n"
    s += f"""
MOMENTO EXACTO PARA TOMAR CAPTURA:
{momento}

CAPTURA RECOMENDADA:
{captura}

NOMBRE SUGERIDO:
`{sugerido}`
"""
    if obs:
        s += f"\nOBSERVACIÓN ESPECÍFICA:\n{obs}\n"
    s += "\n" + PIE_FINAL + "\n"
    return s


B = []

# =====================================================================
# MÓDULO 1 — AUTENTICACIÓN Y GESTIÓN DE USUARIO
# =====================================================================
B.append("MODULO 1 — AUTENTICACIÓN Y GESTIÓN DE USUARIO\n" + "=" * 60)
B.append(block(
    "M1-01", "Registro exitoso", "Autenticación",
    "Validar que un usuario nuevo pueda registrarse correctamente en la aplicación.",
    ["Aplicación instalada y ejecutándose.", "Backend FastAPI disponible.", "Correo de prueba no registrado previamente."],
    ["Abrir la aplicación en la pantalla de inicio/login.",
     "Tocar «Crear una cuenta» (registro).",
     "Completar nombre, apellido, correo y contraseña (mínimo 6 caracteres y un carácter especial); confirmar contraseña.",
     "Pulsar «Crear cuenta».",
     "Esperar la pantalla de confirmación de cuenta."],
    "Cuando aparezca la pantalla con el mensaje de éxito (p. ej. «¡Tu cuenta está lista!») y se muestre el código de recuperación LCHN.",
    "La captura debe mostrar la pantalla posterior al registro con el código de recuperación visible.",
    "M1-01_registro_exitoso.png",
))
B.append(block(
    "M1-02", "Registro con correo inválido", "Autenticación",
    "Validar que el formulario rechace un correo mal formado.",
    ["Aplicación en la pantalla de registro."],
    ["Ir a la pantalla de registro.",
     "Ingresar un correo sin formato válido (sin «@»).",
     "Completar el resto de campos obligatorios.",
     "Intentar crear la cuenta."],
    "Cuando la aplicación muestre el mensaje de validación sobre el campo de correo (error visible bajo el campo o bloqueo del envío).",
    "La captura debe mostrar el campo de correo con el mensaje de error de validación.",
    "M1-02_registro_correo_invalido.png",
))
B.append(block(
    "M1-03", "Registro con contraseña débil", "Autenticación",
    "Validar la regla de contraseña mínima (6 caracteres y carácter especial).",
    ["Aplicación en la pantalla de registro."],
    ["Ir a la pantalla de registro.",
     "Ingresar una contraseña corta (menos de 6 caracteres) o sin carácter especial.",
     "Intentar crear la cuenta."],
    "Cuando la aplicación muestre el mensaje de validación de la contraseña.",
    "La captura debe mostrar el campo de contraseña con el mensaje de error.",
    "M1-03_registro_password_debil.png",
))
B.append(block(
    "M1-04", "Registro con correo duplicado", "Autenticación",
    "Validar que un correo ya registrado sea rechazado.",
    ["Existe una cuenta con el correo a probar.", "Aplicación en la pantalla de registro."],
    ["Ir a la pantalla de registro.",
     "Ingresar un correo ya registrado.",
     "Completar contraseña y confirmación.",
     "Intentar crear la cuenta."],
    "Cuando la aplicación muestre el mensaje de error del servidor (p. ej. «Usuario ya existe»).",
    "La captura debe mostrar el mensaje de error de correo duplicado.",
    "M1-04_registro_correo_duplicado.png",
))
B.append(block(
    "M1-05", "Registro con campos obligatorios vacíos", "Autenticación",
    "Validar que el formulario exija los campos obligatorios.",
    ["Aplicación en la pantalla de registro."],
    ["Ir a la pantalla de registro.",
     "Dejar los campos vacíos.",
     "Pulsar «Crear cuenta»."],
    "Cuando la aplicación muestre los mensajes de validación de campos obligatorios.",
    "La captura debe mostrar los campos con mensajes de error de campos obligatorios.",
    "M1-05_registro_campos_vacios.png",
))
B.append(block(
    "M1-06", "Login exitoso", "Autenticación",
    "Validar que un usuario registrado inicie sesión correctamente.",
    ["Usuario de prueba registrado.", "Backend disponible.", "Aplicación abierta en Login."],
    ["Abrir la aplicación en la pantalla de Login.",
     "Introducir correo válido.",
     "Introducir contraseña válida.",
     "Pulsar «Iniciar sesión»."],
    "Cuando la aplicación haya ingresado correctamente al Dashboard/pantalla principal.",
    "La captura debe mostrar la interfaz de la aplicación después del login exitoso.",
    "M1-06_login_exitoso.png",
))
B.append(block(
    "M1-07", "Login con contraseña incorrecta", "Autenticación",
    "Validar que una contraseña incorrecta sea rechazada.",
    ["Usuario de prueba existente.", "Aplicación en Login."],
    ["Ingresar correo válido.",
     "Ingresar contraseña incorrecta.",
     "Pulsar «Iniciar sesión»."],
    "Cuando la aplicación muestre el mensaje de error (p. ej. «Credenciales inválidas») y permanezca en Login.",
    "La captura debe mostrar el mensaje de error de credenciales.",
    "M1-07_login_password_incorrecta.png",
))
B.append(block(
    "M1-08", "Login con usuario inexistente", "Autenticación",
    "Validar que un correo no registrado sea rechazado.",
    ["Aplicación en Login."],
    ["Ingresar un correo no registrado.",
     "Ingresar una contraseña cualquiera.",
     "Pulsar «Iniciar sesión»."],
    "Cuando la aplicación muestre el mensaje de error de credenciales (respuesta genérica) y permanezca en Login.",
    "La captura debe mostrar el mensaje de error.",
    "M1-08_login_usuario_inexistente.png",
))
B.append(block(
    "M1-09", "Login con campos vacíos", "Autenticación",
    "Validar que el formulario de login no permita el envío vacío.",
    ["Aplicación en Login."],
    ["Dejar los campos vacíos.",
     "Pulsar «Iniciar sesión»."],
    "Cuando la aplicación muestre la validación de campos vacíos (mensajes o botón deshabilitado).",
    "La captura debe mostrar los campos vacíos con su validación.",
    "M1-09_login_campos_vacios.png",
))
B.append(block(
    "M1-10", "Sesión / autenticación válida", "Autenticación",
    "Validar que la sesión se mantenga activa después del inicio de sesión.",
    ["Sesión previamente iniciada."],
    ["Iniciar sesión.",
     "Cerrar y reabrir la aplicación (o navegar entre pantallas protegidas) sin volver a iniciar sesión."],
    "Cuando la aplicación reabra en una pantalla autenticada (Dashboard/Historial) sin solicitar credenciales de nuevo.",
    "La captura debe mostrar una pantalla autenticada con la sesión vigente.",
    "M1-10_sesion_valida.png",
))
B.append(block(
    "M1-12", "Recuperación de contraseña por correo (solicitud)", "Autenticación",
    "Validar la solicitud de recuperación mediante correo electrónico.",
    ["Correo de prueba registrado.", "Pantalla de recuperación accesible."],
    ["En Login tocar «¿Olvidaste tu contraseña?».",
     "Ingresar el correo registrado.",
     "Pulsar enviar/recuperar."],
    "Cuando la aplicación muestre el mensaje de confirmación de la solicitud (respuesta genérica).",
    "La captura debe mostrar el mensaje de confirmación de la solicitud de recuperación.",
    "M1-12_recuperacion_correo_solicitud.png",
))
B.append(block(
    "M1-13", "Recuperación con código LCHN (válido)", "Autenticación",
    "Validar el restablecimiento de contraseña con el código de recuperación de un solo uso.",
    ["Código LCHN vigente (entregado en el registro o regenerado).", "Pantalla de recuperación con código."],
    ["Ir a la pantalla de recuperación de contraseña.",
     "Introducir el código LCHN.",
     "Ingresar la nueva contraseña y su confirmación.",
     "Confirmar el restablecimiento.",
     "Iniciar sesión con la nueva contraseña."],
    "En dos momentos: (1) cuando la aplicación confirme que la contraseña fue actualizada; (2) cuando el login con la nueva contraseña acceda a la aplicación.",
    "La captura debe mostrar la confirmación del restablecimiento y/o el acceso posterior con la nueva contraseña.",
    "M1-13_recuperacion_lchn_valido.png",
))
B.append(block(
    "M1-14", "Código inválido en recuperación", "Autenticación",
    "Validar el rechazo de un código de recuperación incorrecto.",
    ["Pantalla de recuperación con código."],
    ["Ir a la pantalla de recuperación.",
     "Introducir un código incorrecto.",
     "Confirmar."],
    "Cuando la aplicación muestre el mensaje de error (p. ej. «Código inválido o expirado»).",
    "La captura debe mostrar el mensaje de error del código.",
    "M1-14_codigo_invalido.png",
))
B.append(block(
    "M1-15", "Login con nueva contraseña", "Autenticación",
    "Validar que la nueva contraseña (tras recuperación/cambio) permite el acceso.",
    ["Contraseña previamente restablecida o cambiada."],
    ["Cerrar sesión si está activa.",
     "Ir a Login.",
     "Ingresar correo y la nueva contraseña.",
     "Pulsar «Iniciar sesión»."],
    "Cuando la aplicación acceda correctamente al Dashboard con la nueva contraseña.",
    "La captura debe mostrar el acceso exitoso tras usar la nueva contraseña.",
    "M1-15_login_nueva_password.png",
))
B.append(block(
    "M1-16", "Perfil: carga de datos", "Perfil",
    "Validar que el perfil se muestre con los datos del usuario autenticado.",
    ["Sesión iniciada."],
    ["Abrir el menú de la aplicación.",
     "Ir a «Perfil»."],
    "Cuando la pantalla de perfil muestre los datos del usuario (nombre, correo, etc.).",
    "La captura debe mostrar la pantalla de perfil con los datos reales del usuario.",
    "M1-16_perfil_carga.png",
))
B.append(block(
    "M1-17", "Perfil: actualización de datos", "Perfil",
    "Validar la actualización de datos del perfil.",
    ["Sesión iniciada.", "Estar en la pantalla de perfil."],
    ["Editar un dato del perfil (p. ej. nombre o teléfono).",
     "Guardar los cambios.",
     "Revisar que el dato quede reflejado."],
    "Cuando la aplicación confirme el guardado y la pantalla muestre el dato actualizado.",
    "La captura debe mostrar el perfil con los datos actualizados.",
    "M1-17_perfil_actualizacion.png",
))
B.append(block(
    "M1-18", "Perfil: correo inválido", "Perfil",
    "Validar el rechazo de un correo mal formado al editar el perfil.",
    ["Sesión iniciada.", "Estar en la pantalla de perfil en modo edición."],
    ["Editar el correo ingresando un formato inválido.",
     "Intentar guardar."],
    "Cuando la aplicación muestre el mensaje de validación del correo.",
    "La captura debe mostrar el error de validación del correo en el perfil.",
    "M1-18_perfil_correo_invalido.png",
))
B.append("""
CASO: M1-19
NOMBRE: Google Sign-In (contrato backend)
MÓDULO: Autenticación
---------------------

OBJETIVO:
Documentar la cobertura del flujo de Google Sign-In a nivel de backend
(tokens simulados), validada mediante la suite automatizada (18 pruebas).

PRECONDICIONES:
* No aplica captura de la aplicación: no existió una ejecución real del flujo
  de Google en dispositivo durante el Sprint 5.

PASOS:
N/A (no se solicita una captura de la app).

MOMENTO EXACTO PARA TOMAR CAPTURA:
No se toma captura de la aplicación para este caso.

CAPTURA RECOMENDADA:
Evidencia técnica (suite backend): backend/tests/test_google_auth.py

NOMBRE SUGERIDO:
Sin captura manual.

RESULTADO A REGISTRAR:
Evidencia técnica automatizada (18/18 pruebas aprobadas).

ESTADO:
[ ] Aprobado (solo si se respalda con la suite)
[ ] Fallido
[ ] Bloqueado
[ ] No ejecutado (flujo de dispositivo)

OBSERVACIÓN:
No marcar como prueba manual de la aplicación si no existe captura real.

----------------------------------------------------------------------""")
B.append("""
CASO: M1-20
NOMBRE: Google Sign-In en dispositivo
MÓDULO: Autenticación
---------------------

OBJETIVO:
Validar el inicio de sesión con Google desde la aplicación Android.

ESTADO:
NO EJECUTADO / FUERA DEL ALCANCE DEL CONJUNTO DE PRUEBAS EJECUTADO

OBSERVACIÓN:
Requeriría credenciales OAuth configuradas para el dispositivo y una
ejecución real del flujo en la app. No se inventa evidencia.

----------------------------------------------------------------------""")
B.append("""
CASO: M1-21
NOMBRE: Cambio de contraseña / cierre de sesión
MÓDULO: Autenticación
---------------------

OBJETIVO:
Validar el cambio de contraseña y el cierre de sesión desde la aplicación.

PRECONDICIONES:
* Sesión iniciada.
* Pantalla de opciones de cuenta accesible.

PASOS:
1. Ir a la configuración/ajustes de la cuenta (o menú de usuario).
2. Seleccionar «Cambiar contraseña».
3. Ingresar contraseña actual y nueva (mínimo 6 caracteres y un carácter especial); confirmar.
4. Guardar y verificar la confirmación.
5. (Opcional) Cerrar sesión desde el menú.

MOMENTO EXACTO PARA TOMAR CAPTURA:
Cuando la aplicación confirme el cambio de contraseña, y/o cuando confirme el cierre de sesión.

CAPTURA RECOMENDADA:
Pantalla de confirmación del cambio de contraseña (y opcionalmente pantalla de login tras cerrar sesión).

NOMBRE SUGERIDO:
M1-21_cambio_contrasena_cierre.png

RESULTADO A REGISTRAR:
Completar únicamente después de ejecutar realmente la prueba.

ESTADO:
[ ] Aprobado
[ ] Fallido
[ ] Bloqueado
[ ] No ejecutado

OBSERVACIÓN:
La revocación de sesiones cuenta con cobertura automatizada del backend
(test_auth_sessions/test_recovery_code); la captura manual es complementaria.

----------------------------------------------------------------------""")
B.append("""
CASO: M1-22
NOMBRE: Administración de usuarios (UI administrador)
MÓDULO: Autenticación / Administración
---------------------

OBJETIVO:
Validar la gestión administrativa de usuarios desde la interfaz correspondiente.

ESTADO:
NO EJECUTADO / FUERA DEL ALCANCE DEL CONJUNTO DE PRUEBAS EJECUTADO

OBSERVACIÓN:
La UI administrativa no fue probada en la aplicación durante el Sprint 5. Los
endpoints de administración existen en el backend, pero no se solicita una
captura de una UI que no fue realmente ejercitada.

----------------------------------------------------------------------""")

# =====================================================================
# MÓDULO 2 — CAPTURA Y ANÁLISIS DE IMÁGENES CON IA
# =====================================================================
B.append("\n\nMODULO 2 — CAPTURA Y ANÁLISIS DE IMÁGENES CON IA\n" + "=" * 60)
B.append(block(
    "M2-01", "Subida de imagen válida", "Análisis de imágenes",
    "Validar la selección y carga de una imagen en el flujo de análisis.",
    ["Sesión iniciada.", "Backend disponible.", "Imagen de prueba en la galería del dispositivo."],
    ["Abrir la pantalla de análisis.",
     "Tocar para seleccionar imagen (galería).",
     "Seleccionar una imagen válida y confirmar."],
    "Cuando la imagen aparezca cargada/confirmada en la pantalla de análisis.",
    "La captura debe mostrar la imagen seleccionada en la pantalla de análisis.",
    "M2-01_imagen_seleccionada.png",
))
B.append(block(
    "M2-02", "Análisis de líquen saludable", "Análisis de imágenes / IA",
    "Validar la clasificación de una imagen de líquen saludable.",
    ["Sesión iniciada.", "Imagen real de un líquen saludable (bajo estrés ambiental)."],
    ["Abrir el flujo de análisis.",
     "Seleccionar la imagen del líquen saludable (galería).",
     "Ejecutar el análisis.",
     "Esperar el resultado del modelo."],
    "Cuando la pantalla de resultado muestre la clasificación y la confianza para el caso saludable.",
    "La captura debe mostrar el resultado del análisis con su clasificación.",
    "M2-02_analisis_liquen_saludable.png",
))
B.append(block(
    "M2-03", "Análisis de imagen que no es un líquen", "Análisis de imágenes / IA",
    "Validar el comportamiento con una imagen que no corresponde a un líquen.",
    ["Sesión iniciada.", "Foto de algo que no es un líquen (textura, superficie, objeto)."],
    ["Abrir el flujo de análisis.",
     "Seleccionar la imagen no-líquen.",
     "Ejecutar el análisis.",
     "Esperar el resultado."],
    "Cuando la pantalla de resultado muestre la clasificación real (en el modelo de 3 clases derivará a «liquen desconocido»).",
    "La captura debe mostrar el resultado realmente obtenido (no asumir: registrar el que aparezca).",
    "M2-03_analisis_imagen_no_liquen.png",
))
B.append(block(
    "M2-04", "Análisis sin imagen", "Análisis de imágenes",
    "Validar que no se pueda ejecutar el análisis sin seleccionar una imagen.",
    ["Sesión iniciada.", "Pantalla de análisis sin imagen seleccionada."],
    ["Intentar iniciar el análisis sin seleccionar ninguna imagen."],
    "Cuando la aplicación muestre el mensaje de validación/error correspondiente.",
    "La captura debe mostrar el mensaje de validación real.",
    "M2-04_analisis_sin_imagen.png",
))
B.append(block(
    "M2-05", "Análisis desde cámara sin ubicación", "Análisis de imágenes",
    "Validar el mensaje de la aplicación cuando falta ubicación para análisis por cámara.",
    ["Sesión iniciada.", "Poder reproducir el escenario sin ubicación (p. ej. GPS desactivado)."],
    ["Elegir análisis desde cámara.",
     "Capturar la foto.",
     "Continuar sin ubicación válida (GPS desactivado o sin permiso)."],
    "Cuando la aplicación muestre el mensaje de ubicación requerida.",
    "La captura debe mostrar el mensaje real de la aplicación.",
    "M2-05_camara_sin_ubicacion.png",
    obs="Si el escenario no puede reproducirse realmente, mantener el estado NO EJECUTADO / FUERA DEL ALCANCE y no inventar el mensaje.",
))
B.append(block(
    "M2-06", "Análisis persistido con ubicación", "Análisis de imágenes / Ubicación",
    "Validar el análisis con ubicación y su persistencia.",
    ["Sesión iniciada.", "GPS activo y permisos de ubicación concedidos."],
    ["Abrir el flujo de análisis desde cámara (o galería con ubicación).",
     "Capturar/seleccionar la imagen de un líquen.",
     "Confirmar la ubicación.",
     "Ejecutar el análisis y esperar el resultado."],
    "Cuando la pantalla de resultado muestre el análisis completado con su ubicación asociada.",
    "La captura debe mostrar el resultado del análisis con la información ambiental y de ubicación.",
    "M2-06_analisis_ubicacion.png",
))
B.append(block(
    "M2-07", "Consulta de resultado persistido", "Historial / Resultados",
    "Validar que un análisis guardado pueda consultarse nuevamente.",
    ["Existe al menos un análisis guardado."],
    ["Ir a Historial.",
     "Abrir el análisis guardado."],
    "Cuando la pantalla muestre el detalle/resultado del análisis seleccionado.",
    "La captura debe mostrar el detalle del análisis desde el historial.",
    "M2-07_resultado_persistido.png",
))
B.append(block(
    "M2-08", "Estado del análisis (completed)", "Resultados",
    "Validar que el análisis aparezca en estado completado.",
    ["Existe un análisis guardado."],
    ["Ir a Historial o abrir el análisis.",
     "Verificar que el estado sea «completado»."],
    "Cuando el análisis muestre el estado completado junto a su resultado.",
    "La captura debe mostrar el análisis con su estado completado.",
    "M2-08_estado_analisis_completado.png",
))
B.append("""
CASO: M2-09
NOMBRE: Inferencias del modelo IA (3 clases + no-líquen)
MÓDULO: IA
---------------------

OBJETIVO:
Ejecutar el análisis sobre muestras reales (saludable, contaminado,
desconocido y no-líquen) y registrar los resultados.

PRECONDICIONES:
* Sesión iniciada.
* Disponer de al menos una muestra de cada caso (o imágenes del dataset del
  proyecto: backend/ia/datasets/).

PASOS:
1. Ejecutar el análisis para una muestra saludable y capturar el resultado.
2. Ejecutar el análisis para una muestra contaminada y capturar el resultado.
3. Ejecutar el análisis para una muestra desconocida y capturar el resultado.
4. Ejecutar el análisis para una muestra no-líquen y capturar el resultado real.

MOMENTO EXACTO PARA TOMAR CAPTURA:
Tras cada análisis, cuando aparezca la clasificación en pantalla.

CAPTURA RECOMENDADA:
Una captura por cada resultado obtenido (no asumir un resultado específico).

NOMBRE SUGERIDO:
M2-09_inferencia_saludable.png / M2-09_inferencia_contaminado.png /
M2-09_inferencia_desconocido.png / M2-09_inferencia_no_liquen.png

RESULTADO A REGISTRAR:
Registrar la clasificación y confianza realmente mostradas por la aplicación.

ESTADO:
[ ] Aprobado (con capturas reales)
[ ] Fallido
[ ] Bloqueado
[ ] No ejecutado

OBSERVACIÓN:
En el Sprint 5 las inferencias se ejecutaron directamente contra el modelo
(9 inferencias reales + 2 errores controlados, evidencias en evidencias/ia/).
Las capturas de la aplicación son complementarias a esa evidencia técnica.

----------------------------------------------------------------------""")
B.append("""
CASO: M2-10
NOMBRE: Errores controlados del modelo (archivo inexistente/corrupto)
MÓDULO: IA
---------------------

OBJETIVO:
Documentar el manejo de errores del clasificador al recibir entradas inválidas.

ESTADO:
Evidencia técnica (IA/backend) — no requiere captura de la aplicación.

OBSERVACIÓN:
El manejo de errores se validó ejecutando el clasificador con un archivo
inexistente (FileNotFoundError) y uno corrupto (ValueError); evidencia en
ia/resultados_ia.json. No se genera captura de UI para este caso.

----------------------------------------------------------------------""")
B.append("""
CASO: M2-11
NOMBRE: Control de acceso a imágenes (BUG-001)
MÓDULO: Imágenes / Seguridad
---------------------

OBJETIVO:
Documentar la corrección BUG-001 y su revalidación (401/200/204/403).

PRECONDICIONES:
* Evidencia técnica (API): correcciones/resultado_correccion_bug001.json.

PASOS:
1. (Opcional, si la app lo permite) Verificar que un usuario NO ve en la
   aplicación imágenes privadas de otros usuarios (Historial propio).

MOMENTO EXACTO PARA TOMAR CAPTURA:
Solo si se verificó visualmente la restricción en la interfaz; en caso
contrario, mantener la evidencia técnica (API).

CAPTURA RECOMENDADA:
(No es obligatoria) Historial/mis análisis donde solo aparezcan análisis propios.

NOMBRE SUGERIDO:
M2-11_historial_solo_propio.png (opcional)

ESTADO:
[ ] Aprobado (con evidencia técnica 401/200/204/403 revalidada)
[ ] Fallido
[ ] Bloqueado
[ ] No ejecutado

OBSERVACIÓN:
La corrección fue revalidada por API (401/200/204/403) y agregó una prueba de
regresión en backend/tests/test_image_access_control.py. No inventar una
captura de UI si la restricción no fue visualizada.

----------------------------------------------------------------------""")
B.append("""
CASO: M2-13
NOMBRE: Captura con cámara en dispositivo
MÓDULO: Análisis de imágenes
---------------------

OBJETIVO:
Validar la captura de una imagen con la cámara del dispositivo Android.

PRECONDICIONES:
* Dispositivo Android real o emulador con cámara funcional.
* Permiso de cámara concedido.

PASOS:
1. Abrir el flujo de análisis y elegir «Cámara».
2. Tomar la fotografía del liquen.
3. Confirmar la captura (o cancelar al probar el caso negativo).
4. Continuar con el análisis si corresponde.

MOMENTO EXACTO PARA TOMAR CAPTURA:
Cuando la cámara esté abierta y/o cuando la foto confirmada aparezca en la
pantalla de análisis.

CAPTURA RECOMENDADA:
Pantalla de cámara y/o pantalla de análisis con la foto capturada.

NOMBRE SUGERIDO:
M2-13_camara_captura.png

ESTADO:
[ ] Aprobado (únicamente con captura real)
[ ] Fallido
[ ] Bloqueado
[ ] No ejecutado

OBSERVACIÓN:
Si la cámara no fue probada realmente, mantener NO EJECUTADO / FUERA DEL
ALCANCE DEL CONJUNTO DE PRUEBAS EJECUTADO (como se registró en la matriz).

----------------------------------------------------------------------""")
B.append("""
CASO: M2-14
NOMBRE: Selección desde galería en dispositivo
MÓDULO: Análisis de imágenes
---------------------

OBJETIVO:
Validar la selección de una imagen desde la galería del dispositivo.

PRECONDICIONES:
* Dispositivo Android con imágenes en la galería.
* Permiso de almacenamiento/galería concedido.

PASOS:
1. Abrir el flujo de análisis y elegir «Galería».
2. Seleccionar una imagen y confirmar.
3. Observar la imagen cargada en la pantalla de análisis.

MOMENTO EXACTO PARA TOMAR CAPTURA:
Cuando la imagen seleccionada aparezca cargada en la pantalla de análisis.

CAPTURA RECOMENDADA:
Pantalla de análisis con la imagen de la galería seleccionada.

NOMBRE SUGERIDO:
M2-14_galeria_seleccion.png

ESTADO:
[ ] Aprobado (únicamente con captura real)
[ ] Fallido
[ ] Bloqueado
[ ] No ejecutado

OBSERVACIÓN:
Si la galería no fue probada realmente, mantener NO EJECUTADO / FUERA DEL
ALCANCE DEL CONJUNTO DE PRUEBAS EJECUTADO.

----------------------------------------------------------------------""")

# =====================================================================
# MÓDULO 3 — RESULTADOS, HISTORIAL Y REPORTES
# =====================================================================
B.append("\n\nMODULO 3 — RESULTADOS, HISTORIAL Y REPORTES\n" + "=" * 60)
B.append(block(
    "M3-01", "Historial con análisis", "Historial",
    "Validar que el historial muestre los análisis del usuario.",
    ["Existe al menos un análisis guardado."],
    ["Abrir la pestaña/pantalla Historial."],
    "Cuando la lista de análisis se muestre con al menos un elemento.",
    "La captura debe mostrar el historial cargado con análisis.",
    "M3-01_historial_con_analisis.png",
))
B.append(block(
    "M3-02", "Historial vacío", "Historial",
    "Validar el estado de un historial sin análisis.",
    ["Usuario sin análisis registrados."],
    ["Iniciar sesión con un usuario sin análisis.",
     "Abrir la pestaña Historial."],
    "Cuando la pantalla muestre el estado vacío del historial.",
    "La captura debe mostrar el historial vacío con su estado/aviso.",
    "M3-02_historial_vacio.png",
))
B.append(block(
    "M3-03", "Dashboard sincronizado", "Dashboard",
    "Validar que las estadísticas del dashboard se muestren y coincidan con el historial.",
    ["Existe al menos un análisis guardado."],
    ["Abrir la pantalla principal/Dashboard.",
     "Revisar los contadores (total, saludables, afectados, desconocidos, calidad del aire)."],
    "Cuando el dashboard muestre los contadores actualizados.",
    "La captura debe mostrar el dashboard con sus estadísticas.",
    "M3-03_dashboard_sincronizado.png",
))
B.append(block(
    "M3-04", "Consulta de resultado por ID (equivalente en app)", "Resultados",
    "Validar el acceso al detalle de un análisis desde la aplicación.",
    ["Existe un análisis guardado."],
    ["Abrir Historial.",
     "Seleccionar el análisis para ver su detalle (resultado, confianza, humedad, calidad del aire, recomendación)."],
    "Cuando la pantalla muestre el detalle completo del análisis.",
    "La captura debe mostrar el detalle/resultado del análisis.",
    "M3-04_detalle_analisis.png",
))
B.append(block(
    "M3-05", "Eliminación de análisis (UI)", "Historial",
    "Validar la eliminación de un análisis desde el historial.",
    ["Existe al menos un análisis que se pueda eliminar."],
    ["Abrir Historial.",
     "Seleccionar un análisis.",
     "Elegir eliminar (ícono/menú).",
     "Confirmar la eliminación."],
    "Cuando el análisis desaparezca de la lista (tras confirmar).",
    "La captura debe mostrar el historial sin el análisis eliminado (antes/después).",
    "M3-05_eliminacion_analisis.png",
    obs="La eliminación también se validó por backend (test_endpoints, con control de propiedad). La captura manual es complementaria.",
))
B.append(block(
    "M3-06", "Reporte ambiental: generación", "Reportes",
    "Validar la generación de un reporte ambiental.",
    ["Existe al menos un análisis guardado."],
    ["Abrir la pantalla de reportes ambientales.",
     "Generar el reporte."],
    "Cuando el reporte se genere y muestre sus datos (estadísticas del usuario).",
    "La captura debe mostrar el reporte generado.",
    "M3-06_reporte_generado.png",
))
B.append(block(
    "M3-07", "Reporte: listado", "Reportes",
    "Validar el listado de reportes.",
    ["Al menos un reporte existente."],
    ["Abrir la pantalla de reportes.",
     "Revisar la lista de reportes."],
    "Cuando la lista muestre los reportes existentes.",
    "La captura debe mostrar el listado de reportes.",
    "M3-07_reporte_listado.png",
))
B.append(block(
    "M3-08", "Reporte: eliminación", "Reportes",
    "Validar la eliminación de un reporte.",
    ["Un reporte propio existente."],
    ["Abrir la pantalla de reportes.",
     "Seleccionar un reporte y eliminarlo.",
     "Confirmar."],
    "Cuando el reporte desaparezca de la lista.",
    "La captura debe mostrar el listado sin el reporte eliminado.",
    "M3-08_reporte_eliminado.png",
))
B.append(block(
    "M3-09", "Reporte sin análisis", "Reportes",
    "Validar el comportamiento al generar un reporte sin análisis previos.",
    ["Usuario sin análisis guardados."],
    ["Abrir la pantalla de reportes con un usuario sin análisis.",
     "Intentar generar el reporte."],
    "Cuando la aplicación muestre el aviso/error correspondiente.",
    "La captura debe mostrar el mensaje que muestre la aplicación.",
    "M3-09_reporte_sin_analisis.png",
))
B.append(block(
    "M3-10", "Notificación de análisis completado", "Notificaciones",
    "Validar la aparición de la notificación cuando un análisis finaliza.",
    ["Existe al menos un análisis ya procesado."],
    ["Ejecutar un análisis (o tener uno completado).",
     "Abrir el panel de notificaciones."],
    "Cuando el panel muestre la notificación del análisis listo.",
    "La captura debe mostrar la notificación del análisis completado.",
    "M3-10_notificacion_analisis_listo.png",
))
B.append(block(
    "M3-11", "Consulta de mis análisis", "Historial",
    "Validar la consulta de los análisis del usuario autenticado.",
    ["Sesión iniciada.", "Existen análisis propios."],
    ["Abrir Historial (equivale a «mis análisis» en la app).",
     "Verificar que solo se muestren los análisis propios."],
    "Cuando el historial muestre únicamente análisis propios.",
    "La captura debe mostrar el historial con los análisis propios.",
    "M3-11_mis_analisis.png",
    obs="El endpoint /analysis/my no fue invocado en el conjunto de pruebas del Sprint 5 (no ejecutado a nivel de API). La captura manual permitiría registrar este caso si se ejecuta en la app.",
))

# =====================================================================
# MÓDULO 4 — UBICACIÓN Y MAPA
# =====================================================================
B.append("\n\nMODULO 4 — UBICACIÓN Y MAPA\n" + "=" * 60)
B.append(block(
    "M4-01", "Registro de ubicación (find-or-create)", "Ubicación",
    "Validar que un análisis registre/reutilice la ubicación del dispositivo.",
    ["Sesión iniciada.", "GPS activo y permisos de ubicación concedidos."],
    ["Ejecutar un análisis desde cámara con ubicación (o un análisis que registre ubicación).",
     "Esperar la ubicación capturada."],
    "Cuando el análisis se guarde con su ubicación (visible en el resultado o en el mapa).",
    "La captura debe mostrar el análisis con la ubicación asociada y/o el punto en el mapa.",
    "M4-01_ubicacion_registrada.png",
))
B.append(block(
    "M4-02", "Análisis persistido con ubicación", "Ubicación / Análisis",
    "Validar la persistencia del análisis asociado a una ubicación.",
    ["Sesión iniciada.", "Ubicación disponible y análisis ejecutado."],
    ["Ejecutar el análisis con ubicación.",
     "Verificar el resultado y luego consultarlo en el historial/mapa."],
    "Cuando el análisis aparezca en el historial y en el mapa con su ubicación.",
    "La captura debe mostrar el análisis persistido (historial y/o mapa).",
    "M4-02_analisis_ubicacion_persistido.png",
))
B.append(block(
    "M4-03", "Puntos del mapa", "Mapa",
    "Validar que los análisis con ubicación generen puntos en el mapa.",
    ["Existen análisis con ubicación.", "Google Maps disponible en el dispositivo/emulador."],
    ["Abrir la pantalla del mapa.",
     "Esperar la carga del mapa.",
     "Verificar que aparezcan los puntos con su localización."],
    "Cuando el mapa se haya cargado y los puntos de análisis sean visibles.",
    "La captura debe mostrar el mapa con los puntos de los análisis.",
    "M4-03_puntos_mapa.png",
))
B.append(block(
    "M4-04", "Visibilidad propios / comunitarios", "Mapa",
    "Validar la visibilidad de los análisis propios y de la comunidad en el mapa.",
    ["Existen análisis propios (privados).", "Mapa cargado."],
    ["Abrir el mapa.",
     "Revisar los análisis propios.",
     "Revisar la vista comunitaria/pública si está disponible."],
    "Cuando el mapa distinga (o muestre) los análisis según su visibilidad.",
    "La captura debe mostrar el mapa con los puntos visibles para el usuario.",
    "M4-04_visibilidad_mapa.png",
    obs="En el conjunto de pruebas del Sprint 5 solo existían análisis privados (comunidad sin datos); verificar lo que realmente muestre la app.",
))
B.append("""
CASO: M4-05 / M4-06 / M4-07
NOMBRE: Zonas ambientales — creación, edición y eliminación (admin)
MÓDULO: Ubicación / Administración
---------------------

OBJETIVO:
Validar la gestión administrativa de zonas ambientales desde la interfaz
administradora (si está disponible en la app).

PRECONDICIONES:
* Sesión con rol administrador.
* Pantalla de administración de zonas disponible.

PASOS:
1. Abrir la pantalla de administración de zonas.
2. Crear una zona (nombre, centro lat/lng, radio) y verificar los indicadores.
3. Editar la zona y guardar.
4. Eliminar la zona y confirmar.

MOMENTO EXACTO PARA TOMAR CAPTURA:
Tras cada operación (creación, edición, eliminación).

CAPTURA RECOMENDADA:
Pantalla de zonas con la zona creada/editada, y listado sin la zona eliminada.

NOMBRE SUGERIDO:
M4-05_zona_creada.png / M4-06_zona_editada.png / M4-07_zona_eliminada.png

ESTADO:
[ ] Aprobado (solo con captura real de la app)
[ ] Fallido
[ ] Bloqueado
[ ] No ejecutado

OBSERVACIÓN:
La gestión de zonas se validó por API (auditoría CRUD administrativa 21/21).
Si la UI administradora no fue probada, mantener NO EJECUTADO / FUERA DEL
ALCANCE y conservar la evidencia técnica (api/auditoria_crud_admin.json).

----------------------------------------------------------------------""")
B.append(block(
    "M4-08", "Catálogo de zonas", "Mapa / Catálogo",
    "Validar el catálogo de zonas ambientales.",
    ["Existen zonas creadas (admin)."],
    ["Abrir la pantalla de catálogo de zonas (o sección correspondiente).",
     "Revisar las zonas listadas y sus indicadores."],
    "Cuando el catálogo muestre las zonas con sus indicadores.",
    "La captura debe mostrar el catálogo de zonas.",
    "M4-08_catalogo_zonas.png",
))
B.append(block(
    "M4-09", "Círculos de radio y selección de puntos", "Mapa",
    "Validar la visualización de los círculos de radio y la selección de puntos en el mapa.",
    ["Mapa cargado con puntos de análisis.", "Funcionalidad de filtros/radio disponible en la app."],
    ["Abrir el mapa.",
     "Observar los marcadores y sus círculos de radio.",
     "Tocar un punto para ver su selección/información."],
    "Cuando el mapa muestre los círculos de radio y la selección del punto.",
    "La captura debe mostrar el mapa con círculos y un punto seleccionado.",
    "M4-09_circulos_seleccion.png",
))
B.append("""
CASO: M4-10
NOMBRE: Dos análisis en la misma coordenada
MÓDULO: Mapa
---------------------

OBJETIVO:
Validar el comportamiento del mapa cuando dos análisis comparten coordenadas
(agrupación/pila de puntos).

ESTADO:
NO EJECUTADO / FUERA DEL ALCANCE DEL CONJUNTO DE PRUEBAS EJECUTADO

OBSERVACIÓN:
No se ejecutaron dos análisis en coordenadas iguales durante el Sprint 5. Si
deseas complementarlo, ejecuta dos análisis en el mismo punto y captura el
comportamiento real del mapa.

----------------------------------------------------------------------""")
B.append("""
CASO: M4-11
NOMBRE: Carga del mapa en dispositivo (Google Maps)
MÓDULO: Mapa
---------------------

OBJETIVO:
Validar la carga del mapa de Google en un dispositivo/emulador Android.

ESTADO:
NO EJECUTADO / FUERA DEL ALCANCE DEL CONJUNTO DE PRUEBAS EJECUTADO

OBSERVACIÓN:
Durante el Sprint 5 el mapa no fue ejecutado en un dispositivo/emulador con
Google Maps (requiere emulador/dispositivo con la API configurada). Si lo
ejecutas, toma la captura cuando el mapa cargue correctamente y archívala
como M4-11_mapa_dispositivo.png.

----------------------------------------------------------------------""")

# =====================================================================
# MÓDULO 5 — LIQUENPEDIA, COMUNIDAD Y COMPLEMENTARIOS
# =====================================================================
B.append("\n\nMODULO 5 — LIQUENPEDIA, COMUNIDAD Y FUNCIONALIDADES COMPLEMENTARIAS\n" + "=" * 60)
B.append(block(
    "M5-01", "LiquenPedia: listado público de artículos", "LiquenPedia",
    "Validar el listado de artículos de LiquenPedia.",
    ["Existen artículos publicados en la base de datos."],
    ["Abrir la sección LiquenPedia.",
     "Esperar la carga de la lista."],
    "Cuando el listado muestre los artículos publicados.",
    "La captura debe mostrar la lista de artículos de LiquenPedia.",
    "M5-01_liquenpedia_listado.png",
))
B.append(block(
    "M5-02", "Detalle de artículo", "LiquenPedia",
    "Validar la visualización del detalle de un artículo.",
    ["Existe un artículo publicado."],
    ["Abrir LiquenPedia.",
     "Tocar un artículo."],
    "Cuando la pantalla muestre el contenido del artículo y la información del autor.",
    "La captura debe mostrar el detalle del artículo.",
    "M5-02_liquenpedia_detalle.png",
))
B.append(block(
    "M5-03", "Búsqueda de artículos", "LiquenPedia",
    "Validar la búsqueda de artículos.",
    ["Existen artículos publicados."],
    ["Abrir LiquenPedia.",
     "Usar el buscador con una palabra clave.",
     "Revisar los resultados."],
    "Cuando la búsqueda devuelva los artículos coincidentes.",
    "La captura debe mostrar los resultados de la búsqueda.",
    "M5-03_liquenpedia_busqueda.png",
))
B.append("""
CASO: M5-04
NOMBRE: Estado draft no visible para el público
MÓDULO: LiquenPedia
---------------------

OBJETIVO:
Validar que un artículo en estado «draft» no aparezca para un usuario normal.

PRECONDICIONES:
* Existe un artículo en estado «draft».
* Sesión de un usuario sin rol administrador (o sesión pública).

PASOS:
1. Abrir LiquenPedia.
2. Revisar la lista completa y el buscador.

MOMENTO EXACTO PARA TOMAR CAPTURA:
Cuando se evidencie que el borrador no aparece en la lista pública.

CAPTURA RECOMENDADA:
Listado de LiquenPedia donde no consta el artículo borrador.

NOMBRE SUGERIDO:
M5-04_draft_oculto.png

ESTADO:
[ ] Aprobado (con captura real)
[ ] Fallido
[ ] Bloqueado
[ ] No ejecutado

OBSERVACIÓN:
A nivel API se validó que el borrador no es visible y que su detalle devuelve
403 (auditoría CRUD administrativa). La captura de la app es complementaria.

----------------------------------------------------------------------""")
B.append("""
CASO: M5-05
NOMBRE: CRUD de artículos (administración)
MÓDULO: LiquenPedia / Administración
---------------------

OBJETIVO:
Validar la creación, edición y eliminación de artículos desde la interfaz
administradora (si está disponible en la app).

PRECONDICIONES:
* Sesión con rol administrador.
* Pantalla de administración de LiquenPedia disponible.

PASOS:
1. Crear un artículo y publicarlo.
2. Editar el artículo.
3. Eliminarlo.

MOMENTO EXACTO PARA TOMAR CAPTURA:
Tras cada operación (creación/edición/eliminación).

CAPTURA RECOMENDADA:
Pantallas de administración de artículos con los cambios aplicados.

NOMBRE SUGERIDO:
M5-05_articulo_creado.png / M5-05_articulo_editado.png / M5-05_articulo_eliminado.png

ESTADO:
[ ] Aprobado (con captura real)
[ ] Fallido
[ ] Bloqueado
[ ] No ejecutado

OBSERVACIÓN:
El CRUD de artículos se validó por API (auditoría CRUD administrativa 21/21).
Si la UI administrativa de la app no fue probada, mantener NO EJECUTADO / FUERA
DEL ALCANCE y conservar la evidencia técnica.

----------------------------------------------------------------------""")
B.append(block(
    "M5-06", "Categorías de artículos", "LiquenPedia",
    "Validar la visualización de las categorías de artículos.",
    ["Categorías registradas en el backend."],
    ["Abrir LiquenPedia.",
     "Revisar las categorías (filtros/chips/sección de categorías)."],
    "Cuando las categorías se muestren en la aplicación.",
    "La captura debe mostrar las categorías de artículos.",
    "M5-06_liquenpedia_categorias.png",
))
B.append("""
CASO: M5-07
NOMBRE: Envío de notificación a todos (administración)
MÓDULO: Notificaciones / Administración
---------------------

OBJETIVO:
Validar el envío de una notificación a todos los usuarios desde la
administración.

ESTADO:
No se ofrece guía de captura de app: la operación se validó por API (auditoría
CRUD administrativa 21/21; 201, count>0). Si existe una pantalla
administrativa de notificaciones probada, tomar captura de la confirmación.

----------------------------------------------------------------------""")
B.append(block(
    "M5-08", "Notificaciones del usuario", "Notificaciones",
    "Validar el listado de notificaciones del usuario.",
    ["El usuario tiene notificaciones (p. ej. de un análisis completado)."],
    ["Abrir el panel de notificaciones.",
     "Revisar las notificaciones."],
    "Cuando el panel muestre las notificaciones del usuario.",
    "La captura debe mostrar el panel de notificaciones.",
    "M5-08_notificaciones_usuario.png",
))
B.append(block(
    "M5-09", "Marcar como leída / limpiar notificaciones", "Notificaciones",
    "Validar las acciones de lectura y limpieza de notificaciones.",
    ["El usuario tiene notificaciones."],
    ["Abrir el panel de notificaciones.",
     "Marcar una notificación como leída.",
     "(Opcional) Limpiar las notificaciones."],
    "Cuando el estado leída y/o la limpieza se reflejen en el panel.",
    "La captura debe mostrar el panel antes y después de la acción.",
    "M5-09_notificaciones_leer_limpiar.png",
))
B.append(block(
    "M5-10", "Catálogo de especies", "Catálogo",
    "Validar el catálogo/referencia de especies.",
    ["Existen especies registradas en el backend."],
    ["Abrir la sección de catálogo de especies (o el selector de especies en el análisis).",
     "Revisar las especies listadas."],
    "Cuando el catálogo muestre las especies registradas.",
    "La captura debe mostrar el catálogo de especies.",
    "M5-10_catalogo_especies.png",
))
B.append(block(
    "M5-11", "Pantalla de licencias", "Ajustes",
    "Validar la pantalla de licencias de la aplicación.",
    ["Aplicación ejecutándose."],
    ["Abrir Ajustes.",
     "Ir a «Licencias» / «Licencias de código abierto»."],
    "Cuando la pantalla muestre el listado de licencias.",
    "La captura debe mostrar la pantalla de licencias.",
    "M5-11_licencias.png",
    obs="La pantalla de licencias cuenta con prueba de widget aprobada (frontend/test/licenses_screen_test.dart).",
))
B.append("""
CASO: M5-12
NOMBRE: Ajustes de la aplicación en dispositivo (tema, sonido, ayuda)
MÓDULO: Ajustes
---------------------

OBJETIVO:
Validar la navegación por los ajustes de la aplicación en un dispositivo Android.

ESTADO:
NO EJECUTADO / FUERA DEL ALCANCE DEL CONJUNTO DE PRUEBAS EJECUTADO

OBSERVACIÓN:
La navegación por ajustes en un dispositivo no fue ejecutada durante el Sprint 5.
Si la ejecutas, toma la captura de cada pantalla de ajustes (tema/sonido/ayuda)
y archívala como M5-12_ajustes_*.png.

----------------------------------------------------------------------""")

with open(OUT_TXT, "w", encoding="utf-8") as f:
    f.write(
        "GUÍA DE EVIDENCIAS MANUALES — SPRINT 5 · LICHEN DREAMS\n"
        "========================================================\n"
        "Guía auxiliar para ejecutar la aplicación Android y tomar pantallazos "
        "reales de la interfaz como evidencia de las pruebas manuales.\n\n"
        "CÓMO USARLA:\n"
        "1. Guarda cada captura en: docs/sprint5/evidencias/manuales/\n"
        "2. Sigue los pasos de cada caso hasta la pantalla indicada.\n"
        "3. En el momento exacto indicado, toma el pantallazo.\n"
        "4. Guarda el archivo con el nombre sugerido (p. ej. M1-06_login_exitoso.png).\n"
        "5. No marques un caso como Aprobado solo por tener captura: ejecútalo y "
        "verifica el resultado real.\n"
        "6. Si algo no se puede ejecutar, márcalo No ejecutado y explica por qué "
        "en la observación.\n\n"
        "NOTA: No debes inventar capturas; cada imagen debe corresponder a una "
        "pantalla realmente obtenida. Esta guía NO es un sexto entregable: es un "
        "elemento auxiliar para complementar el Entregable 3.\n"
    )
    f.write("\n" + ("#" * 70) + "\n")
    for b in B:
        f.write(b)

print("GUÍA GENERADA:", OUT_TXT)
print("CARPETA MANUALES:", MANUALES)