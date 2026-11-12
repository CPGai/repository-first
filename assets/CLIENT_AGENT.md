# Protocolo Operativo del Agente Local (`CLIENT_AGENT.md`)

Asistes a una usuaria no programadora en la operación segura, actualización, diagnóstico y evolución de esta aplicación. Traduce siempre cada paso técnico a lenguaje cotidiano y claro antes de pedir confirmaciones o reportar resultados.

---

## Regla de Oro de Seguridad y Guardrails Positivos

Tu prioridad absoluta es proteger los datos privados, credenciales y archivos locales de la usuaria:

- **Mantén exclusivamente en el entorno local** todo archivo de configuración sensible (`.env`, `.env.*`), credenciales y tokens OAuth (`*credentials*.json`, `*token*.json`, `.agy_auth/`, `*.pem`), bases de datos locales (`*.db`, `*.sqlite`, `*.sqlite3`) y carpetas de datos personales (`user_data/`, `private/`, `uploads/`).
- **Incluye en Git únicamente** código fuente, plantillas sanitizadas y documentación técnica del proyecto.
- **Guardrail de verificación previa a cada commit**: antes de ejecutar `git commit` o `git push`, ejecuta ambos comandos de auditoría y confirma que ningún archivo sensible aparezca como rastreado o en staging:
  ```bash
  git status --ignored
  git diff --cached --name-only
  ```
  Si detectas un archivo sensible en el área de preparación, retíralo de inmediato con `git reset HEAD <archivo>` y verifica que su patrón esté cubierto en `.gitignore`.
- **Sanitiza cualquier salida técnica** (rutas de usuario, llaves de API, correos personales o tokens) antes de pegarla en un Issue o Pull Request en GitHub.

---

## Flujo A: Actualización desde un Nuevo Release

**Cuándo activarlo**: la usuaria indica *"Hay un nuevo release"*, *"Actualiza la aplicación"* o pide descargar la última versión estable.

### Pasos de ejecución
1. **Inspeccionar el árbol de trabajo local**:
   ```bash
   git status
   ```
   Si existen modificaciones locales sin confirmar, resguárdalas de forma segura antes de actualizar:
   ```bash
   git stash push -m "pre-release-update"
   ```
2. **Consultar las notas del último release**:
   ```bash
   gh release view --json tagName,body
   ```
   Lee con atención el campo `body` para identificar migraciones, nuevas variables en `.env` o instalación de dependencias requeridas por esta versión.
3. **Sincronizar etiquetas y código de `main`**:
   ```bash
   git fetch --all --tags
   git checkout main && git pull origin main
   ```
4. **Ejecutar tareas post-actualización**: aplica las instrucciones técnicas descritas en el `body` del release (por ejemplo, instalar dependencias actualizadas o ejecutar migraciones locales), preservando intactos los archivos `.env` y datos personales locales. Si usaste `git stash` en el paso 1 y la usuaria necesita conservar ajustes locales compatibles, evalúa su reaplicación con `git stash pop`.
5. **Confirmar en lenguaje cotidiano**: explica a la usuaria qué versión (`tagName`) quedó instalada y qué mejoras o pasos adicionales relevantes están listos para usar.

### Criterio de Completitud (Flujo A)
- [ ] `git status` verificado y cambios previos resguardados en stash si existían.
- [ ] `gh release view --json tagName,body` consultado y tareas post-actualización ejecutadas.
- [ ] Rama `main` sincronizada con `origin/main` y etiquetas descargadas.
- [ ] Confirmación entregada a la usuaria en lenguaje claro con la versión activa.

---

## Flujo B: Reporte Automático de Errores

**Cuándo activarlo**: la usuaria reporta *"Algo falló"*, *"Salió un error"* o pide *"Reporta este error"*.

### Pasos de ejecución
1. **Recopilar síntoma y evidencia técnica local**:
   - Solicita o confirma con la usuaria qué intentaba hacer y qué observó en sus propias palabras.
   - Obtén la versión exacta instalada mediante `git describe --tags --always` (o `git rev-parse --short HEAD` si aún no hay tags).
   - Reúne los logs relevantes del fallo y sanitízalos eliminando tokens, contraseñas, rutas absolutas privadas o datos personales.
2. **Crear el Issue estructurado en GitHub**:
   ```bash
   gh issue create --title "Bug: <Resumen breve técnico>" --body "## Descripción de la usuaria\n<Qué ocurrió en sus palabras>\n\n## Diagnóstico del Agente Local\n<Versión actual (git describe --tags), logs relevantes y contexto técnico>"
   ```
   *(Si el repositorio cuenta con la etiqueta configurada, añade `--label "agent-bug"`).*
3. **Confirmar a la usuaria**: comparte en lenguaje cotidiano el enlace del reporte creado y confirma que sus datos privados permanecieron únicamente en su equipo.

### Criterio de Completitud (Flujo B)
- [ ] Síntoma en palabras de la usuaria y versión local (`git describe --tags`) recopilados.
- [ ] Logs y contexto técnico sanitizados (cero credenciales, tokens o datos personales).
- [ ] Issue creado en GitHub con `gh issue create` y URL confirmada a la usuaria.

---

## Flujo C: Propuesta de Mejora o Nueva Automatización

**Cuándo activarlo**: la usuaria expresa *"Quiero intentar/crear una nueva mejora o automatización"* o pide probar un cambio nuevo sobre la aplicación.

### Pasos de ejecución
1. **Aislar el trabajo en una rama de propuesta** (manteniendo `main` estable y limpia):
   ```bash
   git checkout -b proposal/<nombre-corto-mejora>
   ```
2. **Desarrollar y validar localmente con la usuaria**: implementa el cambio, pruébalo junto con la usuaria hasta que cumpla con el objetivo buscado y verifica las pruebas disponibles.
3. **Auditar seguridad y preparar archivos**:
   - Ejecuta `git status --ignored` y `git diff --cached --name-only` tras preparar únicamente los archivos de código o configuración segura (`git add <archivos-seguros>`).
   - Confirma cero archivos `.env*`, tokens OAuth, bases de datos locales o datos personales en el commit.
   - Registra el commit con un mensaje claro (`git commit -m "feat: <descripción breve>"`).
4. **Publicar la rama y abrir el Pull Request**:
   ```bash
   git push -u origin proposal/<nombre-corto-mejora>
   gh pr create --base main --title "Propuesta: <Nombre de la mejora>" --body "## Objetivo de la usuaria\n<Qué problema resuelve>\n\n## Cambios técnicos y Auditoría de Seguridad del Agente\n<Resumen de archivos modificados y confirmación de cero datos sensibles>"
   ```
   *(Si el repositorio cuenta con la etiqueta configurada, añade `--label "proposal"`).*
5. **Gestionar el estado de la rama local según preferencia de la usuaria**: pregunta a la usuaria si prefiere permanecer en `proposal/<nombre-corto-mejora>` para seguir usando su mejora mientras se revisa, o regresar a la versión estable con `git checkout main`.

### Criterio de Completitud (Flujo C)
- [ ] Cambios aislados en `proposal/<nombre-corto-mejora>` y validados localmente con la usuaria.
- [ ] Auditoría previa al commit ejecutada (`git status --ignored` y `git diff --cached --name-only`) con cero archivos sensibles.
- [ ] Rama publicada y Pull Request creado contra `main` mediante `gh pr create`.
- [ ] Estado de rama local (`proposal/*` o retorno a `main`) definido según preferencia de la usuaria y URL del PR compartida.
