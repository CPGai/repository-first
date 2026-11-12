# Evaluación Arquitectónica: Opción 3 (Creativa / Automatizada) para `repository-first`

Evaluación de diseño aplicando el marco de **`writing-great-skills`** (`Predictability`, `Information Hierarchy`, `Progressive Disclosure`, `Single Source of Truth`, `Steering` y `Pruning`) al ciclo de vida del skill `repository-first` en entorno Windows (`AGY_Setup`) y POSIX.

---

## 1. Veredicto Ejecutivo

**Recomendación:** Adoptar **Opción 3: Creativa (Automatizada — `SKILL.md` + `assets/` + `scripts/`)** con soporte nativo dual PowerShell (`scripts/bootstrap_repo.ps1`) y Bash (`scripts/bootstrap_repo.sh`).

### Por qué falla la Opción 1 (Solo `SKILL.md`)
1. **Violación de Single Source of Truth y aparición de Duplication:** Incrustar el texto completo de `CLIENT_AGENT.md`, `.gitignore` y plantillas `.github/` dentro de `SKILL.md` mezcla instrucciones de ejecución del orquestador con documentación operativa del agente cliente. Cualquier ajuste en el protocolo del colaborador obliga a editar múltiples bloques dentro de un archivo monolítico.
2. **Sprawl severo y degradación de la atención:** Superar las ~200–300 líneas con plantillas estáticas diluye los **Steps** primarios. Según la **Information Hierarchy**, el material de referencia incrustado cuando debe divulgarse convierte la lectura de los pasos críticos en un lanzamiento de moneda y eleva el **Context Load** en cada invocación.
3. **Pérdida de Predictability:** Obligar al LLM a regenerar token por token un `.gitignore`, un `CLIENT_AGENT.md` y cuatro comandos `git`/`gh` secuenciales introduce deriva sintáctica, omisiones accidentales y variación entre ejecuciones.

### Por qué Opción 3 supera a Opción 2 (`SKILL.md` + `assets/`)
La **Opción 2** resuelve el **Sprawl** mediante **Progressive Disclosure** (`assets/`), pero sigue delegando al LLM la ejecución manual de la cadena `git init -> copia de archivos -> commit fundacional -> gh repo create -> labels -> checkout`. La **Opción 3** maximiza la **Predictability** al combinar:
- **Progressive Disclosure (`assets/`):** Las plantillas viven en una única fuente autoritativa (**Single Source of Truth**) fuera de `SKILL.md`, referenciadas por **Context Pointers** nítidos.
- **Ejecución determinista (`scripts/`):** La inicialización estructural pasa de ser generación probabilística a una llamada de script idempotente con salida JSON verificable y modo `-LocalOnly` / `--local-only` para pruebas sin red.

### Imperativo multiplataforma en `AGY_Setup` (Windows + POSIX)
En estaciones Windows (`AGY_Setup`), depender únicamente de un script `.sh` exige WSL, Git Bash o ajustes de permisos POSIX (`chmod +x`), introduciendo fricción de entorno y fallos silenciosos de ruta (`\` vs `/`). Incluir **`scripts/bootstrap_repo.ps1`** junto a **`scripts/bootstrap_repo.sh`** elimina la fricción de sistema operativo y permisos, garantizando ejecución nativa en PowerShell (`-NoProfile -ExecutionPolicy Bypass`) y en entornos Linux/macOS con idéntica interfaz y contrato de salida.

---

## 2. Auditoría del Borrador Original bajo `/writing-great-skills`

### A. Invocation & Description
- **Model-Invoked vs. User-Invoked:** `repository-first` debe permanecer **Model-Invoked** (sin `disable-model-invocation: true`). Aunque añade **Context Load** permanente por su `description`, es indispensable para que skills previos de planeación (p. ej., flujo Addy Osmani SDLC) lo descubran e invoquen autónomamente al cerrar la arquitectura, ahorrando **Cognitive Load** al usuario.
- **Front-loading de Leading Words:** El borrador dispersaba palabras clave al final. La nueva `description` coloca al frente los **Leading Words** de dominio: `repository-first`, `bootstrap`, `release`, `audit`.
- **Poda de Branch Triggers duplicados:** Se eliminan sinónimos redundantes para una misma acción (como *"inicializar proyecto / crear estructura inicial / configurar git"*) que generaban **Duplication**, consolidando exactamente **3 Branches** distintas más una cláusula de alcance (*reach clause*) para hand-off desde skills de planeación.

### B. Information Hierarchy & Progressive Disclosure
En la escalera de **Information Hierarchy**:
1. **Rung 1 — Steps (en `SKILL.md`):** Pre-flight pasivo y las 3 **Branches** operativas (`<120` líneas en total).
2. **Rung 2 — Reference in-skill (en `SKILL.md`):** Reglas de aislamiento de ramas y formato de etiquetas/releases.
3. **Rung 3 — Reference disclosed (en `assets/` y `scripts/`):** `CLIENT_AGENT.md`, `gitignore.template`, `ISSUE_TEMPLATE.md`, `PR_TEMPLATE.md`, `bootstrap_repo.ps1` y `bootstrap_repo.sh`, enlazados mediante **Context Pointers** cuya redacción indica explícitamente *cuándo* cargar o ejecutar cada recurso.

### C. Completion Criteria vs. Premature Completion
El borrador original carecía de compuertas verificables al cierre de cada fase, favoreciendo la **Premature Completion** (el agente asume que "el repo está listo" sin confirmar commit, remoto o rama activa). La versión Opción 3 añade un **`Criterio de Completitud`** comprobable y exhaustivo en:
1. **Pre-flight Check:** Compuerta *fail-closed* con remediación exacta (`gh auth login`).
2. **Branch 1 (Bootstrap):** Estructura inyectada, commit fundacional en `main`, remoto creado (o modo local verificado) y rama activa cambiada a `feat/initial-mvp`.
3. **Branch 2 (Release):** Merge `--no-ff` en `main`, tag semántico `vX.Y.Z` y `gh release create` con notas accionables.
4. **Branch 3 (Audit):** Revisión aislada con `gh pr checkout`, cero archivos sensibles (`.env`, tokens OAuth, BD locales) y alcance acotado.
5. **Integración SDLC (Hand-off):** Confirmación de entrega antes de escribir código de producto.

### D. Steering: Negation -> Positive Framing, No-Op Pruning y Corrección Sintáctica
- **Eliminación de Negations ("Elefante Rosa"):**
  - *Borrador (Negation):* `"Nunca desarrolles directamente sobre main"` -> *Reescritura positiva:* `"Aísla cada funcionalidad o corrección en feat/<slug> o fix/<slug>, reservando main exclusivamente como rama limpia de integración mediante merge --no-ff."`
  - *Borrador (Negation):* `"NO generes código todavía"` -> *Reescritura positiva:* `"Ejecuta primero el hand-off hacia repository-first y confirma feat/initial-mvp activa antes de escribir la primera línea del MVP."`
  - Cuando se conserva una restricción crítica de seguridad, se formula como guardrail positivo verificable (`git diff --cached --name-only` libre de secretos y archivos ignorados).
- **No-Op Pruning:** Se podan exhortaciones genéricas que el modelo ya sigue por defecto (*"sé cuidadoso"*, *"asegúrate de revisar bien el código"*) por fallar la prueba **No-Op** (no alteran el comportamiento frente al baseline).
- **Corrección de sintaxis corrupta del borrador original (Flujos B y C de `CLIENT_AGENT.md`):**
  - `"<Lo pasó que>"` -> corregido a `"<Qué ocurrió en sus palabras>"`.
  - `"<Versión actual, contexto de error logs técnico y>"` -> corregido a `"<Versión actual (git describe --tags), logs relevantes y contexto técnico>"`.
  - `"<Resumen archivos auditoría de lógica modificada para seguridad y>"` -> corregido a `"<Resumen de archivos modificados y confirmación de cero datos sensibles>"`.

---

## 3. Matriz Comparativa Final

| Dimensión (`writing-great-skills`) | Opción 1: Solo `SKILL.md` | Opción 2: `SKILL.md` + `assets/` | Opción 3: `SKILL.md` + `assets/` + `scripts/` (`.ps1` + `.sh`) |
| :--- | :--- | :--- | :--- |
| **Predictability** | Baja (regeneración probabilística de plantillas y comandos) | Media (plantillas fijas, ejecución `git`/`gh` manual) | **Máxima** (plantillas fijas + script determinista + JSON) |
| **Single Source of Truth** | Violado (plantillas mezcladas con pasos del orquestador) | Cumplido (`assets/` aislados) | **Cumplido** (`assets/` únicos + lógica encapsulada en `scripts/`) |
| **Sprawl y Context Load** | Alto (`>250` líneas en `SKILL.md`) | Bajo (`<120` líneas en `SKILL.md`) | **Mínimo** (`<120` líneas; punteros directos a scripts y assets) |
| **Fricción OS / Windows (`AGY_Setup`)** | Media (comandos inline propensos a diferencias de shell) | Media (copiado manual sujeto a rutas/permisos) | **Cero** (`bootstrap_repo.ps1` nativo + `bootstrap_repo.sh` POSIX) |
| **Completion Criteria y Testabilidad** | Informal, sin pruebas end-to-end | Verificable por inspección de archivos | **Verificable automáticamente** (`-LocalOnly` + `pytest`) |
| **Mantenibilidad (Sediment)** | Costosa; riesgo de regresiones al editar | Buena; editar `assets/` no toca pasos | **Óptima**; evolución independiente de pasos, plantillas y scripts |
