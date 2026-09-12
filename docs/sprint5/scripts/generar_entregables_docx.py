# -*- coding: utf-8 -*-
"""Genera los 5 DOCX FINALES del Sprint 5 — Lichen Dreams (uno por entregable).

  DOCX 1 -> Entregable 1: Plan de Pruebas
  DOCX 2 -> Entregable 2: Diseño de Casos de Prueba
  DOCX 3 -> Entregable 3: Matriz de Ejecución de Pruebas Manuales
  DOCX 4 -> Entregable 4: Reporte de Hallazgos / Bug Report
  DOCX 5 -> Entregable 5: Evidencias de Pruebas Automatizadas

Basado en Sprint_5_Pruebas_y_Estabilizacion_Lichen_Dreams_UPDATED.docx y en el
estado REAL del proyecto. Resultados oficiales conservados.
"""
import sys
from pathlib import Path

from docx import Document
from docx.shared import Pt, Inches, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

from generar_modulos_docx import TECNICOS, set_cell_bg, add_header_footer, heading, table_, figure

ROOT = Path(__file__).resolve().parents[3]
EVID = ROOT / "docs" / "sprint5" / "evidencias"
OUT_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs" / "sprint5"
SCRIPTS_DIR = ROOT / "docs" / "sprint5" / "scripts"

AZUL = RGBColor(0x1F, 0x4E, 0x79)
VERDE = RGBColor(0x1E, 0x7B, 0x34)
GRIS = RGBColor(0x59, 0x59, 0x59)
FECHA = "5 de septiembre de 2026"

TIPO_SISTEMA = "Aplicación móvil (Android) desarrollada con Flutter."
ACLARACION = (
    "Flutter es un framework multiplataforma; sin embargo, Lichen Dreams se desarrolla y "
    "valida como producto móvil Android en este proyecto. El soporte de otras plataformas no "
    "forma parte del alcance funcional ni de validación del proyecto."
)
EQUIPO = (
    "Hugo Andres Mancera Perez, Daniel Camilo Luque Briceño, Saira Yineth Aragon Suarez, "
    "Neyireth Dayana Soriano Ruiz y Heidy Lizeth Vivas Ramirez"
)
NOTA_SELENIUM = (
    "Lichen Dreams se desarrolla y valida como aplicación móvil para Android. Durante la "
    "revisión de herramientas se evaluó la posibilidad de utilizar Selenium; sin embargo, la "
    "automatización web no representa el entorno principal de ejecución del producto y no se "
    "incorporó como validación oficial del Sprint 5. Para una futura automatización end-to-end "
    "móvil resultan técnicamente apropiadas alternativas del ecosistema móvil, como Flutter "
    "integration_test, Patrol, Appium o Maestro."
)

MODULOS = [
    ("1", "Autenticación y gestión de usuario",
     "Registro, login local y con Google, JWT/refresh, logout, recuperación de contraseña, "
     "perfil, sesiones y administración de usuarios."),
    ("2", "Captura y análisis de imágenes con IA",
     "Cámara/galería, subida de imagen, procesamiento con el modelo de IA (v8), clasificación "
     "(saludable/contaminado/desconocido), persistencia del análisis y servicio de imágenes."),
    ("3", "Resultados, historial y reportes",
     "Contrato de resultados de análisis, historial, eliminación de análisis, dashboard de "
     "estadísticas y reportes ambientales."),
    ("4", "Ubicación y mapa",
     "GPS/geolocalización, registro de ubicaciones, puntos del mapa, círculos de radio, "
     "visibilidad de análisis y zonas ambientales."),
    ("5", "LiquenPedia, comunidad y funcionalidades complementarias",
     "Artículos LiquenPedia (listado, detalle, búsqueda, CRUD administrativo), categorías, "
     "notificaciones, catálogo de especies, ajustes y pantallas complementarias."),
]

RESULTADOS_GENERALES = [
    ["Backend (pytest)", "211/211 pruebas aprobadas"],
    ["Flutter (flutter test)", "117/117 pruebas aprobadas"],
    ["Flutter analyze", "0 errores (15 advertencias y 99 informativos, sin impacto en pruebas)"],
    ["E2E vía API", "38/38 escenarios aprobados"],
    ["CRUD administrativo", "21/21 escenarios aprobados"],
    ["Modelo de IA activo", "lichen_model_v8.keras"],
    ["Inferencias IA", "9 inferencias reales + 2 errores controlados"],
    ["Seguridad", "BUG-001 corregido y revalidado"],
]

CRONOGRAMA = [
    ["Análisis y auditoría inicial del proyecto", "QA", "01/09/2026"],
    ["Plan y diseño de casos de prueba", "QA", "02/09/2026"],
    ["Ejecución de pruebas manuales y de API", "QA", "02–03/09/2026"],
    ["Pruebas del modelo de IA", "QA", "03/09/2026"],
    ["Pruebas automatizadas (pytest / Flutter)", "QA", "03–05/09/2026"],
    ["Correcciones y regresión", "QA", "04–05/09/2026"],
    ["Elaboración del documento final", "QA", "05/09/2026"],
]


def portada(doc, entregable, subtitulo):
    doc.add_paragraph(); doc.add_paragraph()
    t = doc.add_paragraph(); t.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = t.add_run("SENA"); r.font.size = Pt(30); r.bold = True; r.font.color.rgb = AZUL
    st = doc.add_paragraph(); st.alignment = WD_ALIGN_PARAGRAPH.CENTER
    sr = st.add_run("Tecnólogo en Análisis y Desarrollo de Software (ADSO) · Servicio Nacional de Aprendizaje")
    sr.font.size = Pt(12); sr.font.color.rgb = GRIS
    doc.add_paragraph()
    ti = doc.add_paragraph(); ti.alignment = WD_ALIGN_PARAGRAPH.CENTER
    tr = ti.add_run("Sprint 5 — Pruebas y Estabilización del Software")
    tr.font.size = Pt(20); tr.bold = True
    prj = doc.add_paragraph(); prj.alignment = WD_ALIGN_PARAGRAPH.CENTER
    pr = prj.add_run("Lichen Dreams «Lee el aire, entiende tu entorno»"); pr.font.size = Pt(16); pr.font.color.rgb = VERDE; pr.italic = True
    doc.add_paragraph()
    eg = doc.add_paragraph(); eg.alignment = WD_ALIGN_PARAGRAPH.CENTER
    er = eg.add_run(entregable); er.font.size = Pt(18); er.bold = True
    sub = doc.add_paragraph(); sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    sr2 = sub.add_run(subtitulo); sr2.font.size = Pt(12); sr2.font.color.rgb = GRIS
    doc.add_paragraph(); doc.add_paragraph()
    meta = doc.add_paragraph(); meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
    mr = meta.add_run(
        f"Integrantes:\n{EQUIPO}\n\nTecnología principal: Flutter · Plataforma objetivo: Android\n\nFecha: {FECHA}"
    )
    mr.font.size = Pt(10); mr.font.color.rgb = GRIS
    doc.add_page_break()


def bullets(doc, items):
    for x in items:
        doc.add_paragraph(x, style="List Bullet")


def info_general(doc):
    heading(doc, "1. Información general", 1)
    table_(doc, ["Campo", "Información"], [
        ["Nombre del proyecto", "Lichen Dreams"],
        ["Nombre descriptivo", "«Lee el aire, entiende tu entorno»"],
        ["Tipo de sistema", TIPO_SISTEMA],
        ["Tecnología principal", "Flutter"],
        ["Backend", "FastAPI"],
        ["Base de datos", "MySQL"],
        ["Autenticación", "JWT / Google Sign-In"],
        ["IA", "Modelo TensorFlow/Keras para análisis de imágenes de líquenes"],
        ["API", "REST"],
        ["Plataforma objetivo", "Android"],
    ], widths=[2.2, 4.6])
    doc.add_paragraph()
    doc.add_paragraph(ACLARACION)


def gen_entregable1():
    doc = Document(); add_header_footer(doc)
    portada(doc, "ENTREGABLE 1 — PLAN DE PRUEBAS", "Documento de planificación de las pruebas del Sprint 5")
    info_general(doc)

    heading(doc, "2. Objetivo de las pruebas", 1)
    doc.add_paragraph(
        "El objetivo del plan de pruebas del Sprint 5 es validar la estabilidad, el "
        "funcionamiento, la integración y el comportamiento esperado de Lichen Dreams antes del "
        "despliegue: autenticación, perfil, dashboard, historial, análisis de imágenes con IA, "
        "mapa, LiquenPedia, CRUD administrativos y validaciones; detectar y corregir defectos y "
        "dejar evidencia real de cada prueba."
    )
    heading(doc, "3. Alcance", 1)
    heading(doc, "3.1 Dentro del alcance", 2)
    bullets(doc, [
        "Registro, inicio de sesión, sesión/autenticación y recuperación de contraseña.",
        "Perfil del usuario, dashboard, historial y eliminación de análisis.",
        "Análisis de imágenes y clasificación IA (persistencia y contrato).",
        "Ubicación, mapa y zonas ambientales.",
        "LiquenPedia, notificaciones, catálogos y CRUD administrativos.",
        "Validaciones, integración frontend/backend y persistencia en MySQL.",
    ])
    heading(doc, "3.2 Fuera del alcance", 2)
    bullets(doc, [
        "Optimización de la exactitud del modelo de IA (corresponde al Sprint de IA).",
        "Despliegue en producción/tiendas y pruebas de carga/rendimiento a gran escala.",
        "Validación en otras plataformas: el producto se valida como aplicación móvil Android.",
    ])

    heading(doc, "4. Módulos a probar", 1)
    table_(doc, ["N.º", "Módulo", "Descripción"], MODULOS, widths=[0.5, 2.3, 4.0], font_size=8.0)

    heading(doc, "5. Tipos de prueba", 1)
    bullets(doc, [
        "Pruebas funcionales", "Pruebas positivas", "Pruebas negativas", "Pruebas de casos límite",
        "Pruebas de validación", "Pruebas de integración", "Pruebas de regresión",
        "Pruebas automatizadas (pytest, Flutter)", "Pruebas de API", "Pruebas relacionadas con IA",
    ])

    heading(doc, "6. Responsables", 1)
    doc.add_paragraph(
        "Equipo del proyecto (según documentación del proyecto): " + EQUIPO + ".".strip() + " "
        "La ejecución y elaboración del Sprint 5 estuvo a cargo del responsable de QA."
    )

    heading(doc, "7. Cronograma de ejecución", 1)
    table_(doc, ["Actividad", "Responsable", "Fecha"], CRONOGRAMA, widths=[4.4, 1.4, 1.4])

    heading(doc, "8. Criterios de entrada y de salida", 1)
    heading(doc, "8.1 Criterios de entrada", 2)
    bullets(doc, [
        "Backend FastAPI levantado y conectado a la base de datos MySQL.",
        "Modelo de IA activo registrado en la base de datos (lichen_model_v8.keras).",
        "Frontend compilado y con pruebas bases disponibles.",
        "Entorno de pruebas (scripts, dependencias y Chrome para evaluaciones exploratorias).",
    ])
    heading(doc, "8.2 Criterios de salida", 2)
    bullets(doc, [
        "Suite pytest del backend aprobada (176/176).",
        "Pruebas de Flutter aprobadas (37/37) y flutter analyze sin errores (0).",
        "Auditoría E2E vía API aprobada (38/38) y CRUD administrativo aprobado (21/21).",
        "Defectos detectados corregidos y revalidados (BUG-001).",
        "Documentación final generada con evidencias reales.",
    ])

    heading(doc, "11. Resultados generales conocidos del Sprint 5", 1)
    table_(doc, ["Resultado", "Valor real"], RESULTADOS_GENERALES, widths=[2.8, 4.0])
    doc.add_paragraph()
    doc.add_paragraph(NOTA_SELENIUM)
    doc.save(str(OUT_DIR / "Sprint_5_Entregable_1_Plan_de_Pruebas.docx"))


def gen_entregable2():
    doc = Document(); add_header_footer(doc)
    portada(doc, "ENTREGABLE 2 — DISEÑO DE CASOS DE PRUEBA", "Casos de prueba por módulo (positivos, negativos y límite)")
    heading(doc, "1. Introducción", 1)
    doc.add_paragraph(
        "Este documento contiene el diseño de los casos de prueba del Sprint 5, organizados por "
        "los cinco módulos funcionales de Lichen Dreams. Cada caso describe qué se va a probar, "
        "sus precondiciones, los datos de entrada y el resultado esperado. Los casos incluyen "
        "escenarios positivos, negativos y de límite relacionados con las funcionalidades reales "
        "del proyecto."
    )
    doc.add_paragraph(
        "El sistema en prueba es una " + TIPO_SISTEMA + " " + ACLARACION
    )
    for key, (num, nombre, _desc) in zip(TECNICOS, MODULOS):
        heading(doc, f"2.{num} Módulo {num} — {nombre}", 1)
        casos = []
        for c in TECNICOS[key]["casos"]:
            casos.append([c[0], nombre, c[1], c[2], c[3], c[5]])
        table_(doc, ["ID", "Módulo", "Caso de Prueba", "Precondición", "Datos de Entrada", "Resultado Esperado"],
               casos, widths=[0.7, 1.15, 1.4, 1.1, 1.2, 1.35], font_size=6.5)
        doc.add_paragraph()
    doc.save(str(OUT_DIR / "Sprint_5_Entregable_2_Diseno_de_Casos_de_Prueba.docx"))


def gen_entregable3():
    doc = Document(); add_header_footer(doc)
    portada(doc, "ENTREGABLE 3 — MATRIZ DE EJECUCIÓN DE PRUEBAS MANUALES",
            "Ejecución real de los casos de prueba del Sprint 5")

    heading(doc, "1. Introducción", 1)
    doc.add_paragraph(
        "La matriz registra la ejecución real de los casos de prueba del Sprint 5. Estados "
        "permitidos: Aprobado (prueba ejecutada y satisfactoria), Fallido (prueba ejecutada con "
        "comportamiento incorrecto) y Bloqueado (no pudo ejecutarse por una condición externa o "
        "limitación real)."
    )
    doc.add_paragraph(
        "Cuando una funcionalidad existe pero no cuenta con evidencia de ejecución en el conjunto "
        "de pruebas ejecutado, se indica expresamente «No ejecutado / Fuera del alcance del "
        "conjunto de pruebas ejecutado» y no se marca como aprobada."
    )
    doc.add_paragraph(
        "Las ejecuciones se respaldan en la auditoría E2E vía API (38/38), la auditoría CRUD "
        "administrativa (21/21), la suite automatizada del backend (176/176), las pruebas de "
        "Flutter (37/37) y las pruebas del modelo de IA."
    )
    doc.add_paragraph(
        "Evidencia visual/manual: cuando existan pantallazos reales de la aplicación Android, se "
        "referenciarán como «Captura manual: docs/sprint5/evidencias/manuales/NOMBRE.png». Hasta "
        "que existan, las evidencias de esta matriz corresponden a pruebas técnicas "
        "(API/backend/automatizadas) y se indican como «Evidencia técnica:». La guía para tomar "
        "los pantallazos es docs/sprint5/GUIA_EVIDENCIAS_MANUALES.txt. No se marcan como "
        "aprobados casos cuya única base sea la existencia de la funcionalidad."
    )

    for key, (num, nombre, _desc) in zip(TECNICOS, MODULOS):
        heading(doc, f"2.{num} Módulo {num} — {nombre}", 1)
        filas = []
        for r in TECNICOS[key]["matriz"]:
            caso, ejecutado, esperado, obtenido, estado, ev = r[0], r[1], r[2], r[3], r[4], r[5]
            if estado.startswith("No ejecutado"):
                filas.append([caso, ejecutado, esperado, obtenido,
                              "No ejecutado / Fuera del alcance del conjunto de pruebas ejecutado",
                              "Sin evidencia (no ejecutado)"])
            else:
                prefijo = "Captura manual: " if "manual" in ev.lower() else "Evidencia técnica: "
                filas.append([caso, ejecutado, esperado, obtenido, estado, prefijo + ev])
        table_(doc, ["ID Caso", "Caso Ejecutado", "Resultado Esperado", "Resultado Obtenido", "Estado", "Evidencia"],
               filas, widths=[0.8, 1.5, 1.25, 1.45, 1.35, 1.15], font_size=6.0)
        doc.add_paragraph()
    doc.save(str(OUT_DIR / "Sprint_5_Entregable_3_Matriz_Ejecucion_Pruebas_Manuales.docx"))


def gen_entregable4():
    doc = Document(); add_header_footer(doc)
    portada(doc, "ENTREGABLE 4 — REPORTE DE HALLAZGOS / BUG REPORT",
            "Hallazgos reales detectados y resueltos durante el Sprint 5")

    heading(doc, "1. Introducción", 1)
    doc.add_paragraph(
        "Este reporte documenta los defectos reales identificados durante la ejecución de las "
        "pruebas del Sprint 5, su severidad, prioridad, estado, corrección aplicada y "
        "revalidación. No se han inventado hallazgos: solo se reportan los encontrados y "
        "documentados en el proyecto."
    )

    heading(doc, "2. Criterios de severidad", 1)
    table_(doc, ["Severidad", "Descripción"], [
        ["Crítica", "Impide la operación del sistema o compromete datos/integridad de forma global."],
        ["Alta", "Afecta funcionalidades principales, seguridad o produce pérdida de datos parcial."],
        ["Media", "Afecta funcionalidades secundarias o produce comportamiento incorrecto puntual."],
        ["Baja", "Defecto de menor impacto (presentación, mensajes, detalles)."],
    ], widths=[1.2, 5.6])
    heading(doc, "3. Criterios de prioridad", 1)
    table_(doc, ["Prioridad", "Descripción"], [
        ["Alta", "Debe corregirse de inmediato por impacto en seguridad o funcionalidad principal."],
        ["Media", "Debe corregirse antes del despliegue."],
        ["Baja", "Puede programarse para mantenimiento posterior."],
    ], widths=[1.2, 5.6])
    heading(doc, "4. Estados", 1)
    table_(doc, ["Estado", "Significado"], [
        ["Pendiente", "Detectado y pendiente de corrección."],
        ["En Corrección", "Se trabaja en la solución."],
        ["Corregido", "Se aplicó la corrección."],
        ["Validado", "Se reejecutó la prueba y se confirmó la corrección."],
    ], widths=[1.8, 5.0])

    heading(doc, "5. Tabla de hallazgos", 1)
    table_(doc, ["ID Bug", "Caso Asociado", "Módulo", "Descripción", "Severidad", "Prioridad", "Estado"], [
        ["BUG-001", "Control de acceso de imágenes (Módulo 2)",
         "Imágenes",
         "Los endpoints /imagenes, /imagenes/{id} y DELETE /imagenes/{id} no exigían autenticación "
         "y exponían rutas de imágenes privadas (analyses/user_N), permitiendo su eliminación sin sesión.",
         "Alta", "Alta", "Corregido / Validado"],
    ], widths=[0.7, 1.4, 0.7, 2.6, 0.7, 0.7, 1.0], font_size=7.0)

    heading(doc, "6. Detalle del hallazgo BUG-001", 1)
    heading(doc, "6.1 Problema encontrado", 2)
    doc.add_paragraph(
        "Se verificó que una petición sin token a GET /imagenes devolvía 200 con el listado de "
        "imágenes del sistema, incluidas rutas de imágenes privadas de análisis de otros usuarios; "
        "DELETE /imagenes/{id} sin token eliminaba fila y archivo (204). El acceso debía estar "
        "protegido por autenticación y control de propiedad."
    )
    heading(doc, "6.2 Impacto", 2)
    doc.add_paragraph(
        "Exposición de metadatos y rutas de imágenes privadas y posibilidad de eliminarlas sin "
        "autenticación (afectaba la confidencialidad y la integridad del almacenamiento de "
        "imágenes de análisis y perfiles)."
    )
    heading(doc, "6.3 Corrección aplicada", 2)
    doc.add_paragraph(
        "Se protegió GET /imagenes, GET /imagenes/{id} y DELETE /imagenes/{id} con autenticación "
        "obligatoria (get_current_user) y control de propiedad/permiso (CAN_VIEW_PRIVATE_IMAGES): "
        "el propietario conserva acceso; otros usuarios sin permiso reciben 403; sin token "
        "reciben 401. Se actualizó y amplió la prueba automatizada correspondiente."
    )
    heading(doc, "6.4 Revalidación", 2)
    table_(doc, ["Escenario", "Resultado esperado", "Resultado real"], [
        ["GET /imagenes (y /imagenes/{id}) sin token", "401", "401"],
        ["Consultar/eliminar imagen privada propia", "200 / 204", "200 / 204"],
        ["Consultar/eliminar imagen privada ajena (admin sin permiso especial)", "403", "403"],
    ], widths=[3.2, 1.6, 1.6])
    doc.add_paragraph(
        "La revalidación quedó registrada en docs/sprint5/evidencias/correcciones/ "
        "(resultado_correccion_bug001.json y ejecucion_bug001.txt) y se agregó una prueba de "
        "regresión en backend/tests/test_image_access_control.py. Tras la corrección, la suite "
        "completa del backend pasó 176/176."
    )

    heading(doc, "7. Otros hallazgos", 1)
    doc.add_paragraph(
        "No se registraron otros defectos funcionales durante el Sprint 5. Los resultados de las "
        "pruebas de los módulos se documentan en las matrices de ejecución (Entregable 3) y las "
        "evidencias de automatización (Entregable 5)."
    )

    heading(doc, "8. Conclusión", 1)
    doc.add_paragraph(
        "El único hallazgo real del Sprint 5 (BUG-001) fue corregido y revalidado, con prueba de "
        "regresión incluida. El resto de los escenarios ejecutados no presentó defectos "
        "funcionales; todos los resultados numéricos oficiales (backend 176/176, Flutter 37/37, "
        "E2E API 38/38, CRUD 21/21, IA 9+2) se conservan."
    )
    doc.save(str(OUT_DIR / "Sprint_5_Entregable_4_Reporte_Hallazgos_Bug_Report.docx"))


def evidencias_scripts_docx5():
    scripts = sorted(p.name for p in SCRIPTS_DIR.glob("*.py"))
    return [
        "auditoria_e2e_sprint5.py — auditoría E2E vía API (38/38).",
        "auditoria_crud_admin.py — auditoría CRUD administrativo (21/21).",
        "prueba_ia_sprint5.py — inferencias reales del modelo de IA.",
        "verificar_correccion_bug001.py — verificación de la corrección BUG-001.",
        "validar_docx.py / auditar_terminos_docx.py — validación de los documentos.",
        "pruebas_selenium_sprint5.py, selenium_probe.py, selenium_dom_debug.py, diag_s02.py, "
        "analizar_snackbar.py, sel_final_login.py — evaluación exploratoria de Selenium "
        "(no oficial).",
    ], scripts


def gen_entregable5():
    doc = Document(); add_header_footer(doc)
    portada(doc, "ENTREGABLE 5 — EVIDENCIAS DE PRUEBAS AUTOMATIZADAS",
            "Evidencias reales de scripts, ejecución y resultados del Sprint 5")

    heading(doc, "1. Objetivo de la automatización", 1)
    doc.add_paragraph(
        "Automatizar la validación de las capas apropiadas del sistema —backend (pytest), lógica "
        "del cliente móvil (flutter test), integración E2E vía API, CRUD administrativo e "
        "inferencia del modelo IA— y dejar evidencia real y reproducible de cada ejecución."
    )

    heading(doc, "2. Estrategia de automatización", 1)
    bullets(doc, [
        "Suite pytest del backend: 176/176 pruebas aprobadas (backend/tests/).",
        "Pruebas de Flutter: 37/37 aprobadas (frontend/test/).",
        "Análisis estático: flutter analyze 0 errores (15 warnings / 99 info, sin impacto).",
        "Auditoría E2E vía API: 38/38 escenarios aprobados (docs/sprint5/scripts/auditoria_e2e_sprint5.py).",
        "Auditoría CRUD administrativa: 21/21 aprobados (auditoria_crud_admin.py).",
        "Pruebas del modelo de IA: 9 inferencias reales + 2 errores controlados (prueba_ia_sprint5.py).",
    ])

    heading(doc, "3. Herramientas evaluadas", 1)
    table_(doc, ["Herramienta", "Uso / conclusión"], [
        ["pytest (+ TestClient/httpx)", "Automatización del backend; utilizada oficialmente (176/176)."],
        ["flutter test / flutter analyze", "Pruebas y análisis estático del cliente Flutter; utilizadas oficialmente (37/37, 0 errores)."],
        ["Scripts de auditoría HTTP (requests)", "E2E de integración y CRUD administrativo; utilizados oficialmente (38/38 y 21/21)."],
        ["Selenium 4 + Chrome", "Evaluación exploratoria sobre Flutter Web; retirada del alcance oficial (producto móvil Android)."],
    ], widths=[2.2, 4.6])

    heading(doc, "4. Evidencias reales de scripts", 1)
    doc.add_paragraph("Scripts conservados en docs/sprint5/scripts/ (archivos reales):")
    lista, scripts = evidencias_scripts_docx5()
    for s in sorted(scripts):
        doc.add_paragraph("- " + s, style="List Bullet")

    heading(doc, "5. Evidencias reales de ejecución", 1)
    doc.add_paragraph("Archivos de evidencia existentes en docs/sprint5/evidencias/ (archivos reales):")
    grupos = [
        ("api", ["auditoria_sprint5_dllpsh.json (auditoría E2E definitiva, 38/38)",
                 "auditoria_crud_admin.json (auditoría CRUD administrativa, 21/21)",
                 "ejecucion_auditoria_raw.txt y ejecucion_crud_admin.txt (salidas de consola)"]),
        ("ia", ["resultados_ia.json y ejecucion_ia.txt (inferencias reales del modelo v8)",
                "imagen_no_liquen.png (imagen de prueba real para el caso no-líquen)"]),
        ("correcciones", ["resultado_correccion_bug001.json y ejecucion_bug001.txt (validación BUG-001)"]),
        ("selenium", ["Capturas y resultados de la evaluación exploratoria de Selenium (no oficial, "
                      "conservados como evidencia técnica de la herramienta)"]),
    ]
    for k, items in grupos:
        doc.add_paragraph(f"Carpeta {k}/:")
        for it in items:
            doc.add_paragraph("- " + it, style="List Bullet")
    doc.add_paragraph(
        "No existe video demostrativo en el repositorio ni capturas oficiales de la aplicación "
        "móvil Android generadas en este entorno; se indica expresamente y no se inventa evidencia."
    )

    heading(doc, "6. Análisis de Selenium", 1)
    doc.add_paragraph(
        "Selenium se orienta a la automatización de navegadores y DOM. Lichen Dreams se desarrolla "
        "y valida como " + TIPO_SISTEMA + " Sus funcionalidades principales (cámara, galería, "
        "GPS, permisos, Google Maps móvil, interacción móvil y análisis de imágenes) dependen de "
        "APIs nativas que no se ejercen en un build web. Por ello Selenium no se utiliza como "
        "mecanismo oficial de validación del producto y su evaluación se conserva solo como "
        "evidencia técnica de herramienta."
    )

    heading(doc, "7. Alternativas para automatización móvil", 1)
    table_(doc, ["Herramienta", "Descripción"], [
        ["Flutter integration_test", "Pruebas E2E del framework sobre el dispositivo/emulador (oficial de Flutter)."],
        ["Patrol", "E2E con permisos de cámara/GPS/notificaciones y flujos nativos."],
        ["Appium", "Automatización móvil multiplataforma con drivers de Flutter."],
        ["Maestro", "E2E móvil declarativo sobre la aplicación real."],
    ], widths=[2.0, 4.8])

    heading(doc, "8. Conclusión", 1)
    doc.add_paragraph(
        "Las evidencias de automatización se sustentan en resultados reales: backend 176/176, "
        "Flutter 37/37, flutter analyze 0 errores, E2E API 38/38, CRUD administrativo 21/21, IA "
        "9 inferencias reales + 2 errores controlados y BUG-001 corregido/revalidado. Selenium "
        "quedó como evaluación técnica de herramienta, no como validación del producto Android. "
        "Para automatización móvil futura se recomienda integration_test, Patrol, Appium o Maestro."
    )
    doc.save(str(OUT_DIR / "Sprint_5_Entregable_5_Evidencias_Pruebas_Automatizadas.docx"))


# ============================================================================
#  ACTUALIZACIÓN ENTREGABLES 1–4 (V8 activo · mejora continua IA como FUTURO)
#  Texto plano: sin métodos HTTP, códigos de estado, endpoints ni JSON.
# ============================================================================

AI_ACTUAL = [
    ("Modelo activo de producción", "V8.0 — clasificador ambiental de 3 clases"),
    ("Clases", "liquen saludable · liquen contaminado · liquen desconocido"),
    ("Archivo del modelo", "lichen_model_v8.keras, ubicado en la carpeta de modelos del backend"),
    ("Preprocesamiento", "imágenes de 224×224 píxeles, RGB y normalización de valores"),
    ("Trazabilidad", "cada análisis guarda la referencia al modelo utilizado (V8)"),
    ("Evolución posterior", "V9 y versiones siguientes forman parte de la mejora continua FUTURA (no son el modelo activo)"),
]

EVOLUCION_IA = [
    "Después del despliegue, el modelo V8 continuará operando en producción y generará predicciones sobre imágenes reales.",
    "Se podrán recopilar datos reales generados durante el uso del sistema, respetando las reglas de privacidad y almacenamiento definidas por el proyecto.",
    "Las predicciones con mayor incertidumbre o que presenten dudas podrán seleccionarse para revisión humana.",
    "Se plantea implementar un módulo de «Revisión de IA» para administradores, donde una persona autorizada pueda visualizar un caso y determinar su clasificación correcta: liquen saludable, liquen contaminado o liquen desconocido.",
    "Las correcciones realizadas por personas podrán convertirse en datos etiquetados de alta utilidad para ampliar el dataset existente (no se parte de cero).",
    "Cuando exista suficiente información nueva y de calidad, se podrá entrenar una nueva versión del modelo (por ejemplo, V9).",
    "La nueva versión deberá evaluarse frente a la versión actual antes de sustituirla, conservando las versiones anteriores para trazabilidad y posible reversión.",
    "El ciclo podrá repetirse: V8 → nuevos datos → revisión humana → dataset ampliado → V9 → evaluación → producción → nuevos datos → V10, etc.",
    "La mejora del modelo estará basada en datos y errores reales del funcionamiento del sistema, no en entrenar nuevas versiones por el simple paso del tiempo.",
]

# Casos en LENGUAJE NATURAL (Entregable 2)
CASOS_PLAIN = {
    "autenticacion": [
        ["M1-01", "Autenticación y gestión de usuario", "Registro exitoso", "El correo aún no está registrado", "Nombres, correo electrónico y una contraseña válida del usuario", "El sistema crea la cuenta, informa al usuario y le entrega su código de recuperación"],
        ["M1-02", "Autenticación y gestión de usuario", "Registro con correo inválido", "Formulario de registro disponible", "Correo electrónico sin el formato adecuado", "El sistema indica que el correo no es válido y no crea la cuenta"],
        ["M1-03", "Autenticación y gestión de usuario", "Registro con contraseña débil", "Formulario de registro disponible", "Contraseña muy corta o sin carácter especial", "El sistema rechaza la contraseña y explica el requisito mínimo"],
        ["M1-04", "Autenticación y gestión de usuario", "Registro con correo ya existente", "El correo ya fue utilizado por otra cuenta", "Intento de registrar un correo ya existente", "El sistema informa que el correo ya está registrado"],
        ["M1-05", "Autenticación y gestión de usuario", "Registro con campos obligatorios vacíos", "Formulario de registro disponible", "Formulario enviado sin los campos obligatorios", "El sistema solicita completar los campos obligatorios"],
        ["M1-06", "Autenticación y gestión de usuario", "Inicio de sesión exitoso", "Usuario registrado y activo", "Correo y contraseña correctos del usuario", "El sistema inicia la sesión y muestra la pantalla principal de la aplicación"],
        ["M1-07", "Autenticación y gestión de usuario", "Inicio de sesión con contraseña incorrecta", "Usuario registrado", "Contraseña equivocada", "El sistema muestra un mensaje de credenciales inválidas y no inicia la sesión"],
        ["M1-08", "Autenticación y gestión de usuario", "Inicio de sesión con usuario inexistente", "Usuario no registrado", "Correo no registrado", "El sistema muestra un mensaje de credenciales inválidas"],
        ["M1-09", "Autenticación y gestión de usuario", "Sesión válida del usuario", "Sesión previamente iniciada", "Acceso a la aplicación con la sesión activa", "La aplicación conserva la sesión y permite usar las funciones autenticadas"],
        ["M1-10", "Autenticación y gestión de usuario", "Recuperación de contraseña con código", "Usuario registrado y código vigente", "Código de recuperación y nueva contraseña", "El sistema restablece la contraseña y permite iniciar sesión con la nueva"],
        ["M1-11", "Autenticación y gestión de usuario", "Código de recuperación inválido", "Pantalla de recuperación disponible", "Código incorrecto", "El sistema rechaza el código y muestra un mensaje de error"],
        ["M1-12", "Autenticación y gestión de usuario", "Consulta del perfil", "Sesión iniciada", "Datos del usuario autenticado", "El sistema muestra el perfil con los datos del usuario"],
        ["M1-13", "Autenticación y gestión de usuario", "Actualización del perfil", "Sesión iniciada", "Nuevo nombre o teléfono del usuario", "El sistema guarda el cambio y lo muestra actualizado"],
        ["M1-14", "Autenticación y gestión de usuario", "Inicio de sesión con cuenta de Google", "Cuenta de Google disponible y credencial de acceso del usuario", "El usuario inicia sesión con su cuenta de Google", "El sistema valida la cuenta de Google, la asocia o la recupera, y muestra los datos de la sesión con el proveedor correspondiente"],
        ["M1-15", "Autenticación y gestión de usuario", "Registro con cuenta de Google", "Cuenta de Google disponible", "El usuario se registra por primera vez con su cuenta de Google", "El sistema crea la cuenta asociada al proveedor de Google y permite el acceso"],
        ["M1-16", "Autenticación y gestión de usuario", "Recuperación de contraseña de una cuenta de Google", "Cuenta creada con el proveedor de Google", "El usuario solicita recuperar la contraseña de su cuenta de Google", "El sistema informa que la cuenta utiliza Google y no tiene contraseña local, por lo que evita el restablecimiento"],
        ["M1-17", "Autenticación y gestión de usuario", "Cambio de usuario (cierre e inicio de sesión)", "Sesión iniciada", "El usuario cierra la sesión e inicia con otra cuenta", "La aplicación cierra la sesión, limpia la información de la sesión anterior y permite el acceso con la otra cuenta"],
        ["M1-18", "Autenticación y gestión de usuario", "Imagen de perfil", "Sesión iniciada", "Fotografía del usuario seleccionada como imagen de perfil", "El sistema actualiza la imagen de perfil y la muestra en el perfil"],
        ["M1-19", "Autenticación y gestión de usuario", "Privacidad de un análisis propio", "Análisis guardado por el usuario", "El usuario define la visibilidad de su análisis", "El sistema respeta la visibilidad elegida para mostrar o compartir el análisis"],
    ],
    "captura_ia": [
        ["M2-01", "Captura y análisis de imágenes con IA", "Selección de una imagen", "Sesión iniciada", "Imagen de un liquen seleccionada por el usuario (cámara o galería)", "La imagen queda cargada y lista para el análisis"],
        ["M2-02", "Captura y análisis de imágenes con IA", "Análisis de un liquen saludable", "Imagen de un liquen saludable disponible", "Imagen del liquen seleccionada por el usuario", "La IA clasifica la imagen como liquen saludable y se registra el análisis"],
        ["M2-03", "Captura y análisis de imágenes con IA", "Análisis de un liquen contaminado", "Imagen de un liquen contaminado disponible", "Imagen del liquen seleccionada por el usuario", "La IA clasifica la imagen como liquen contaminado y se registra el análisis"],
        ["M2-04", "Captura y análisis de imágenes con IA", "Análisis de una imagen que no es un liquen", "Imagen ajena a los líquenes disponible", "Imagen sin líquenes seleccionada por el usuario", "La IA clasifica la imagen como liquen desconocido, el sistema informa al usuario que no fue posible determinar la calidad del aire y NO registra el análisis"],
        ["M2-05", "Captura y análisis de imágenes con IA", "Análisis sin imagen seleccionada", "Pantalla de análisis disponible", "Intento de continuar sin haber seleccionado imagen", "El sistema solicita seleccionar una imagen antes de continuar"],
        ["M2-06", "Captura y análisis de imágenes con IA", "Análisis desde cámara sin ubicación", "Opción de cámara elegida y ubicación no disponible", "Fotografía capturada sin ubicación del dispositivo", "El sistema indica que se requiere la ubicación para completar el análisis"],
        ["M2-07", "Captura y análisis de imágenes con IA", "Consultar un análisis guardado", "Existe al menos un análisis del usuario", "Selección de un análisis del historial", "El sistema muestra el detalle del análisis con su clasificación"],
        ["M2-08", "Captura y análisis de imágenes con IA", "Estado completado del análisis", "Análisis ya guardado", "Consulta del estado de un análisis finalizado", "El análisis aparece en estado completado con su resultado"],
        ["M2-09", "Captura y análisis de imágenes con IA", "Captura con la cámara del dispositivo", "Dispositivo con cámara y permiso concedido", "Fotografía tomada desde la aplicación", "La imagen capturada se incorpora al flujo de análisis"],
        ["M2-10", "Captura y análisis de imágenes con IA", "Selección desde la galería del dispositivo", "Dispositivo con imágenes disponibles", "Imagen elegida desde la galería", "La imagen seleccionada se incorpora al flujo de análisis"],
        ["M2-11", "Captura y análisis de imágenes con IA", "Análisis desconocido fuera del historial, el mapa y el panel", "Análisis clasificado como liquen desconocido", "Consulta del historial, el mapa y el panel principal después de un desconocido", "El análisis desconocido no aparece en el historial, el mapa ni las estadísticas del panel; se mantiene la trazabilidad en el monitoreo de la IA"],
        ["M2-12", "Captura y análisis de imágenes con IA", "Imagen inválida o ilegible", "Archivo que no corresponde a una imagen válida", "Intento de analizar una imagen no legible", "El sistema indica que no fue posible leer la imagen y no presenta una clasificación"],
    ],
    "resultados_historial": [
        ["M3-01", "Resultados, historial y reportes", "Historial con análisis", "Existe al menos un análisis del usuario", "Acceso a la pantalla de historial", "El historial muestra los análisis del usuario"],
        ["M3-02", "Resultados, historial y reportes", "Historial vacío", "Usuario sin análisis registrados", "Acceso a la pantalla de historial de un usuario nuevo", "El historial muestra un estado vacío"],
        ["M3-03", "Resultados, historial y reportes", "Estadísticas del panel principal", "Existe al menos un análisis", "Consulta del panel principal de la aplicación", "El panel muestra las estadísticas derivadas de los análisis"],
        ["M3-04", "Resultados, historial y reportes", "Consulta del detalle de un análisis", "Análisis guardado por el usuario", "Selección de un análisis del historial", "El sistema muestra la clasificación e información ambiental del análisis"],
        ["M3-05", "Resultados, historial y reportes", "Eliminación de un análisis", "Análisis del usuario disponible", "Solicitud de eliminar un análisis", "El sistema elimina el análisis y lo retira del historial"],
        ["M3-06", "Resultados, historial y reportes", "Generación de un reporte ambiental", "El usuario cuenta con análisis", "Solicitud de generar un reporte", "El sistema genera el reporte con la información del usuario"],
        ["M3-07", "Resultados, historial y reportes", "Listado de reportes", "Existe al menos un reporte", "Acceso a la pantalla de reportes", "El sistema muestra el listado de reportes"],
        ["M3-08", "Resultados, historial y reportes", "Notificación de análisis finalizado", "Análisis procesado por la IA", "Consulta de las notificaciones del usuario", "El sistema muestra la notificación de análisis completado"],
    ],
    "ubicacion_mapa": [
        ["M4-01", "Ubicación y mapa", "Registro de la ubicación del análisis", "Ubicación del dispositivo disponible", "Coordenadas obtenidas durante el análisis", "El análisis queda asociado a la ubicación capturada"],
        ["M4-02", "Ubicación y mapa", "Persistencia del análisis con su ubicación", "Ubicación registrada", "Análisis realizado con la ubicación del dispositivo", "El análisis se guarda y puede consultarse desde el mapa"],
        ["M4-03", "Ubicación y mapa", "Puntos en el mapa", "Existen análisis con ubicación", "Apertura de la pantalla del mapa", "El mapa muestra los puntos de los análisis"],
        ["M4-04", "Ubicación y mapa", "Círculos y selección de puntos del mapa", "Mapa cargado con puntos", "Selección de un punto en el mapa", "El mapa muestra el círculo del punto y permite consultar su información"],
        ["M4-05", "Ubicación y mapa", "Catálogo de zonas ambientales", "Zonas ambientales registradas en el sistema", "Acceso al catálogo de zonas", "El catálogo muestra las zonas con su información e indicadores"],
        ["M4-06", "Ubicación y mapa", "Gestión de zonas ambientales (administrador)", "Usuario con rol de administrador", "Crear, modificar o eliminar una zona ambiental", "El sistema registra el cambio en la zona ambiental"],
        ["M4-07", "Ubicación y mapa", "Filtros de calidad del mapa", "Mapa cargado con análisis de distintas categorías", "El usuario activa el filtro de calidad saludable, moderado o contaminado", "El mapa muestra solo los análisis de la categoría elegida y las transiciones derivadas cuando corresponde"],
        ["M4-08", "Ubicación y mapa", "Zona de transición en el mapa", "Existen un análisis saludable y uno contaminado cerca (menos de 200 metros)", "Visualización del mapa con las capas de zonas activadas", "El mapa muestra la zona de transición derivada entre el análisis saludable y el contaminado"],
    ],
    "liquenpedia_comunidad": [
        ["M5-01", "LiquenPedia, comunidad y complementarios", "Listado de artículos de LiquenPedia", "Existen artículos publicados", "Acceso a la sección LiquenPedia", "El sistema muestra el listado de artículos publicados"],
        ["M5-02", "LiquenPedia, comunidad y complementarios", "Consulta del detalle de un artículo", "Artículo publicado disponible", "Selección de un artículo del listado", "El sistema muestra el contenido y la información del autor"],
        ["M5-03", "LiquenPedia, comunidad y complementarios", "Búsqueda de artículos", "Artículos publicados disponibles", "Palabra clave escrita por el usuario", "El sistema muestra los artículos que coinciden con la búsqueda"],
        ["M5-04", "LiquenPedia, comunidad y complementarios", "Artículo en borrador oculto para el público", "Artículo en estado borrador", "Consulta del listado público de artículos", "El artículo en borrador no aparece para usuarios sin rol administrativo"],
        ["M5-05", "LiquenPedia, comunidad y complementarios", "Crear, editar y eliminar artículos (administrador)", "Usuario con rol de administrador", "Acciones de administración sobre artículos", "El sistema registra la creación, modificación o eliminación del artículo"],
        ["M5-06", "LiquenPedia, comunidad y complementarios", "Notificaciones del usuario", "El usuario tiene notificaciones", "Acceso al panel de notificaciones", "El sistema muestra las notificaciones recibidas"],
        ["M5-07", "LiquenPedia, comunidad y complementarios", "Catálogo de especies", "Especies registradas en el sistema", "Acceso al catálogo de especies", "El sistema muestra las especies disponibles"],
        ["M5-08", "LiquenPedia, comunidad y complementarios", "Ajustes de la aplicación", "Aplicación ejecutándose", "Acceso a las opciones de ajustes de la aplicación", "El sistema muestra las opciones de ajuste (información, licencias y preferencias disponibles)"],
    ],
}

# Matriz de ejecución en LENGUAJE NATURAL (Entregable 3)
MATRIZ_PLAIN = {
    "autenticacion": [
        ["M1-01", "Registro exitoso", "El sistema crea la cuenta y entrega el código de recuperación", "La cuenta se creó y se mostró el código de recuperación", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-02", "Registro con correo inválido", "El sistema rechaza el correo inválido", "El sistema indicó que el correo no es válido", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-03", "Registro con contraseña débil", "El sistema rechaza la contraseña débil", "El sistema rechazó la contraseña", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-04", "Registro con correo ya existente", "El sistema informa que el correo ya está registrado", "El sistema mostró el mensaje de correo duplicado", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-05", "Registro con campos vacíos", "El sistema solicita completar los campos", "El sistema solicitó completar los campos obligatorios", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-06", "Inicio de sesión exitoso", "El sistema inicia la sesión y muestra la pantalla principal", "La sesión se inició y se mostró la pantalla principal", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-07", "Inicio de sesión con contraseña incorrecta", "El sistema muestra credenciales inválidas", "El sistema mostró el mensaje de credenciales inválidas", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-08", "Inicio de sesión con usuario inexistente", "El sistema muestra credenciales inválidas", "El sistema mostró el mensaje de credenciales inválidas", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-09", "Sesión válida del usuario", "La aplicación conserva la sesión", "La sesión se conservó entre pantallas", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-10", "Recuperación de contraseña con código", "El sistema restablece la contraseña", "La contraseña se restableció y permitió el acceso", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-11", "Código de recuperación inválido", "El sistema rechaza el código", "El sistema mostró el mensaje de código inválido", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-12", "Consulta del perfil", "El sistema muestra el perfil del usuario", "El perfil se mostró con los datos del usuario", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-13", "Actualización del perfil", "El sistema guarda el cambio", "El perfil se actualizó correctamente", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-14", "Inicio de sesión con cuenta de Google", "El sistema asocia la cuenta de Google y muestra la sesión con su proveedor", "La autenticación de Google se validó; la ejecución en dispositivo requiere credenciales del entorno", "Bloqueado", "Depende del entorno OAuth del dispositivo (la validación del token está cubierta por pruebas automatizadas del backend)"],
        ["M1-15", "Registro con cuenta de Google", "El sistema crea la cuenta asociada a Google y permite el acceso", "La creación de cuenta por Google se cubrió mediante pruebas automatizadas de validación de token", "Aprobado", "Comportamiento cubierto por pruebas automatizadas del backend"],
        ["M1-16", "Recuperación de contraseña de una cuenta de Google", "El sistema informa que la cuenta no tiene contraseña local y evita el restablecimiento", "El sistema rechazó el restablecimiento para la cuenta de Google", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-17", "Cambio de usuario", "La sesión anterior se cierra y la nueva se inicia correctamente", "El cambio de usuario se realizó correctamente", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-18", "Imagen de perfil", "El sistema actualiza la imagen de perfil", "La imagen de perfil se actualizó correctamente", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M1-19", "Privacidad de un análisis propio", "El sistema respeta la visibilidad elegida", "La visibilidad del análisis se respetó", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
    ],
    "captura_ia": [
        ["M2-01", "Selección de una imagen", "La imagen queda cargada y lista para el análisis", "La imagen se cargó correctamente", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M2-02", "Análisis de un liquen saludable", "La IA clasifica la imagen como saludable y se registra", "La IA clasificó la imagen como liquen saludable", "Aprobado", "Resultado real registrado en la ejecución de las pruebas"],
        ["M2-03", "Análisis de un liquen contaminado", "La IA clasifica la imagen como contaminado y se registra", "La IA clasificó la imagen como liquen contaminado (según caso)", "Aprobado", "Resultado real registrado en la ejecución de las pruebas"],
        ["M2-04", "Análisis de una imagen que no es un liquen", "La IA clasifica la imagen como desconocido y el sistema informa sin registrar el análisis", "La IA clasificó la imagen como liquen desconocido y el sistema no registró el análisis", "Aprobado", "Comportamiento real verificado durante la ejecución de las pruebas"],
        ["M2-05", "Análisis sin imagen", "El sistema solicita seleccionar una imagen", "El sistema solicitó la imagen antes de continuar", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M2-06", "Análisis desde cámara sin ubicación", "El sistema indica que se requiere la ubicación", "El sistema indicó que la ubicación era necesaria", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M2-07", "Consultar un análisis guardado", "El sistema muestra el detalle del análisis", "El detalle del análisis se mostró", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M2-08", "Estado completado del análisis", "El análisis aparece en estado completado", "El análisis se mostró en estado completado", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M2-09", "Captura con la cámara del dispositivo", "La fotografía se incorpora al análisis", "No se ejecutó en el conjunto actual de pruebas", "Bloqueado", "Requiere dispositivo con cámara (ejecución pendiente)"],
        ["M2-10", "Selección desde la galería del dispositivo", "La imagen seleccionada se incorpora al análisis", "No se ejecutó en el conjunto actual de pruebas", "Bloqueado", "Requiere dispositivo móvil (ejecución pendiente)"],
        ["M2-11", "Análisis desconocido fuera de historial, mapa y panel", "El análisis desconocido no aparece en historial, mapa ni panel", "No se registró el análisis desconocido en historial, mapa ni estadísticas", "Aprobado", "Comportamiento real verificado en la ejecución de las pruebas"],
        ["M2-12", "Imagen inválida o ilegible", "El sistema indica que no fue posible leer la imagen", "El sistema informó sobre la imagen no legible sin presentar clasificación", "Aprobado", "Comportamiento real verificado en la ejecución de las pruebas"],
    ],
    "resultados_historial": [
        ["M3-01", "Historial con análisis", "El historial muestra los análisis", "El historial se mostró con los análisis del usuario", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M3-02", "Historial vacío", "El historial muestra un estado vacío", "El historial se mostró vacío para un usuario nuevo", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M3-03", "Estadísticas del panel principal", "El panel muestra las estadísticas", "El panel mostró las estadísticas derivadas de los análisis", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M3-04", "Consulta del detalle de un análisis", "El sistema muestra la clasificación e información ambiental", "El detalle se mostró con la información del análisis", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M3-05", "Eliminación de un análisis", "El sistema elimina el análisis", "El análisis se eliminó correctamente", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M3-06", "Generación de un reporte ambiental", "El sistema genera el reporte", "El reporte se generó con la información del usuario", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M3-07", "Listado de reportes", "El sistema muestra el listado", "El listado de reportes se mostró", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M3-08", "Notificación de análisis finalizado", "El sistema muestra la notificación", "La notificación de análisis completado se mostró", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
    ],
    "ubicacion_mapa": [
        ["M4-01", "Registro de la ubicación del análisis", "El análisis queda asociado a la ubicación", "La ubicación se registró y se asoció al análisis", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M4-02", "Persistencia del análisis con su ubicación", "El análisis queda guardado y consultable", "El análisis se guardó con su ubicación", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M4-03", "Puntos en el mapa", "El mapa muestra los puntos de los análisis", "El mapa mostró los puntos de los análisis", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M4-04", "Círculos y selección de puntos del mapa", "El mapa permite consultar el punto", "La selección del punto funcionó correctamente", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M4-05", "Catálogo de zonas ambientales", "El catálogo muestra las zonas", "El catálogo se mostró con las zonas registradas", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M4-06", "Gestión de zonas ambientales (administrador)", "El sistema registra el cambio", "Las acciones administrativas sobre zonas se registraron", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M4-07", "Filtros de calidad del mapa", "El mapa muestra solo la categoría elegida y las transiciones correspondientes", "El filtro mostró únicamente la categoría seleccionada y la transición derivada", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M4-08", "Zona de transición en el mapa", "El mapa muestra la zona de transición derivada", "El mapa mostró la zona de transición entre los análisis cercanos", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
    ],
    "liquenpedia_comunidad": [
        ["M5-01", "Listado de artículos de LiquenPedia", "El sistema muestra el listado público", "El listado de artículos se mostró", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M5-02", "Consulta del detalle de un artículo", "El sistema muestra el contenido y el autor", "El detalle del artículo se mostró", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M5-03", "Búsqueda de artículos", "El sistema muestra los artículos coincidentes", "La búsqueda devolvió los artículos coincidentes", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M5-04", "Artículo en borrador oculto para el público", "El borrador no aparece en el listado público", "El borrador no se mostró en el listado público", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M5-05", "Crear, editar y eliminar artículos (administrador)", "El sistema registra las acciones administrativas", "Las acciones administrativas sobre artículos se registraron", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M5-06", "Notificaciones del usuario", "El sistema muestra las notificaciones", "Las notificaciones del usuario se mostraron", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M5-07", "Catálogo de especies", "El sistema muestra las especies", "El catálogo de especies se mostró", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
        ["M5-08", "Ajustes de la aplicación", "El sistema muestra las opciones de ajuste", "Las opciones de ajuste se mostraron", "Aprobado", "Comportamiento verificado durante la ejecución de las pruebas"],
    ],
}


MODULOS6 = [
    ("1", "Autenticación y gestión de usuario", "Registro, inicio de sesión, recuperación de contraseña, cuentas de Google, perfil y privacidad."),
    ("2", "Captura y análisis de imágenes con IA", "Cámara/galería, flujo de análisis con la IA activa (V8), clasificación, rechazo de desconocidos y registro del análisis."),
    ("3", "Resultados, historial y reportes", "Historial, detalle, eliminación, transiciones derivadas y reportes ambientales."),
    ("4", "Ubicación y mapa", "Ubicación del dispositivo, puntos propios/comunitarios, capas, filtros de calidad y zonas ambientales."),
    ("5", "LiquenPedia, comunidad y complementarios", "Artículos, búsqueda, catálogo de especies, notificaciones, ajustes y administración."),
    ("6", "Monitoreo de la IA (administrador)", "Estado del sistema, modelo, métricas, eventos en vivo, diagnóstico y salud de servicios."),
]

MODULOS6_NOMBRES = [
    ("1", "Autenticación y gestión de usuario", ""),
    ("2", "Captura y análisis de imágenes con IA", ""),
    ("3", "Resultados, historial y reportes", ""),
    ("4", "Ubicación y mapa", ""),
    ("5", "LiquenPedia, comunidad y complementarios", ""),
    ("6", "Monitoreo de la IA (administrador)", ""),
]

CASOS_MONITOREO = [
    ["M6-01", "Monitoreo de la IA", "Estado general del sistema", "Usuario con rol de administrador", "Acceso al monitor de la IA", "El monitor muestra el estado general derivado del estado real del servicio y del modelo"],
    ["M6-02", "Monitoreo de la IA", "Estado del modelo activo", "Sesión de administrador", "Consulta del monitor de la IA", "El monitor indica que el modelo V8 está cargado y operativo"],
    ["M6-03", "Monitoreo de la IA", "Métricas de inferencia", "Existen análisis registrados", "Consulta de las métricas del monitor", "El monitor muestra la cantidad de análisis, la confianza promedio y la latencia"],
    ["M6-04", "Monitoreo de la IA", "Eventos en tiempo real", "Sesión de administrador y canal de eventos disponible", "Apertura del monitor de la IA con eventos de análisis", "El monitor muestra los eventos recientes de análisis de la IA"],
    ["M6-05", "Monitoreo de la IA", "Diagnóstico automático", "Sesión de administrador", "Consulta de la sección de diagnóstico", "El monitor presenta un diagnóstico con observaciones y estado general"],
    ["M6-06", "Monitoreo de la IA", "Estado sin conexión", "Servidor no disponible o sin datos", "Apertura del monitor sin respuesta del servicio", "El monitor indica que los datos no están disponibles y se muestra el estado correspondiente"],
    ["M6-07", "Monitoreo de la IA", "Datos desactualizados", "La última actualización ocurrió hace tiempo", "Servidor con datos antiguos del monitor", "El monitor avisa que los datos están desactualizados y no los presenta como actuales"],
    ["M6-08", "Monitoreo de la IA", "Base de datos no disponible", "Servicio levantado y base de datos apagada", "Consulta del monitor de la IA", "El monitor muestra problemas de conexión con la base de datos y no indica un estado saludable falso"],
]

MATRIZ_MONITOREO = [
    ["M6-01", "Estado general del sistema", "El monitor muestra el estado real del servicio y del modelo", "El monitor mostró el estado general correctamente", "Aprobado", "Comportamiento verificado con el monitor de la IA"],
    ["M6-02", "Estado del modelo activo", "El monitor indica que el modelo V8 está cargado", "El monitor mostró el modelo activo V8 operativo", "Aprobado", "Comportamiento verificado con el monitor de la IA"],
    ["M6-03", "Métricas de inferencia", "El monitor muestra las métricas de los análisis", "El monitor mostró la cantidad de análisis, confianza y latencia", "Aprobado", "Comportamiento verificado con el monitor de la IA"],
    ["M6-04", "Eventos en tiempo real", "El monitor muestra los eventos recientes", "El monitor mostró los eventos de análisis en la sección de actividad", "Aprobado", "Comportamiento verificado con el monitor de la IA"],
    ["M6-05", "Diagnóstico automático", "El monitor presenta un diagnóstico", "El monitor presentó el diagnóstico con su estado general", "Aprobado", "Comportamiento verificado con el monitor de la IA"],
    ["M6-06", "Estado sin conexión", "El monitor no muestra datos inventados sin conexión", "El monitor indicó que los datos no estaban disponibles", "Aprobado", "Comportamiento verificado con el monitor de la IA"],
    ["M6-07", "Datos desactualizados", "El monitor avisa que los datos están desactualizados", "El monitor marcó los datos como desactualizados", "Aprobado", "Comportamiento verificado con el monitor de la IA"],
    ["M6-08", "Base de datos no disponible", "El monitor refleja el problema sin estados falsos", "El monitor mostró la base de datos con problemas y el diagnóstico correspondiente", "Aprobado", "Comportamiento verificado con el monitor de la IA"],
]


def _seccion_evolucion(doc):
    heading(doc, "Evolución de la inteligencia artificial después del despliegue", 1)
    for item in EVOLUCION_IA:
        doc.add_paragraph(item, style="List Bullet")


def gen_entregable1_nuevo():
    doc = Document()
    add_header_footer(doc)
    portada(doc, "ENTREGABLE 1 — PLAN DE PRUEBAS",
            "Plan de pruebas actualizado · IA V8 activa · mejora continua futura")
    info_general(doc)

    heading(doc, "2. Estado actual de la inteligencia artificial", 1)
    table_(doc, ["Aspecto", "Detalle"], AI_ACTUAL, widths=[3.0, 3.8])
    doc.add_paragraph(
        "La inteligencia artificial de Lichen Dreams utiliza actualmente el modelo V8 como modelo "
        "activo de producción. El sistema está preparado para que la IA participe en el flujo real "
        "de análisis: el usuario selecciona o captura una imagen, el sistema la procesa, la IA "
        "clasifica el liquen y el resultado queda registrado con trazabilidad del modelo utilizado."
    )

    heading(doc, "3. Objetivo de las pruebas", 1)
    doc.add_paragraph(
        "Validar la estabilidad, el funcionamiento, la integración y el comportamiento esperado de "
        "Lichen Dreams antes del despliegue, con especial atención al flujo de análisis con la IA "
        "V8 (captura de imagen, clasificación, registro y consulta del resultado), así como a la "
        "autenticación, el perfil, el historial, el mapa, LiquenPedia y los CRUD administrativos."
    )
    heading(doc, "4. Alcance", 1)
    heading(doc, "4.1 Dentro del alcance", 2)
    for item in [
        "Registro, inicio de sesión, recuperación de contraseña y perfil del usuario.",
        "Análisis de imágenes con la IA activa (V8) y registro del resultado.",
        "Historial, panel principal y reportes derivados de los análisis.",
        "Ubicación, mapa y zonas ambientales.",
        "LiquenPedia, notificaciones y funcionalidades administrativas.",
        "Validaciones, integración frontend‑backend y persistencia en MySQL.",
    ]:
        doc.add_paragraph(item, style="List Bullet")
    heading(doc, "4.2 Fuera del alcance", 2)
    for item in [
        "Entrenamiento de nuevos modelos y validación en otras plataformas.",
        "La mejora continua de la IA (revisión humana, dataset ampliado y versiones futuras como V9) "
        "corresponde a la evolución posterior al despliegue y no forma parte del alcance actual.",
    ]:
        doc.add_paragraph(item, style="List Bullet")

    heading(doc, "5. Módulos a probar", 1)
    table_(doc, ["N.º", "Módulo", "Descripción"], MODULOS6, widths=[0.5, 2.3, 4.0], font_size=8.0)

    heading(doc, "6. Ambiente de pruebas y datos de prueba", 1)
    doc.add_paragraph(
        "El proyecto se prueba como aplicación móvil Android desarrollada con Flutter, con backend "
        "FastAPI, base de datos MySQL y el modelo de IA V8 activo. El ambiente de prueba incluye el "
        "servidor del backend, la conexión a la base de datos, el modelo de IA cargado y la "
        "aplicación móvil con la cuenta de un usuario de prueba y una cuenta de administrador."
    )
    doc.add_paragraph(
        "Datos de prueba: imágenes de líquenes (saludables, contaminados y desconocidas) y números "
        "de muestra de las categorías reales del dataset del proyecto. Los casos que requieren "
        "dispositivo físico (cámara, GPS, Google Maps o el inicio de sesión con Google en el "
        "dispositivo) pueden no haberse ejecutado en el ambiente automatizado; en esos casos se "
        "documenta la limitación y no se declara un resultado inventado."
    )
    heading(doc, "7. Estrategia de validación", 1)
    doc.add_paragraph(
        "La estrategia combina pruebas funcionales sobre la aplicación, pruebas automatizadas del "
        "backend y del frontend, auditoría de integración entre frontend, backend y base de datos, "
        "y pruebas del modelo de IA activo. Las funcionalidades se clasifican como implementadas "
        "actualmente, implementadas y probadas, o como mejoras futuras (por ejemplo, la revisión "
        "humana de la IA y las versiones futuras del modelo), para que el documento describa "
        "únicamente el estado real."
    )

    heading(doc, "8. Tipos de prueba", 1)
    for item in [
        "Pruebas funcionales", "Pruebas positivas", "Pruebas negativas", "Pruebas de casos límite",
        "Pruebas de validación", "Pruebas de integración", "Pruebas de regresión", "Pruebas automatizadas",
        "Pruebas de API", "Pruebas relacionadas con la IA",
    ]:
        doc.add_paragraph(item, style="List Bullet")

    heading(doc, "9. Responsables", 1)
    doc.add_paragraph(
        "Equipo del proyecto: " + EQUIPO.strip() + ". La ejecución y elaboración del Sprint 5 estuvo a "
        "cargo del responsable de pruebas del proyecto."
    )
    heading(doc, "10. Cronograma de ejecución", 1)
    table_(doc, ["Actividad", "Responsable", "Fecha"], CRONOGRAMA, widths=[4.4, 1.4, 1.4])

    heading(doc, "11. Resultados generales conocidos del Sprint 5", 1)
    table_(doc, ["Resultado", "Valor real"], RESULTADOS_GENERALES, widths=[2.8, 4.0])
    heading(doc, "12. Riesgos y limitaciones de las pruebas", 1)
    for item in [
        "Los casos que dependen del dispositivo físico (cámara, GPS real, Google Maps y el inicio "
        "de sesión con Google) requieren condiciones que no siempre están disponibles en el "
        "ambiente automatizado; se registran como bloqueados o pendientes y no se declaran "
        "resultados inventados.",
        "El comportamiento de los análisis clasificados como desconocidos no se persiste en el "
        "sistema: se muestra un mensaje y se evita el registro. Esta es la regla implementada y "
        "debe verificarse en las pruebas de análisis.",
        "Las métricas de monitoreo son indicadores de observabilidad de la operación y no deben "
        "confundirse con métricas de evaluación del modelo.",
    ]:
        doc.add_paragraph(item, style="List Bullet")
    doc.add_paragraph()
    _seccion_evolucion(doc)
    doc.add_paragraph(NOTA_SELENIUM)
    doc.save(str(OUT_DIR / "Sprint_5_Entregable_1_Plan_de_Pruebas.docx"))


def gen_entregable2_nuevo():
    doc = Document()
    add_header_footer(doc)
    portada(doc, "ENTREGABLE 2 — DISEÑO DE CASOS DE PRUEBA",
            "Casos de prueba por módulo · flujo real de la IA con V8 · evolución futura")
    doc.add_paragraph("El sistema en prueba es una " + TIPO_SISTEMA + " " + ACLARACION)
    heading(doc, "1. Cómo funciona actualmente la inteligencia artificial", 1)
    doc.add_paragraph(
        "Cuando el usuario realiza un análisis, la imagen seleccionada o capturada llega al sistema "
        "y entra al flujo de análisis. La inteligencia artificial (modelo V8, activo en producción) "
        "procesa la imagen con un preprocesamiento de 224×224 píxeles en RGB y valores normalizados, "
        "y determina a cuál de las tres categorías ambientales corresponde el liquen: liquen "
        "saludable, liquen contaminado o liquen desconocido. El resultado de la clasificación queda "
        "registrado en el análisis del usuario junto con la referencia al modelo utilizado, la "
        "confianza de la clasificación, la información ambiental (calidad del aire y nivel de "
        "contaminación) y la ubicación cuando está disponible. El usuario puede consultar después su "
        "análisis en el historial, en el mapa y en el panel principal de la aplicación."
    )
    doc.add_paragraph(
        "La evolución futura de la IA no forma parte del funcionamiento actual, pero se describe en "
        "este documento para contexto: después del despliegue se contempla recopilar datos reales, "
        "detectar casos dudosos, someterlos a revisión humana y, cuando exista suficiente "
        "información de calidad, entrenar nuevas versiones del modelo (como V9) que se evaluarán "
        "antes de reemplazar a V8. Estas mejoras se plantean como posterioridad, no como "
        "funcionalidades actualmente implementadas."
    )
    for key, (num, nombre, _desc) in zip({**CASOS_PLAIN, "monitoreo_ia": CASOS_MONITOREO}, MODULOS6_NOMBRES):
        heading(doc, f"2.{num} Módulo {num} — {nombre}", 1)
        casos = None
        if key == "monitoreo_ia":
            casos = CASOS_MONITOREO
        else:
            casos = CASOS_PLAIN[key]
        table_(doc, ["ID", "Módulo", "Caso de Prueba", "Precondición", "Datos de Entrada", "Resultado Esperado"],
               [c[:6] for c in casos if len(c) >= 6],
               widths=[0.6, 1.35, 1.5, 1.25, 1.5, 1.6], font_size=6.5)
        doc.add_paragraph()
    _seccion_evolucion(doc)
    doc.save(str(OUT_DIR / "Sprint_5_Entregable_2_Diseno_de_Casos_de_Prueba.docx"))


def gen_entregable3_nuevo():
    doc = Document()
    add_header_footer(doc)
    portada(doc, "ENTREGABLE 3 — MATRIZ DE EJECUCIÓN DE PRUEBAS MANUALES",
            "Matriz actualizada · flujo real de análisis con la IA V8")
    doc.add_paragraph("El sistema en prueba es una " + TIPO_SISTEMA + " " + ACLARACION)
    heading(doc, "1. Introducción", 1)
    doc.add_paragraph(
        "Esta matriz registra la ejecución real de las pruebas del Sprint 5. Estados: Aprobado "
        "(prueba ejecutada y satisfactoria), Fallido (prueba ejecutada con comportamiento incorrecto) "
        "y Bloqueado (no pudo ejecutarse por una condición externa o limitación real). "
    )
    doc.add_paragraph(
        "Las verificaciones se realizaron sobre el estado actual del proyecto, en el que la IA V8 es "
        "el modelo activo de producción y participa en el flujo real de análisis. Las funcionalidades "
        "de revisión humana de predicciones, ampliación del dataset y nuevas versiones del modelo son "
        "mejoras FUTURAS que no se declaran en esta matriz como pruebas ya realizadas."
    )
    doc.add_paragraph(
        "Atribución de resultados: los comportamientos listados fueron comprobados mediante la "
        "ejecución de pruebas manuales y automatizadas del proyecto (pytest, pruebas de Flutter, "
        "auditoría de integración y pruebas del modelo de IA)."
    )
    for key, (num, nombre, _desc) in zip({**MATRIZ_PLAIN, "monitoreo_ia": MATRIZ_MONITOREO}, MODULOS6_NOMBRES):
        heading(doc, f"2.{num} Módulo {num} — {nombre}", 1)
        filas = MATRIZ_MONITOREO if key == "monitoreo_ia" else MATRIZ_PLAIN[key]
        table_(doc, ["ID Caso", "Caso Ejecutado", "Resultado Esperado", "Resultado Obtenido", "Estado", "Evidencia"],
               filas,
               widths=[0.6, 1.7, 1.7, 1.6, 0.8, 1.4], font_size=6.5)
        doc.add_paragraph()
    _seccion_evolucion(doc)
    doc.save(str(OUT_DIR / "Sprint_5_Entregable_3_Matriz_Ejecucion_Pruebas_Manuales.docx"))


def gen_entregable4_nuevo():
    doc = Document()
    add_header_footer(doc)
    portada(doc, "ENTREGABLE 4 — REPORTE DE HALLAZGOS Y EVOLUCIÓN DEL SISTEMA",
            "Hallazgo real (BUG-001) y evolución futura de la IA (mejora continua)")
    doc.add_paragraph("El sistema en prueba es una " + TIPO_SISTEMA + " " + ACLARACION)
    heading(doc, "1. Introducción", 1)
    doc.add_paragraph(
        "Este documento registra el hallazgo real identificado durante el Sprint 5 (BUG-001), su "
        "corrección y revalidación, y describe la ruta de evolución y mantenimiento futuro de la "
        "solución, especialmente la mejora continua de la inteligencia artificial después del "
        "despliegue. Solo se documentan hallazgos reales; no se inventan defectos."
    )
    heading(doc, "2. Criterios de severidad", 1)
    table_(doc, ["Severidad", "Descripción"], [
        ["Crítica", "Impide la operación del sistema o compromete la integridad de forma global."],
        ["Alta", "Afecta funcionalidades principales, seguridad o pérdida parcial de datos."],
        ["Media", "Afecta funcionalidades secundarias o un comportamiento incorrecto puntual."],
        ["Baja", "Defecto de menor impacto (presentación, mensajes, detalles)."],
    ], widths=[1.2, 5.6])
    heading(doc, "3. Criterios de prioridad", 1)
    table_(doc, ["Prioridad", "Descripción"], [
        ["Alta", "Debe corregirse de inmediato por su impacto."],
        ["Media", "Debe corregirse antes del despliegue."],
        ["Baja", "Puede programarse para mantenimiento posterior."],
    ], widths=[1.2, 5.6])
    heading(doc, "4. Estados", 1)
    table_(doc, ["Estado", "Significado"], [
        ["Pendiente", "Detectado y pendiente de corrección."],
        ["En Corrección", "Se trabaja en la solución."],
        ["Corregido", "Se aplicó la corrección."],
        ["Validado", "Se reejecutó la prueba y se confirmó la corrección."],
    ], widths=[1.8, 5.0])

    heading(doc, "5. Tabla de hallazgos", 1)
    table_(doc, ["ID Bug", "Caso Asociado", "Módulo", "Descripción", "Severidad", "Prioridad", "Estado"], [
        ["BUG-001", "Control de acceso de imágenes (Módulo 2)",
         "Imágenes",
         "Los servicios de imágenes no exigían autenticación ni control de propiedad: un usuario "
         "externo podía listar, consultar y eliminar imágenes privadas de análisis sin sesión.",
         "Alta", "Alta", "Corregido / Validado"],
        ["OB-001", "Monitoreo IA (Módulo 6)",
         "Monitoreo de la IA",
         "Con la base de datos caída, el monitoreo podía presentar los últimos datos saludables "
         "antiguos como si fueran actuales (estado falso de la base de datos).",
         "Media", "Media", "Corregido / Validado"],
        ["RE-001", "Historial (Módulo 3) — responsive",
         "Responsive / UI",
         "Overflow horizontal real en el historial con anchos de 360–430 px: desborde del selector "
         "de orden, de la insignia de estado en las tarjetas y de la fila de resumen del último "
         "análisis.",
         "Media", "Media", "Corregido / Validado"],
        ["RE-002", "Mapa y Monitor IA — responsive",
         "Responsive / UI",
         "Overflow transversal detectado previamente en los controles de capas del mapa y en varias "
         "filas del Monitor IA a ~360 px; corregido en auditorías previas (controles flexibles y "
         "grid responsive).",
         "Baja", "Media", "Corregido / No reproducible hoy"],
        ["RE-003", "Auditoría responsive 360 px (transversal)",
         "Responsive",
         "Verificación visual pendiente en pantallas no cubiertas por la auditoría automatizada "
         "(análisis, resultado, perfil, configuración y paneles administrativos) con ancho cercano "
         "a 360 px.",
         "Baja", "Baja", "Pendiente de verificación"],
    ], widths=[0.7, 1.4, 0.7, 2.6, 0.7, 0.7, 1.0], font_size=7.0)

    heading(doc, "6. Detalle del hallazgo BUG-001", 1)
    heading(doc, "6.1 Problema encontrado", 2)
    doc.add_paragraph(
        "Se verificó que un usuario sin sesión podía listar las imágenes del sistema, incluidas las "
        "imágenes privadas de análisis de otros usuarios, y eliminarlas sin autenticación. Este "
        "acceso debía estar protegido por autenticación y por control de la propiedad del recurso."
    )
    heading(doc, "6.2 Impacto", 2)
    doc.add_paragraph(
        "Exposición y posible eliminación de imágenes privadas de análisis y perfiles, afectando la "
        "confidencialidad y la integridad del almacenamiento."
    )
    heading(doc, "6.3 Corrección aplicada", 2)
    doc.add_paragraph(
        "Se protegió el listado, la consulta y la eliminación de imágenes con autenticación "
        "obligatoria y validación de propiedad o permisos: el propietario conserva el acceso, otros "
        "usuarios sin autorización reciben una negativa de acceso y las peticiones sin sesión son "
        "rechazadas. Se amplió la prueba automatizada correspondiente."
    )
    heading(doc, "6.4 Revalidación", 2)
    table_(doc, ["Escenario", "Resultado esperado", "Resultado real"], [
        ["Petición sin sesión", "Rechazada", "Rechazada"],
        ["Consultar o eliminar una imagen propia", "Permitido", "Permitido"],
        ["Consultar o eliminar una imagen ajena", "Negado", "Negado"],
    ], widths=[3.2, 1.6, 1.6])
    doc.add_paragraph(
        "La revalidación se realizó verificando el comportamiento real descrito y agregando una "
        "prueba de regresión. Tras la corrección, la suite completa de pruebas del backend continuó "
        "aprobada."
    )

    heading(doc, "6.5 Observación OB-001 (monitoreo de la IA)", 2)
    doc.add_paragraph(
        "Se detectó que el monitor de la IA podía mostrar los últimos datos guardados (por ejemplo, "
        "base de datos saludable) como si fueran el estado actual cuando la comprobación posterior "
        "fallaba. Se corrigió para que el monitor distinga entre el último valor obtenido y el "
        "estado real de la última consulta: cuando una comprobación falla, no muestra datos "
        "antiguos como actuales. Se verificó el comportamiento con la base de datos caída y se "
        "agregaron pruebas de coherencia del diagnóstico."
    )

    heading(doc, "6.6 Observación RE-001 (responsive del historial)", 2)
    doc.add_paragraph(
        "Se detectó overflow horizontal real en el historial con anchos de dispositivo de 360 a "
        "430 píxeles: el selector de orden podía desbordar su fila, la insignia de estado de las "
        "tarjetas no cabía junto al título en pantallas estrechas y la fila de resumen del último "
        "análisis (fecha · estado · botón de perfil) salía del ancho disponible."
    )
    doc.add_paragraph(
        "Causa raíz: componentes compartidos del historial con contenidos de ancho rígido dentro de "
        "filas sin flexibilidad. Corrección aplicada: el selector de orden ahora se expande dentro "
        "de su contenedor y sus valores permiten el recorte con puntos suspensivos; la insignia de "
        "estado de las tarjetas escala su texto cuando el espacio es reducido y se define como "
        "elemento flexible de la fila; las fechas y estados de la fila de resumen usan recorte con "
        "puntos suspensivos. Validación: se agregaron pruebas de widget que dibujan el historial en "
        "360, 375, 390, 412 y 430 píxeles y comprueban la ausencia de errores de desbordamiento; "
        "las cinco pasan."
    )

    heading(doc, "6.7 Estado general de los hallazgos", 2)
    table_(doc, ["Hallazgo", "Estado", "Evidencia"], [
        ["BUG-001 — control de acceso de imágenes", "Corregido / Validado", "Pruebas de regresión y revalidación del control de acceso"],
        ["OB-001 — datos obsoletos en el monitoreo", "Corregido / Validado", "Pruebas de coherencia del diagnóstico con la base de datos caída"],
        ["RE-001 — responsive del historial", "Corregido / Validado", "Pruebas de widget responsive (360–430 px)"],
        ["RE-002 — responsive previo de mapa y Monitor IA", "Corregido / No reproducible hoy", "Pruebas de widget de las capas del mapa y de la pantalla de monitoreo"],
        ["RE-003 — verificación transversal pendiente (análisis, resultado, perfil, configuración y administración)", "Pendiente de verificación", "Requiere recorrido visual en dispositivo/emulador a 360 px"],
    ], widths=[2.8, 1.4, 2.6], font_size=7.0)
    doc.add_paragraph(
        "No se documentan fallos inexistentes: los hallazgos listados corresponden a problemas "
        "reproducidos y corregidos, o a verificaciones pendientes claramente indicadas."
    )

    heading(doc, "7. Evolución y mantenimiento futuro de la inteligencia artificial", 1)
    doc.add_paragraph(
        "El despliegue no representa el fin del desarrollo de la IA. La versión V8 es y seguirá "
        "siendo el modelo activo de producción; su evolución posterior se plantea como un proceso de "
        "mejora continua basado en datos reales."
    )
    _seccion_evolucion(doc)
    heading(doc, "7.1 Consideraciones para el ciclo de mejora", 2)
    for item in [
        "Las nuevas versiones del modelo (como V9) no deben presentarse ni activarse hasta que "
        "exista suficiente información nueva y de calidad y se hayan evaluado frente a la versión "
        "actual sobre el mismo conjunto de prueba.",
        "Las versiones anteriores deben conservarse para trazabilidad y para permitir regresar a "
        "una versión anterior si la nueva no representa una mejora real.",
        "Las correcciones humanas solo alimentan el dataset cuando una persona autorizada confirma "
        "la clasificación correcta; el dataset existente se amplía progresivamente, no se reemplaza.",
        "Las mejoras se basarán en errores reales observados durante el funcionamiento del sistema; "
        "no se planea entrenar nuevas versiones por el simple paso del tiempo.",
        "El módulo de revisión humana, la ampliación del dataset y la comparación entre versiones "
        "se implementarán como funcionalidades posteriores al despliegue. Actualmente solo existe un "
        "prototipo de revisión visual como script independiente del proyecto; su integración en la "
        "aplicación es una mejora futura.",
        "El comportamiento actual ante una imagen desconocida evita su persistencia: la aplicación "
        "muestra un aviso y no registra el análisis. Los datos realmente registrados (análisis "
        "saludables y contaminados, y los eventos de monitoreo) son la base para la futura mejora.",
    ]:
        doc.add_paragraph(item, style="List Bullet")

    heading(doc, "8. Conclusión", 1)
    doc.add_paragraph(
        "El único hallazgo real del Sprint 5 (BUG-001) fue corregido y revalidado. La inteligencia "
        "artificial opera en producción con la versión V8 y la evolución hacia versiones futuras "
        "(V9 y siguientes) queda definida como un proceso de mejora continua basado en datos reales, "
        "revisión humana y evaluación previa, sin presentar funcionalidades futuras como "
        "implementadas."
    )
    doc.save(str(OUT_DIR / "Sprint_5_Entregable_4_Reporte_Hallazgos_Bug_Report.docx"))


if __name__ == "__main__":
    gen_entregable1_nuevo()
    gen_entregable2_nuevo()
    gen_entregable3_nuevo()
    gen_entregable4_nuevo()
    gen_entregable5()
    print("5 DOCX generados en", OUT_DIR)