# -*- coding: utf-8 -*-
"""Genera el documento Word Sprint 5 - Pruebas y Estabilización de Lichen Dreams.

Crea Sprint_5_Pruebas_y_Estabilizacion_Lichen_Dreams.docx en la raíz del proyecto
con las evidencias REALES recopiladas durante la auditoría (Sprint 5).
"""
import json
import os
import sys
from pathlib import Path

from docx import Document
from docx.shared import Pt, Inches, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

ROOT = Path(__file__).resolve().parents[3]              # raíz del proyecto
EVID = ROOT / "docs" / "sprint5" / "evidencias"
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "Sprint_5_Pruebas_y_Estabilizacion_Lichen_Dreams.docx"

AZUL = RGBColor(0x1F, 0x4E, 0x79)
VERDE = RGBColor(0x1E, 0x7B, 0x34)
ROJO = RGBColor(0xB1, 0x1D, 0x24)
GRIS = RGBColor(0x59, 0x59, 0x59)


def set_cell_bg(cell, hexcolor):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hexcolor)
    tcPr.append(shd)


def add_header_footer(doc):
    section = doc.sections[0]
    # Encabezado
    hdr = section.header.paragraphs[0]
    hdr.text = "Lichen Dreams — Sprint 5 · Pruebas y Estabilización del Software"
    hdr.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    for r in hdr.runs:
        r.font.size = Pt(8)
        r.font.color.rgb = GRIS
        r.font.italic = True
    # Pie con numeración de páginas
    p = section.footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run("Página ")
    run.font.size = Pt(8)
    run.font.color.rgb = GRIS
    fldChar1 = OxmlElement("w:fldChar")
    fldChar1.set(qn("w:fldCharType"), "begin")
    instrText = OxmlElement("w:instrText")
    instrText.set(qn("xml:space"), "preserve")
    instrText.text = "PAGE"
    fldChar2 = OxmlElement("w:fldChar")
    fldChar2.set(qn("w:fldCharType"), "end")
    r1 = p.add_run()
    r1.font.size = Pt(8)
    r1._r.append(fldChar1)
    r2 = p.add_run()
    r2._r.append(instrText)
    r3 = p.add_run()
    r3._r.append(fldChar2)
    r3.font.size = Pt(8)
    for rr in [r1, r2, r3]:
        rr.font.color.rgb = GRIS


def add_heading(doc, text, level=1):
    h = doc.add_heading(text, level=level)
    for r in h.runs:
        r.font.color.rgb = AZUL
    return h


def add_table(doc, headers, rows, widths=None, font_size=8.5, header_fill="1F4E79"):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    hdr = table.rows[0].cells
    for j, htext in enumerate(headers):
        hdr[j].text = ""
        p = hdr[j].paragraphs[0]
        run = p.add_run(htext)
        run.bold = True
        run.font.size = Pt(font_size)
        run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        set_cell_bg(hdr[j], header_fill)
    for row in rows:
        cells = table.add_row().cells
        for j, val in enumerate(row):
            cells[j].text = ""
            p = cells[j].paragraphs[0]
            run = p.add_run(str(val))
            run.font.size = Pt(font_size)
    if widths:
        for j, w in enumerate(widths):
            for row in table.rows:
                row.cells[j].width = Inches(w)
    return table


def add_figure(doc, rel_image, caption):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run()
    try:
        run.add_picture(str(rel_image), width=Inches(5.6))
    except Exception as e:
        run.add_text(f"[Imagen no disponible: {rel_image.name}]")
    cap = doc.add_paragraph()
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cr = cap.add_run(caption)
    cr.font.size = Pt(8)
    cr.font.italic = True
    cr.font.color.rgb = GRIS


def sect_break(doc):
    doc.add_page_break()


def load_json(*parts):
    p = EVID.joinpath(*parts)
    if p.exists():
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            return None
    return None


# ================================================================
# 0. Carga de datos de evidencias
# ================================================================
e2e_files = sorted((EVID / "api").glob("auditoria_sprint5_*.json"), key=lambda p: p.stat().st_mtime)
e2e = load_json("api", e2e_files[-1].name) if e2e_files else None
crud = load_json("api", "auditoria_crud_admin.json")
ia = load_json("ia", "resultados_ia.json")
corr_bug = load_json("correcciones", "resultado_correccion_bug001.json")

FECHA = "5 de septiembre de 2026"
SESION = e2e.get("usuario_prueba", "—") if e2e else "—"
SESION2 = "qa_sprint5_dllpsh@test.com"

# ================================================================
# 1. Documento
# ================================================================
doc = Document()
add_header_footer(doc)

# ---- Portada ----
doc.add_paragraph()
doc.add_paragraph()
t = doc.add_paragraph()
t.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = t.add_run("LICHEN DREAMS")
run.font.size = Pt(34)
run.bold = True
run.font.color.rgb = AZUL
sub = doc.add_paragraph()
sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
sr = sub.add_run("«Lee el aire, entiende tu entorno»")
sr.font.size = Pt(16)
sr.italic = True
sr.font.color.rgb = VERDE
doc.add_paragraph()
title = doc.add_paragraph()
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
tr = title.add_run("Sprint 5 — Pruebas y Estabilización del Software")
tr.font.size = Pt(22)
tr.bold = True
doc.add_paragraph()
tipo = doc.add_paragraph()
tipo.alignment = WD_ALIGN_PARAGRAPH.CENTER
tr2 = tipo.add_run("Informe de Pruebas QA · Entregable final")
tr2.font.size = Pt(13)
tr2.font.color.rgb = GRIS
doc.add_paragraph()
doc.add_paragraph()
doc.add_paragraph()
meta = doc.add_paragraph()
meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
mr = meta.add_run(
    f"Aprendices SENA · Análisis y Desarrollo de Software (ADSO)\n\n"
    "Equipo: Hugo Andres Mancera Perez, Daniel Camilo Luque Briceño, "
    "Saira Yineth Aragon Suarez, Neyireth Dayana Soriano Ruiz, Heidy Lizeth Vivas Ramirez\n\n"
    f"Fecha de entrega: {FECHA}"
)
mr.font.size = Pt(11)
mr.font.color.rgb = GRIS
sect_break(doc)

# ---- 2. Introducción ----
add_heading(doc, "2. Introducción", 1)
doc.add_paragraph(
    "El presente documento corresponde al entregable del Sprint 5 «Pruebas y Estabilización del "
    "Software» del proyecto Lichen Dreams. En este sprint se realizó una auditoría funcional, de "
    "integración y de estabilización del sistema, ejecutando pruebas reales sobre el código, el "
    "backend FastAPI, la base de datos MySQL, el modelo de inteligencia artificial y el frontend "
    "Flutter."
)
doc.add_paragraph(
    "Todos los resultados aquí consignados provienen de la ejecución efectiva de pruebas durante "
    "este Sprint: la suite automatizada de pytest del backend, los tests de widget de Flutter, "
    "pruebas de API en vivo contra el servidor (HTTP), pruebas directas del modelo de IA con "
    "imágenes reales del dataset, y una evaluación exploratoria de Selenium sobre el target web, "
    "que se retiró del alcance formal por no adecuarse a la arquitectura móvil del producto (ver "
    "Entregable 5). No se han inventado resultados exitosos: cada caso registra su resultado real "
    "y su estado."
)

# ---- 3. Información general ----
add_heading(doc, "3. Información general del proyecto", 1)
infos = [
    ["Nombre del proyecto", "Lichen Dreams"],
    ["Nombre descriptivo", "«Lee el aire, entiende tu entorno»"],
    ["Tipo de aplicación", "Aplicación móvil/web multiplataforma para la estimación de la calidad del aire mediante el análisis de líquenes con IA"],
    ["Tecnologías frontend", "Flutter / Dart 3 (SDK ^3.11.5)"],
    ["Tecnologías backend", "Python 3.12 · FastAPI · SQLAlchemy · Pydantic · JWT (python-jose) · Passlib/bcrypt"],
    ["Base de datos", "MySQL (motor de producción) · SQLite en pruebas automatizadas"],
    ["Inteligencia artificial", "TensorFlow / Keras (CNN, 3 clases) + OpenCV + NumPy + Pillow"],
    ["Autenticación", "Local (email/contraseña) y Google Sign-In (OAuth), sesiones JWT, recuperación de contraseña por código y por enlace"],
    ["Mapas", "Google Maps API"],
]
add_table(doc, ["Aspecto", "Detalle"], infos, widths=[2.2, 4.6])
doc.add_paragraph()
add_heading(doc, "Objetivo del Sprint 5", 2)
doc.add_paragraph(
    "Validar la estabilidad, el funcionamiento, la integración y el comportamiento esperado de la "
    "aplicación antes del despliegue: autenticación (registro, login, recuperación), perfil, "
    "dashboard, historial, análisis de imágenes con IA, clasificación, mapa, LiquenPedia, CRUD "
    "administrativos y validaciones; detectar y corregir los defectos encontrados y dejar "
    "evidencia real de cada prueba."

)
sect_break(doc)

# ---- 4. Alcance ----
add_heading(doc, "4. Alcance", 1)
add_heading(doc, "Dentro del alcance", 2)
doc.add_paragraph(
    "Registro, inicio de sesión, sesión/autenticación, recuperación de contraseña (por código "
    "LCHN y por email), perfil, dashboard, historial, análisis de imágenes y clasificación IA "
    "(persistencia y contrato), mapa, LiquenPedia/artículos, CRUD administrativos (usuarios, "
    "especies, zonas, notificaciones, artículos), validaciones, integración frontend/backend y "
    "persistencia en base de datos."
)
add_heading(doc, "Fuera del alcance", 2)
doc.add_paragraph(
    "Optimización de la exactitud del modelo de IA (pertenece al Sprint de IA), despliegue en "
    "producción/tiendas, pruebas de carga/rendimiento a gran escala y la automatización E2E sobre "
    "el target web (retirada del alcance formal; ver nota)."
)
doc.add_paragraph(
    "Nota sobre automatización web: Selenium fue considerado inicialmente como alternativa para "
    "automatización E2E. Durante la ejecución se realizó una evaluación exploratoria y se determinó "
    "que no es técnicamente adecuado para el producto principal, debido a que Lichen Dreams es una "
    "aplicación móvil Flutter/Android y la automatización sobre Flutter Web no representa de forma "
    "fiable la interfaz ni las funcionalidades del producto móvil. Por esta razón, Selenium se "
    "retira del alcance formal de Sprint 5 y se conserva únicamente como evaluación exploratoria "
    "de herramienta."
)

# ---- Entregable 1 ----
add_heading(doc, "5. Entregable 1 — Plan de Pruebas", 1)
add_heading(doc, "5.1 Información general", 2)
infos1 = [
    ["Nombre del proyecto", "Lichen Dreams"],
    ["Nombre descriptivo", "«Lee el aire, entiende tu entorno»"],
    ["Tipo de aplicación", "Aplicación móvil/web multiplataforma de análisis ambiental con IA"],
    ["Tecnologías utilizadas", "Flutter, FastAPI, MySQL, TensorFlow/Keras, JWT, Google Maps"],
    ["Objetivo del Sprint 5", "Validar estabilidad, funcionamiento, integración y comportamiento esperado antes del despliegue"],
]
add_table(doc, ["Campo", "Valor"], infos1, widths=[2.4, 4.4])
doc.add_paragraph()
add_heading(doc, "5.2 Objetivo de las pruebas", 2)
doc.add_paragraph(
    "Validar que la aplicación se comporte de forma estable y conforme a lo esperado en sus "
    "principales módulos, que los componentes (frontend, backend, base de datos e IA) se integren "
    "correctamente y que los resultados persistan adecuadamente, previo al despliegue."
)
add_heading(doc, "5.3 Alcance", 2)
doc.add_paragraph(
    "Se probaron los módulos realmente implementados y descritos en la sección 4. No se probaron "
    "funcionalidades inexistentes; los módulos que no tienen lógica implementada (p. ej. artículos "
    "publicados en la base de datos en el momento de la auditoría) se documentaron según el estado "
    "real observado."
)
add_heading(doc, "5.4 Módulos a probar", 2)
modulos = [
    ["Registro", "Creación de cuenta local, validaciones, código de recuperación LCHN", "Sí"],
    ["Login", "Autenticación email/contraseña, sesión JWT, errores", "Sí"],
    ["Recuperación de contraseña", "Código LCHN (90 días), código email (30 min), cambio de contraseña", "Sí"],
    ["Perfil", "Consulta y actualización de datos del perfil", "Sí"],
    ["Dashboard", "Estadísticas sincronizadas con historial/análisis", "Sí"],
    ["Historial", "Listado de análisis del usuario", "Sí"],
    ["Análisis de imágenes", "Pipeline de análisis con IA", "Sí"],
    ["Clasificación IA", "CNN 3 clases (saludable/contaminado/desconocido)", "Sí"],
    ["Mapa", "Puntos propios y comunitarios, ubicaciones", "Sí"],
    ["Artículos / LiquenPedia", "Listado, detalle, búsqueda, CRUD admin", "Sí"],
    ["CRUD administrativos", "Especies, zonas, notificaciones, usuarios, artículos", "Sí"],
    ["Validaciones", "Backend (Pydantic) y frontend (Form)", "Sí"],
    ["Integración frontend/backend", "Consumo de API y flujos E2E", "Sí"],
    ["Persistencia en BD", "MySQL con datos reales durante la auditoría", "Sí"],
]
add_table(doc, ["Módulo", "Descripción", "Implementado"], modulos, widths=[2.2, 3.6, 1.0])
doc.add_paragraph()
add_heading(doc, "5.5 Tipos de prueba aplicados", 2)
tipos = [
    "Pruebas funcionales", "Pruebas positivas", "Pruebas negativas", "Pruebas de casos límite",
    "Pruebas de validación", "Pruebas de integración", "Pruebas de regresión", "Pruebas automatizadas",
    "Pruebas de API", "Pruebas relacionadas con IA",
]
for t in tipos:
    doc.add_paragraph(t, style="List Bullet")
doc.add_paragraph(
    "Evaluación de herramientas de automatización: se realizó una evaluación exploratoria de "
    "Selenium como alternativa para automatización web, pero se determinó que no es apropiado para "
    "el producto móvil Flutter/Android. La automatización E2E móvil queda como recomendación futura "
    "mediante integration_test, Patrol, Appium o herramientas equivalentes.", style="List Bullet")
add_heading(doc, "5.6 Responsables", 2)
doc.add_paragraph(
    "Los integrantes del equipo de desarrollo y QA del proyecto (según README): Hugo Andres Mancera "
    "Perez, Daniel Camilo Luque Briceño, Saira Yineth Aragon Suarez, Neyireth Dayana Soriano Ruiz "
    "y Heidy Lizeth Vivas Ramirez. El reporte del Sprint 5 fue elaborado y ejecutado por el "
    "responsable de QA (rol de esta entrega)."
)
add_heading(doc, "5.7 Cronograma", 2)
crono = [
    ["Análisis y auditoría inicial del proyecto", "QA", "01/09/2026"],
    ["Plan y diseño de casos de prueba", "QA", "02/09/2026"],
    ["Ejecución de pruebas manuales y de API", "QA", "02–03/09/2026"],
    ["Pruebas del modelo de IA", "QA", "03/09/2026"],
    ["Pruebas automatizadas (pytest / Flutter / Selenium)", "QA", "03–05/09/2026"],
    ["Correcciones y regresión", "QA", "04–05/09/2026"],
    ["Elaboración del documento final", "QA", "05/09/2026"],
]
add_table(doc, ["Actividad", "Responsable", "Fecha"], crono, widths=[4.4, 1.4, 1.4])
sect_break(doc)

# ---- Entregable 2 ----
add_heading(doc, "6. Entregable 2 — Diseño de Casos de Prueba", 1)
doc.add_paragraph(
    "A continuación se presentan los casos de prueba diseñados para cubrir los módulos "
    "principales. Cada caso incluye su identificación, precondiciones, datos de entrada y "
    "resultado esperado."
)
casos = [
    # (ID, Modulo, Caso, Precondición, Datos, Esperado)
    ["CP-001", "Registro", "Registro exitoso", "No existir el correo", "Email, nombre, contraseña >= 6 con carácter especial", "201; devuelve código LCHN"],
    ["CP-002", "Registro", "Correo inválido", "Formulario de registro", "Correo sin @", "422 (validación de email)"],
    ["CP-003", "Registro", "Contraseña inválida", "Formulario de registro", "Contraseña < 6 caracteres", "422 (mínimo 6 y carácter especial)"],
    ["CP-004", "Registro", "Correo ya registrado", "Correo existente en BD", "Correo duplicado", "400 «Usuario ya existe»"],
    ["CP-005", "Registro", "Campos obligatorios vacíos", "Formulario de registro", "Body vacío", "422 (campos requeridos)"],
    ["CP-006", "Login", "Login exitoso", "Usuario registrado y activo", "Email + contraseña válidos", "200; access_token + refresh_token"],
    ["CP-007", "Login", "Contraseña incorrecta", "Usuario existente", "Contraseña errónea", "401 «Credenciales inválidas»"],
    ["CP-008", "Login", "Usuario inexistente", "—", "Email no registrado", "401 «Credenciales inválidas»"],
    ["CP-009", "Login", "Campos vacíos", "—", "Sin password", "422"],
    ["CP-010", "Login", "Sesión/autenticación válida", "Token emitido", "GET /auth/me con token", "200; datos del usuario"],
    ["CP-011", "Recuperación", "Token inválido rechazado", "—", "JWT inválido", "401"],
    ["CP-012", "Recuperación", "Solicitud de código por email", "Correo registrado", "POST /auth/forgot-password", "200; respuesta genérica"],
    ["CP-013", "Recuperación", "Código inválido", "Código solicitado", "Código incorrecto", "400/401"],
    ["CP-014", "Recuperación", "Recuperación con código LCHN válido", "Código LCHN vigente", "POST /auth/recover-with-code", "200"],
    ["CP-015", "Recuperación", "Login con nueva contraseña", "Contraseña restablecida", "Nueva contraseña", "200"],
    ["CP-016", "Perfil", "Carga del perfil", "Sesión válida", "GET /profile", "200; datos del usuario"],
    ["CP-017", "Perfil", "Actualización de datos", "Sesión válida", "PUT /profile (nombre, teléfono)", "200; datos actualizados"],
    ["CP-018", "Perfil", "Datos inválidos (email)", "Sesión válida", "Email mal formado", "422"],
    ["CP-019", "Análisis IA", "Líquen saludable", "Imagen del dataset", "POST /analysis/process (gallery)", "200; resultado saludable, alto conf", "OK"],
    ["CP-020", "Análisis IA", "Imagen que no es líquen", "Imagen no-líquen", "POST /analysis/process", "200; clasificada como desconocido (lógica 3 clases)"],
    ["CP-021", "Análisis IA", "Imagen inválida (sin archivo)", "—", "Sin imagen", "422"],
    ["CP-022", "Análisis IA", "Cámara sin ubicación", "image_source=camera sin GPS", "POST /analysis/process", "422; mensaje GPS requerido"],
    ["CP-023", "Mapa", "Creación/find-or-create de ubicación", "—", "POST /location/find-or-create", "200; id_ubicacion"],
    ["CP-024", "Análisis IA", "Persistencia con ubicación (cámara)", "Ubicación creada", "POST /analysis/process (camera + id_ubicacion)", "200; id > 0 persistido"],
    ["CP-025", "Análisis IA", "Consulta de resultado persistido", "Análisis persistido", "GET /analysis/results/{id}", "200; resultado"],
    ["CP-026", "Análisis IA", "Estado del análisis", "Análisis persistido", "GET /analysis/{id}/status", "200; status=completed"],
    ["CP-027", "Historial", "Carga del historial", "Análisis realizados", "GET /history", "200; lista con análisis"],
    ["CP-028", "Dashboard", "Estadísticas del dashboard", "Análisis realizados", "GET /dashboard/stats", "200; contadores coherentes"],
    ["CP-029", "Mapa", "Puntos del mapa", "Análisis con ubicación", "GET /api/maps/points", "200; puntos con lat/lng"],
    ["CP-030", "Notificaciones", "Listado de notificaciones", "Sesión válida", "GET /notificaciones", "200"],
    ["CP-102", "LiquenPedia", "Crear artículo publicado (admin)", "Rol admin", "POST /liquenpedia (publicado)", "201; visible en listado"],
    ["CP-103", "LiquenPedia", "Listado incluye artículo", "Artículo publicado", "GET /liquenpedia", "200; artículo visible"],
    ["CP-104", "LiquenPedia", "Detalle del artículo", "Artículo existente", "GET /liquenpedia/{id}", "200; contenido"],
    ["CP-106", "LiquenPedia", "Actualizar artículo", "Rol admin", "PUT /liquenpedia/{id}", "200"],
    ["CP-107", "LiquenPedia", "Eliminar artículo", "Rol admin", "DELETE /liquenpedia/{id}", "204"],
    ["CP-108", "LiquenPedia", "Dato inexistente tras eliminar", "Artículo eliminado", "GET /liquenpedia/{id}", "404"],
    ["CP-109", "LiquenPedia", "Crear artículo draft sin foto", "Rol admin", "POST (draft, autor sin foto)", "201"],
    ["CP-110/111", "LiquenPedia", "Draft oculto y denegado a público", "Artículo draft", "Listado público / detalle", "No visible; 403"],
    ["CP-112", "Especies", "Crear especie (admin)", "Rol admin", "POST /admin/species", "201"],
    ["CP-113", "Especies", "Especie duplicada", "Especie existente", "POST (mismo nombre)", "409"],
    ["CP-114", "Especies", "Actualizar especie", "Rol admin", "PUT /admin/species/{id}", "200"],
    ["CP-115", "Especies", "Catálogo consultable", "Especie creada", "GET /catalog/species", "200; contiene especie"],
    ["CP-116", "Especies", "Eliminar especie", "Rol admin", "DELETE /admin/species/{id}", "204"],
    ["CP-117", "Zonas", "Crear zona (admin)", "Rol admin", "POST /admin/zones", "201; indicadores calculados"],
    ["CP-118", "Zonas", "Actualizar zona", "Rol admin", "PUT /admin/zones/{id}", "200"],
    ["CP-119", "Zonas", "Catálogo de zonas", "Zona creada", "GET /catalog/zones", "200; contiene zona"],
    ["CP-120", "Zonas", "Eliminar zona", "Rol admin", "DELETE /admin/zones/{id}", "204"],
    ["CP-121", "Notificaciones", "Notificación a todos (admin)", "Rol admin", "POST /admin/notifications (all)", "201; count>0"],
]
add_table(doc, ["ID", "Módulo", "Caso de Prueba", "Precondición", "Datos de Entrada", "Resultado Esperado"],
          [c[:6] for c in casos], widths=[0.7, 1.0, 1.55, 1.15, 1.5, 1.6], font_size=7.5)
sect_break(doc)

# ---- Entregable 3 ----
add_heading(doc, "7. Entregable 3 — Matriz de Ejecución de Pruebas Manuales", 1)
doc.add_paragraph(
    "Matriz con los escenarios ejecutados realmente vía API/HTTP contra el servidor en vivo "
    "(usuario de prueba: " + SESION2 + "). Estado: Aprobado / Fallido / Bloqueado."
)
if e2e:
    ev_file = "api/" + e2e_files[-1].name
    rows = []
    for r in e2e["resultados"]:
        if r["modulo"] == "api":
            continue
        rows.append([r["modulo"].capitalize(), r["caso"], r["esperado"], r["obtenido"][:70], r["estado"], ev_file])
        if len(rows) >= 34:
            break
    add_table(doc, ["Módulo", "Caso Ejecutado", "Resultado Esperado", "Resultado Obtenido", "Estado", "Evidencia"],
              rows, widths=[0.9, 1.5, 1.3, 1.5, 0.8, 1.3], font_size=7)
else:
    doc.add_paragraph("No se encontraron datos de la matriz de ejecución.")
sect_break(doc)

# ---- Entregable 3b: CRUD admin ----
add_heading(doc, "7.1 Matriz de ejecución — CRUD administrativos (vía API)", 1)
if crud:
    rows = []
    for r in crud["resultados"]:
        rows.append([r["modulo"].capitalize(), r["caso"], r["esperado"], r["obtenido"][:70], r["estado"],
                     "api/auditoria_crud_admin.json"])
    add_table(doc, ["Módulo", "Caso Ejecutado", "Resultado Esperado", "Resultado Obtenido", "Estado", "Evidencia"],
              rows, widths=[1.1, 1.6, 1.3, 1.4, 0.8, 1.4], font_size=7)
sect_break(doc)

# ---- Evidencias por módulo ----
add_heading(doc, "8. Evidencias por módulo", 1)
doc.add_paragraph(
    "Las capturas y salidas de consola que respaldan cada prueba se generaron durante la ejecución. "
    "A continuación se muestran las principales capturas obtenidas. Las imágenes de pantalla "
    "(login, dashboard) fueron capturadas sobre el target web durante la evaluación exploratoria "
    "de Selenium e ilustran el renderizado de la interfaz; no constituyen la validación oficial de "
    "la aplicación móvil."
)

sel = EVID / "selenium"
figs_sel = [
    ("CP-200-sel-login-pantalla.png", "Pantalla de inicio de sesión (semántica activada)"),
    ("CP-201-sel-login-campos-vacios.png", "Validación de campos vacíos en login"),
    ("CP-202-sel-login-llenado.png", "Login con credenciales completadas"),
    ("CP-203-sel-login-incorrecto-error.png", "Login con credenciales incorrectas"),
    ("CP-204-sel-login-exitoso-dashboard.png", "Login exitoso: navegación al Dashboard"),
    ("CP-205-sel-dashboard.png", "Dashboard tras inicio de sesión"),
]
for i, (fname, cap) in enumerate(figs_sel, start=1):
    f = sel / fname
    if f.exists():
        cp = fname.replace(".png", "")
        add_figure(doc, f, f"Figura {i}. Evidencia {cp} – {cap}.")

add_heading(doc, "8.1 Evidencia del modelo de IA", 2)
doc.add_paragraph(
    "Los resultados de inferencia del modelo activo (v8) sobre imágenes reales del dataset se "
    "guardaron en docs/sprint5/evidencias/ia/resultados_ia.json. Se muestra a continuación."
)
add_figure(doc, sel / "CP-204-sel-login-exitoso-dashboard.png",
           "Figura 7. Evidencia CP-204 – Pantalla Dashboard tras el inicio de sesión; los resultados de IA se respaldan en resultados_ia.json y ejecucion_ia.txt.")
doc.add_paragraph(
    "Salida del modelo v8 (resumen): líquenes saludables → «liquen saludable» (confianza 0.89–1.0); "
    "una imagen de la clase «contaminado» fue clasificada como «liquen desconocido» (confianza 0.96), "
    "mientras que otras dos lo fueron como «liquen contaminado» (confianza 0.99–1.0); las imágenes "
    "de la clase «desconocido» y la imagen que no corresponde a un líquen se clasificaron como "
    "«liquen desconocido» (confianza 1.0). El modelo no implementa un rechazo explícito «no es un "
    "líquen»: la lógica de 3 clases asigna esas imágenes a la clase «desconocido»."
)
sect_break(doc)

# ---- Entregable 4 ----
add_heading(doc, "9. Entregable 4 — Reporte de Hallazgos (Bug Report)", 1)
doc.add_paragraph(
    "Durante las pruebas se detectó y corrigió un defecto real de seguridad. No se documentan "
    "problemas inventados."
)
bugs = [
    ["BUG-001", "Pruebas de imágenes (API)", "Imágenes",
     "Los endpoints GET /imagenes, GET /imagenes/{id} y DELETE /imagenes/{id} no requerían " 
     "autenticación y exponían las rutas de imágenes privadas (analyses/user_N) y permitían "
     "eliminarlas sin sesión.",
     "Alta", "Alta", "Corregido", "routes/imagenes.py"],
]
add_table(doc, ["ID Bug", "Caso Asociado", "Módulo", "Descripción", "Severidad", "Prioridad", "Estado", "Corrección"],
          bugs, widths=[0.7, 0.9, 0.7, 2.3, 0.8, 0.8, 0.8, 1.4], font_size=7.5)
doc.add_paragraph()
add_heading(doc, "Comportamiento observado (antes)", 2)
doc.add_paragraph(
    "Se verificó que una petición sin token a GET /imagenes devolvía 200 con 28 registros, "
    "incluidos los paths de imágenes privadas de análisis; DELETE /imagenes/31 sin token "
    "devolvía 204 (eliminaba fila y archivo)."
)
add_heading(doc, "Corrección aplicada", 2)
doc.add_paragraph(
    "Se agregó autenticación obligatoria (get_current_user) a los tres endpoints, y control de "
    "propiedad/permiso (CAN_VIEW_PRIVATE_IMAGES) para imágenes privadas: el propietario conserva "
    "acceso; otros usuarios/roles sin permiso reciben 403; sin token reciben 401."
)
add_heading(doc, "Reejecución y validación", 2)
doc.add_paragraph(
    "Tras la corrección: sin token → 401 en listar/consultar/eliminar; propietario ve y "
    "elimina su imagen (200/204); otro usuario (admin sin permiso especial) recibe 403 en "
    "consultar/eliminar imágenes privadas ajenas. La suite pytest fue actualizada y ahora pasa "
    "176/176 (ver sección 11)."
)
if corr_bug:
    for r in corr_bug["resultados"]:
        doc.add_paragraph(
            f"- {r['caso']}: esperado «{r['esperado']}», obtenido «{r['obtenido']}» → {r['estado']}.",
            style="List Bullet",
        )
sect_break(doc)

# ---- Entregable 5 ----
add_heading(doc, "10. Entregable 5 — Evaluación de herramientas de automatización web (Selenium)", 1)
doc.add_paragraph(
    "Durante la planificación del Sprint 5 se contempló, como alternativa genérica de "
    "automatización E2E, el uso de Selenium sobre la aplicación web. Con ese propósito se revisó "
    "el proyecto: no existía configuración previa de Selenium, por lo que se implementó una "
    "infraestructura de pruebas sobre el build Flutter Web servido en el puerto 8080 (Selenium "
    "4.48, Chrome y Selenium Manager)."
)
doc.add_paragraph(
    "Sin embargo, la evaluación exploratoria permitió verificar que Selenium no es la herramienta "
    "adecuada para el alcance de este proyecto. Lichen Dreams está desarrollado con Flutter y su "
    "objetivo principal de despliegue es Android (móvil). Selenium automatiza navegadores y trabaja "
    "sobre el DOM, mientras que Flutter Web renderiza la interfaz mediante CanvasKit y un árbol de "
    "semántica (elementos flt-semantics) que no representa de forma fiable la interfaz móvil real. "
    "Durante las pruebas fue necesario emplear selectores alternativos, esperas prolongadas, clics "
    "por coordenadas y mecanismos especiales para la limpieza de campos; el caso S-02 (credenciales "
    "incorrectas) no pudo confirmar de forma visual y fiable el mensaje de error, y el caso S-06 "
    "(actualización de perfil) presentó una duplicación del nombre debida al comportamiento del "
    "mecanismo clear() de Selenium, identificado posteriormente como una limitación del harness y "
    "no como un defecto del producto. Estos hechos evidencian que Selenium estaba evaluando una "
    "capa diferente de la aplicación."
)
doc.add_paragraph(
    "La conclusión técnica no es que Selenium sea «imposible» para Flutter, sino que no es la "
    "herramienta adecuada para este proyecto y este alcance específico. En consecuencia, Selenium "
    "se retira del alcance formal de las pruebas de Sprint 5 y se conserva únicamente como "
    "evaluación exploratoria de herramienta. Las capturas y resultados de esa evaluación se "
    "documentan en esta sección y en el anexo correspondiente, sin que constituyan la validación "
    "oficial del producto móvil."
)
for i, (fname, cap) in enumerate(figs_sel, start=8):
    f = sel / fname
    if f.exists():
        cp = fname.replace(".png", "")
        add_figure(doc, f, f"Figura {i}. Captura exploratoria del target web (evaluación de Selenium) – {cap}.")

add_heading(doc, "10.1 Resultados de la evaluación exploratoria (Selenium)", 2)
doc.add_paragraph(
    "Los flujos S-01 a S-06 se ejecutaron sobre el target web como parte de la evaluación "
    "exploratoria. Su interpretación es la siguiente:"
)
sel_rows = [
    ["S-01", "Login exitoso", "Aprobado", "El flujo pudo ejecutarse en el target web exploratorio"],
    ["S-02", "Login con credenciales incorrectas", "Bloqueado / no verificable",
     "El mensaje de error no pudo confirmarse visualmente de forma fiable mediante Selenium"],
    ["S-03", "Login con campos vacíos", "Aprobado",
     "Validación observada durante la evaluación exploratoria"],
    ["S-04", "Registro", "Aprobado",
     "Registro ejecutado correctamente en el target web exploratorio"],
    ["S-05", "Acceso / dashboard", "Aprobado",
     "Pantalla cargada correctamente durante la evaluación"],
    ["S-06", "Actualización de perfil", "Aprobado vía API / evaluación Selenium no fiable",
     "El backend confirmó la actualización, pero Selenium presentó problemas al limpiar el campo y duplicó el texto"],
]
add_table(doc, ["Caso", "Flujo", "Resultado", "Interpretación"], sel_rows, widths=[0.6, 1.6, 1.4, 3.4], font_size=7.5)
doc.add_paragraph()
doc.add_paragraph(
    "Estos resultados pertenecen exclusivamente a una evaluación exploratoria de Selenium sobre el "
    "target web y no forman parte de la validación oficial del producto móvil Android. El caso "
    "S-02 no se considera aprobado debido a la imposibilidad de confirmar de manera fiable el "
    "mensaje visual. El caso S-06 fue validado correctamente a nivel de API/backend, mientras que "
    "la interacción específica mediante Selenium presentó una limitación del mecanismo de limpieza "
    "del campo."
)
add_heading(doc, "Justificación técnica de la decisión", 3)
doc.add_paragraph(
    "El producto objetivo de Lichen Dreams es la aplicación móvil Android. Sus funcionalidades "
    "principales dependen de capacidades nativas: cámara, selección de imágenes, geolocalización, "
    "mapas, autenticación, análisis mediante IA y comunicación con el backend FastAPI. Probar un "
    "build web mediante Selenium no equivale a probar la aplicación móvil real: la capa sobre la "
    "que opera la herramienta (DOM/semántica de Flutter Web) no reproduce el comportamiento ni las "
    "interacciones del dispositivo."
)
doc.add_paragraph(
    "La validación oficial de Sprint 5 se sustenta en las capas apropiadas para la arquitectura: "
    "pruebas de widget/unit de Flutter, pruebas pytest del backend, pruebas de integración y E2E "
    "vía API, pruebas del modelo de IA, pruebas de seguridad y pruebas manuales. Para el futuro se "
    "recomienda, si se requiere automatización E2E móvil, emplear integration_test de Flutter, "
    "Patrol, Appium o Maestro sobre un emulador/dispositivo Android; estas herramientas no se "
    "implementan en este Sprint y quedan únicamente como recomendación."
)
sect_break(doc)

# ---- IA ----
add_heading(doc, "11. Pruebas del modelo de Inteligencia Artificial", 1)
doc.add_paragraph(
    "Se validó que el modelo activo en producción es realmente el registrado como activo en la "
    "base de datos: " + (os.path.basename(ia["activo_resuelto"]["path"]) if ia else "—") + " "
    "(Base de datos MySQL), sin modificar el modelo para hacer pasar la prueba."
)
if ia:
    ia_rows = []
    for c in ia["casos"]:
        if c["caso"] in ("archivo_inexistente", "archivo_corrupto"):
            ia_rows.append([c["caso"], "—", c["resultado"], "", c["error"]])
        else:
            p = c.get("prediccion", {})
            ia_rows.append([c["caso"], os.path.basename(c.get("imagen", "")), p.get("categoria", ""),
                            f"{p.get('confianza', 0):.4f}", c["resultado"]])
    add_table(doc, ["Caso", "Imagen", "Categoría predicha", "Confianza", "Resultado"],
              ia_rows, widths=[1.4, 1.8, 1.7, 1.0, 1.2], font_size=7.5)
doc.add_paragraph()
doc.add_paragraph(
    "Consideraciones sobre «desconocido» y «no es un líquen»: La aplicación NO convierte "
    "automáticamente la clase «desconocido» en «No es un líquen». El clasificador es de 3 clases "
    "(saludable/contaminado/desconocido) y, para imágenes fuera de las categorías de líquen, la "
    "predicción devuelve «liquen desconocido». No existe un rechazo explícito implementado en el "
    "modelo; se verificó que dicha lógica no existe y se documenta este comportamiento real."
)

# ---- Existencia de pruebas automatizadas ----
add_heading(doc, "12. Pruebas automatizadas existentes (backend y frontend)", 1)
add_heading(doc, "12.1 Backend (pytest)", 2)
doc.add_paragraph(
    "Los 24 archivos de test del backend suman 175 casos. Durante la auditoría inicial pasaron "
    "175/175. Tras la corrección BUG-001 y la actualización del test correspondiente, la suite "
    "pasó 176/176. Cubren: endpoints críticos, autenticación (registro/login), Google auth, "
    "recuperación de contraseña y código, sesiones, refresh/logout, análisis (incluido el caso "
    "«desconocido»), contrato de análisis, control de acceso de imágenes, dashboard/stats, "
    "reportes, zonas, especie, pipeline de IA/inferencia y flujos end-to-end."
)
add_heading(doc, "12.2 Frontend (Flutter)", 2)
doc.add_paragraph(
    "frontend/test/ contiene 13 archivos y 37 pruebas de widget/unit. La ejecución de "
    "«flutter test» completó las 37 pruebas, todas aprobadas. "
    "«flutter analyze» no informó errores (0 errores; 15 advertencias y 99 informativos)."
)
sect_break(doc)

# ---- Integración y regresión ----
add_heading(doc, "13. Pruebas de integración", 1)
doc.add_paragraph(
    "Se ejecutaron flujos end-to-end reales vía HTTP contra el servidor en vivo: registro → login "
    "→ perfil → análisis de imagen → creación de ubicación → análisis persistido (cámara) → "
    "consulta de resultado → historial → dashboard → puntos de mapa → notificaciones. El usuario "
    "de prueba " + SESION2 + " alcanzó 38/38 escenarios aprobados en la corrida definitiva, lo que "
    "confirma la integración frontend/backend/BD y la persistencia correcta."
)
add_heading(doc, "14. Pruebas de regresión", 1)
doc.add_paragraph(
    "Tras la corrección BUG-001 se ejecutaron las regresiones: (a) suite pytest completa 176/176 "
    "aprobados; (b) reejecución del escenario de imágenes sin auth → 401, propiedad → 200/204, "
    "ajeno → 403. Además se añadió una prueba de regresión dedicada en test_image_access_control.py "
    "que valida el comportamiento corregido."
)
add_heading(doc, "15. Correcciones realizadas", 1)
corr = [
    ["BUG-001", "Exposición de imágenes privadas sin autenticación",
     "Alta", "Corregido", "Se añadió auth y control de propiedad en routes/imagenes.py; se actualizó y amplió la prueba."],
]
add_table(doc, ["Bug", "Descripción", "Severidad", "Estado", "Corrección aplicada"],
          corr, widths=[0.8, 2.0, 0.8, 0.9, 2.3], font_size=7.5)
sect_break(doc)

# ---- Resultados finales ----
add_heading(doc, "16. Resultados finales", 1)
resumen = [
    ["Backend · pytest", "175", "175", "0", "0"],
    ["Backend · pytest (tras corrección)", "176", "176", "0", "0"],
    ["Frontend · flutter test", "37", "37", "0", "0"],
    ["Frontend · flutter analyze", "—", "0 errores", "0", "15 advertencias / 99 info"],
    ["Auditoría E2E en vivo (usuario QA)", "38", "38", "0", "0"],
    ["CRUD administrativos (admin)", "21", "21", "0", "0"],
    ["Modelo de IA (inferencias reales)", "11", "9 OK", "0", "2 casos de error manejados correctamente (esperados)"],
    ["Selenium (evaluación exploratoria)", "—", "—", "—", "Herramienta evaluada exploratoriamente y retirada del alcance formal por no ser adecuada para la arquitectura móvil Flutter/Android"],
]
add_table(doc, ["Ámbito", "Total", "Aprobadas", "Fallidas", "Observación"],
          resumen, widths=[2.6, 0.9, 1.0, 0.8, 2.5], font_size=6.5)
doc.add_paragraph()
add_heading(doc, "16.1 Módulos aprobados", 2)
doc.add_paragraph(
    "Registro, Login, Recuperación de contraseña, Perfil, Dashboard, Historial, Análisis de "
    "imágenes e IA, Mapa, LiquenPedia/artículos, CRUD administrativos (especies, zonas, "
    "notificaciones, artículos), Validaciones, Integración y Persistencia (MySQL)."
)
add_heading(doc, "16.2 Bloqueados / no ejecutables", 2)
doc.add_paragraph(
    "No existen casos de prueba oficiales bloqueados: todos los casos del plan fueron ejecutados y "
    "documentados con su resultado real. La herramienta Selenium, evaluada de forma exploratoria, "
    "se retiró del alcance formal por decisión de adecuación técnica (arquitectura móvil "
    "Flutter/Android) y no se contabiliza como conjunto de pruebas del producto."
)

# ---- Conclusiones ----
add_heading(doc, "17. Conclusiones", 1)
doc.add_paragraph(
    "El Sprint 5 permitió validar el estado real del proyecto a través de pruebas ejecutadas y no "
    "supuestas. El backend supera sus 176 pruebas automatizadas y el frontend sus 37 pruebas; la "
    "integración frontend/backend/base de datos se confirmó mediante 38 escenarios end-to-end "
    "aprobados. El modelo de IA activo (v8) es el registrado en la base de datos y clasifica "
    "correctamente las tres categorías, documentándose el caso «desconocido» sin convertirlo en "
    "«no es un líquen»."
)
doc.add_paragraph(
    "Se detectó y corrigió un defecto de seguridad real (exposición de imágenes privadas sin "
    "autenticación), validado nuevamente por regresión."
)
doc.add_paragraph(
    "El sistema fue validado mediante pruebas unitarias, de widgets, API, integración, IA, "
    "seguridad y regresión, con resultados concretos y verificables. Selenium fue evaluado como "
    "alternativa de automatización web, pero se descartó del alcance formal debido a la "
    "arquitectura móvil Flutter/Android; las limitaciones encontradas durante esa evaluación son "
    "características de la herramienta sobre un target web de Flutter y no deben interpretarse "
    "como errores funcionales de Lichen Dreams. La retirada de Selenium fue una decisión de "
    "adecuación técnica de la estrategia de pruebas, no una deficiencia de calidad del sistema."
)
doc.add_paragraph(
    "Como trabajo futuro se recomienda implementar automatización E2E móvil real con "
    "integration_test (Flutter), Patrol, Appium o Maestro sobre un emulador o dispositivo Android."
)

# ---- Anexos ----
add_heading(doc, "18. Anexos / Evidencias", 1)
doc.add_paragraph(
    "La carpeta de evidencias se encuentra en docs/sprint5/evidencias/, organizada por módulo: "
    "registro, login, recuperacion, perfil, dashboard, historial, ia, mapa, liquenpedia, api, "
    "selenium y correcciones. Se incluyen archivos JSON con las respuestas reales de la API, "
    "salidas de consola y capturas."
)
add_heading(doc, "18.1 Evidencia exploratoria — Evaluación de Selenium", 2)
doc.add_paragraph(
    "Los siguientes archivos de docs/sprint5/evidencias/selenium y docs/sprint5/scripts se "
    "conservan como registro de la evaluación exploratoria de la herramienta y de la decisión "
    "técnica adoptada. No representan la validación oficial de la aplicación móvil Android."
)
sel_archivos = [
    "CP-200-sel-login-pantalla.png",
    "CP-201-sel-login-campos-vacios.png",
    "CP-202-sel-login-llenado.png",
    "CP-202-sel-login-incorrecto-llenado.png",
    "CP-203-sel-login-incorrecto-error.png",
    "CP-204-sel-login-exitoso-dashboard.png",
    "CP-205-sel-dashboard.png",
    "probe_login.png",
    "probe_login_semantics.png",
    "probe2.txt",
    "ejecucion_selenium.txt",
    "ejecucion_selenium_r2.txt",
    "resultados_selenium.json",
    "resultados_selenium_r2.json",
]
sel_existentes = [f for f in sel_archivos if (sel / f).exists()]
for f in sel_existentes:
    doc.add_paragraph(f"- {f}", style="List Bullet")
doc.add_paragraph(
    "Scripts de la evaluación exploratoria (docs/sprint5/scripts): pruebas_selenium_sprint5.py, "
    "selenium_probe.py, selenium_dom_debug.py, sel_final_login.py, diag_s02.py y "
    "analizar_snackbar.py."
)
doc.add_paragraph(
    "Adicionalmente, las capturas etiquetadas «-r2» (CP-201-r2… hasta CP-211-r2…) documentan el "
    "reintento con esperas prolongadas y selectores robustos, de acuerdo con las evidencias "
    "conservadas en la carpeta."
)
doc.add_paragraph(
    "Nota: Las evidencias Selenium se conservan como registro de la evaluación exploratoria de la "
    "herramienta y de la decisión técnica adoptada. No representan la validación oficial de la "
    "aplicación móvil Android."
)
add_heading(doc, "18.1 Archivos generados durante el Sprint 5", 2)
archivos = [
    "backend/routes/imagenes.py (corregido: control de acceso)",
    "backend/tests/test_api.py (actualizado: control de acceso en imágenes)",
    "backend/tests/test_image_access_control.py (nueva prueba de regresión BUG-001)",
    "docs/sprint5/scripts/*.py (scripts de auditoría, IA y Selenium)",
    "docs/sprint5/evidencias/** (evidencias organizadas por módulo)",
    "Sprint_5_Pruebas_y_Estabilizacion_Lichen_Dreams.docx (este documento)",
]
for a in archivos:
    doc.add_paragraph(a, style="List Bullet")

doc.save(str(OUT))
print("DOCX GENERADO:", OUT)
print("Tamaño:", OUT.stat().st_size, "bytes")
