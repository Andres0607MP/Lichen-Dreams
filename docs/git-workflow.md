# Git Workflow - Lichen Dreams

## Ramas principales del proyecto

El proyecto está organizado con un flujo de trabajo basado en ramas para facilitar el desarrollo colaborativo.

### main
Rama principal del proyecto.  
Contiene únicamente versiones estables y listas para producción.

### develop
Rama de integración general.  
Aquí se unen todos los avances antes de ser pasados a `main`.

### frontend
Rama dedicada al desarrollo de la interfaz de usuario y componentes visuales.

### backend
Rama encargada de la lógica del servidor, APIs y reglas del sistema.

### database
Rama enfocada en la estructura, diseño y conexión de la base de datos.

### ia
Rama destinada a funcionalidades relacionadas con inteligencia artificial o lógica avanzada.

### qa
Rama destinada a pruebas, control de calidad y verificación de errores.

---

## Convención de nombres de ramas

### Nuevas funcionalidades
feature/nombre-funcionalidad

Ejemplo:
feature/login-screen

### Corrección de errores
fix/nombre-error

Ejemplo:
fix/database-connection

---

## Convención de commits

Formato general:
tipo: descripcion

### Tipos más usados
feat: nueva funcionalidad  
fix: corrección de errores  
docs: documentación  
chore: tareas de mantenimiento  

### Ejemplos
feat: pantalla de login creada  
fix: error de conexión a base de datos  
docs: actualización del flujo de git  
chore: configuración inicial del proyecto  

---

## Flujo de trabajo básico

1. Cada desarrollador trabaja en su rama correspondiente.
2. Los cambios se hacen en ramas específicas (frontend, backend, etc.).
3. Luego se integran en `develop`.
4. Cuando todo esté estable, se pasa a `main`.
5. `main` siempre debe contener código funcional y estable.

---

## Reglas del equipo

- No se trabaja directamente en `main`.
- Todo cambio debe hacerse en una rama específica.
- Los commits deben ser claros y descriptivos.
- Se debe evitar mezclar funcionalidades en una sola rama.

---

## Objetivo del flujo Git

Mantener un desarrollo organizado, colaborativo y seguro, evitando conflictos entre áreas del proyecto y asegurando estabilidad en la rama principal.