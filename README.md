# Repository-First Governance & Delivery Skill

Skill estándar para **Antigravity (AGY)** y **Codex** que inicializa, gobierna y audita repositorios en GitHub **antes** de escribir el código de una aplicación (paradigma *Repository-First*, **Opción 3: Creativa / Automatizada**).

## ¿Qué resuelve?

1. **Pre-flight Check (Fail-Closed):** Verifica `git` y la sesión autenticada de GitHub CLI (`gh auth status`) antes de cualquier mutación remota.
2. **Bootstrap Determinista (`scripts/bootstrap_repo.ps1` y `scripts/bootstrap_repo.sh`):**
   - Inicializa `main` y configura `.gitignore` seguro (`.env*`, credenciales OAuth, bases de datos locales y carpetas de datos personales).
   - Inyecta [`assets/CLIENT_AGENT.md`](assets/CLIENT_AGENT.md) para que el agente local de colaboradores no técnicos opere GitHub (`gh`) de forma segura mediante flujos guiados (actualizar releases, reportar bugs y abrir PRs `proposal/*`).
   - Inyecta plantillas de Issues y Pull Requests en `.github/`.
   - Crea el repositorio en GitHub, etiquetas (`proposal`, `agent-bug`), agrega colaboradores opcionales y cambia automáticamente a la rama `feat/initial-mvp`.
3. **Releases Inmutables y Auditoría:** Estandariza merges `--no-ff` a `main` con tags semánticos (`vX.Y.Z`) y auditoría aislada de PRs (`gh pr checkout <id>`).

---

## Instalación Rápida

### En Antigravity (AGY)
```powershell
git clone https://github.com/CPGai/repository-first.git "$env:USERPROFILE\.gemini\config\skills\repository-first"
```

### En Codex
```powershell
git clone https://github.com/CPGai/repository-first.git "$env:USERPROFILE\.codex\skills\repository-first"
```

> **Requisito previo:** Tener instalado [GitHub CLI (`gh`)](https://cli.github.com/) y haber ejecutado `gh auth login` una sola vez.

---

## Estructura del Skill

```text
repository-first/
├── SKILL.md                    # Instrucciones principales (model-invoked, <= 90 líneas)
├── EVALUATION_OPCION3.md       # Análisis arquitectónico bajo writing-great-skills
├── agents/
│   └── openai.yaml             # Metadatos UI y política de invocación para Codex
├── assets/
│   ├── CLIENT_AGENT.md         # Protocolo autónomo para el agente del colaborador
│   ├── gitignore.template      # Plantilla base de exclusiones de secretos y entorno
│   ├── ISSUE_TEMPLATE.md       # Plantilla de reporte de bugs
│   └── PR_TEMPLATE.md          # Plantilla de propuestas (proposal/*)
├── scripts/
│   ├── bootstrap_repo.ps1      # Bootstrap determinista para Windows (PowerShell)
│   └── bootstrap_repo.sh       # Bootstrap determinista para Linux / macOS (Bash)
└── tests/
    └── test_repository_first.py # Suite de verificación (15 pruebas con pytest)
```

---

## Verificación Local

```powershell
python -m pytest tests/test_repository_first.py -p no:cacheprovider -v
```
