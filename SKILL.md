---
name: repository-first
description: repository-first bootstrap, release, and audit workflow for Git/GitHub projects. Use when: (1) initializing a post-planning repo with client-agent governance, (2) merging modular features into immutable semantic releases (vX.Y.Z), or (3) auditing collaborator Issues and PRs for security and scope. Also invoke from SDLC planning skills before writing application code.
---

Protocolo **Repository-First** para inicializar repositorios auditables, empaquetar releases semánticos y revisar contribuciones de colaboradores sin exponer secretos locales.

## Pre-flight Check (Diagnóstico Pasivo)

Antes de ejecutar cualquier rama (excepto pruebas locales con `-LocalOnly` / `--local-only`), verifica herramientas y sesión:

```powershell
git --version; git status -s; gh auth status
```

- **Compuerta Fail-Closed:** Si `gh auth status` falla o `gh` no está instalado, detén la ejecución (`[HALT]`) e indica el comando exacto de remediación: `gh auth login` (o ejecuta Rama 1 en modo `-LocalOnly` / `--local-only` si es una validación sin red).
- **Criterio de Completitud:** `git` disponible, estado de árbol de trabajo conocido y sesión `gh` autenticada (o modo local explícitamente autorizado).

---

## Rama 1: Inicialización Automatizada (Post-Planeación)

Ejecuta el script determinista correspondiente al sistema operativo; este inyecta las plantillas desde su fuente autoritativa (**Single Source of Truth**):

- **Windows (PowerShell):** [`scripts/bootstrap_repo.ps1`](scripts/bootstrap_repo.ps1)
- **POSIX / Linux / macOS (Bash):** [`scripts/bootstrap_repo.sh`](scripts/bootstrap_repo.sh)
- **Assets divulgados (no duplicar inline):** [`assets/CLIENT_AGENT.md`](assets/CLIENT_AGENT.md) (protocolo del agente colaborador), [`assets/gitignore.template`](assets/gitignore.template), [`assets/ISSUE_TEMPLATE.md`](assets/ISSUE_TEMPLATE.md), [`assets/PR_TEMPLATE.md`](assets/PR_TEMPLATE.md).

```powershell
# Windows (resuelve <SKILL_DIR> desde ~/.gemini/config/skills/repository-first o ~/.codex/skills/repository-first):
$SkillDir = if (Test-Path "$env:USERPROFILE\.codex\skills\repository-first\scripts\bootstrap_repo.ps1") { "$env:USERPROFILE\.codex\skills\repository-first" } else { "$env:USERPROFILE\.gemini\config\skills\repository-first" }
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\bootstrap_repo.ps1" -ProjectDir "<ruta>" -RepoName "<repo>" -Visibility private -Collaborator "<usuario>"
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillDir\scripts\bootstrap_repo.ps1" -ProjectDir "<ruta>" -LocalOnly
```

```bash
# POSIX (remoto GitHub completo y fallback local desde <SKILL_DIR>):
SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills/repository-first"; [ -d "$SKILL_DIR" ] || SKILL_DIR="$HOME/.gemini/config/skills/repository-first"
bash "$SKILL_DIR/scripts/bootstrap_repo.sh" --project-dir "<ruta>" --repo-name "<repo>" --visibility private --collaborator "<usuario>"
bash "$SKILL_DIR/scripts/bootstrap_repo.sh" --project-dir "<ruta>" --local-only
```

- **Criterio de Completitud:** Repositorio `git` inicializado en `main`, archivos `.gitignore`, `CLIENT_AGENT.md`, `.github/ISSUE_TEMPLATE/bug_report.md` y `.github/pull_request_template.md` inyectados, commit fundacional `chore: initial repository-first structure and agent protocols` creado, remoto publicado (o JSON `"status": "ok"` en modo `-LocalOnly`/`--local-only` verificado) y rama activa cambiada a `feat/initial-mvp`.

---

## Rama 2: Entrega Modular y Releases Inmutables

Aísla cada desarrollo nuevo en ramas `feat/<slug>` o `fix/<slug>`, manteniendo `main` exclusivamente como rama limpia de integración y despliegue:

1. Desarrolla y prueba cambios en `feat/<slug>` o `fix/<slug>`; verifica que `git diff --cached --name-only` incluya únicamente código fuente y documentación segura.
2. Integra preservando el historial modular, etiqueta la versión semántica y publica el release con notas accionables para el agente cliente (`CLIENT_AGENT.md` Flujo A):

```bash
git checkout main && git pull origin main
git merge --no-ff feat/<slug> -m "merge: feat/<slug> into main"
git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push origin main --tags
gh release create vX.Y.Z --title "vX.Y.Z - <Resumen>" --notes "## Cambios\n- ...\n\n## Pasos Post-Actualización (Agente Local)\n- Ejecutar migraciones o instalar dependencias si aplica."
```

- **Criterio de Completitud:** Rama `feat/<slug>`/`fix/<slug>` integrada en `main` mediante `--no-ff`, tag anotado `vX.Y.Z` publicado en `origin`, release inmutable visible con `gh release view vX.Y.Z` incluyendo pasos post-actualización accionables, y nueva rama `feat/<siguiente>` abierta si continúa el desarrollo.

---

## Rama 3: Auditoría de Retroalimentación (Issues y PRs de Colaboradores)

Inspecciona reportes y propuestas (`proposal/*`) de forma pasiva y aislada antes de integrar cambios al tronco principal:

1. Lista incidencias y PRs abiertas: `gh issue list --state open` y `gh pr list --state open`.
2. Evalúa el PR en rama aislada sin tocar `main`: `gh pr checkout <id>` y revisa alcance con `git diff main...HEAD --name-only`.
3. **Auditoría de Seguridad y Alcance:** Confirma ausencia total de archivos `.env*`, credenciales/tokens OAuth, bases de datos locales (`*.db`, `*.sqlite*`) o carpetas personales, y valida pruebas antes de aprobar (`gh pr merge <id> --merge` o solicitar ajustes en el PR).

- **Criterio de Completitud:** Listado pasivo revisado, PR inspeccionado en checkout aislado, cero secretos/datos locales detectados en el diff, veredicto documentado (merge o comentario técnico accionable en GitHub) y regreso limpio a `main`.

---

## Integración (Hand-off desde Planeación / Addy Osmani SDLC)

Inserta este bloque al final de cualquier skill de planeación o arquitectura antes de implementar el MVP:

```markdown
### Hand-off Obligatorio: Repository-First
1. Invoca el skill `repository-first` (Rama 1) ejecutando `scripts/bootstrap_repo.ps1` (Windows) o `scripts/bootstrap_repo.sh` (POSIX).
2. Confirma que `CLIENT_AGENT.md`, `.gitignore` y `.github/` existen en `main` y que la rama activa es `feat/initial-mvp`.
- **Criterio de Completitud:** JSON `"status": "ok"` emitido y `git branch --show-current` igual a `feat/initial-mvp` antes de escribir el primer archivo del MVP.
```
