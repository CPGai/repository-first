#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="."
REPO_NAME=""
COLLABORATOR=""
VISIBILITY="private"
LOCAL_ONLY=false
DRY_RUN=false

log_err() {
    printf '%s\n' "$*" >&2
}

fail_halt() {
    printf '[HALT] %s\n' "$1" >&2
    exit "${2:-2}"
}

usage() {
    cat >&2 <<'EOF'
Usage: bootstrap_repo.sh [OPTIONS]
  --project-dir <dir>              Target project directory (default: .)
  --repo-name <name>               GitHub repository name (default: directory basename)
  --collaborator <user>            GitHub collaborator username to add
  --visibility <private|public>    Repository visibility (default: private)
  --local-only                     Initialize locally without GitHub remote operations
  --dry-run                        Print planned actions and JSON output without mutating disk
  -h, --help                       Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-dir)
            [[ $# -ge 2 ]] || fail_halt "--project-dir requires a value" 2
            PROJECT_DIR="$2"
            shift 2
            ;;
        --repo-name)
            [[ $# -ge 2 ]] || fail_halt "--repo-name requires a value" 2
            REPO_NAME="$2"
            shift 2
            ;;
        --collaborator)
            [[ $# -ge 2 ]] || fail_halt "--collaborator requires a value" 2
            COLLABORATOR="$2"
            shift 2
            ;;
        --visibility)
            [[ $# -ge 2 ]] || fail_halt "--visibility requires a value" 2
            VISIBILITY="$2"
            shift 2
            ;;
        --local-only)
            LOCAL_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail_halt "Unknown argument: $1" 2
            ;;
    esac
done

case "$VISIBILITY" in
    private|public|internal) ;;
    *) fail_halt "Invalid --visibility '$VISIBILITY'. Expected private, public, or internal." 2 ;;
esac

# Resolve skill assets directory relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/../assets" ]]; then
    ASSETS_DIR="$(cd "$SCRIPT_DIR/../assets" && pwd)"
else
    ASSETS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/assets"
fi

# Step 1: Pre-flight Check (Diagnóstico Pasivo)
if ! command -v git >/dev/null 2>&1 || ! git --version >/dev/null 2>&1; then
    fail_halt "git is not installed or not in PATH. Install Git and re-run." 2
fi

if [[ "$LOCAL_ONLY" == "false" && "$DRY_RUN" == "false" ]]; then
    if ! command -v gh >/dev/null 2>&1; then
        fail_halt "GitHub CLI (gh) is not installed. Install gh and authenticate with 'gh auth login' (or pass --local-only)." 2
    fi
    if ! gh auth status >/dev/null 2>&1; then
        fail_halt "GitHub CLI is not authenticated. Run 'gh auth login' to authenticate (or pass --local-only)." 2
    fi
fi

write_fallback_asset() {
    local asset_name="$1"
    local target_path="$2"
    case "$asset_name" in
        gitignore.template)
            cat > "$target_path" <<'EOF'
.env
.env.*
*.local
*.pem
*.key
credentials.json
token.json
client_secret*.json
node_modules/
__pycache__/
*.py[cod]
.venv/
venv/
dist/
build/
.DS_Store
Thumbs.db
EOF
            ;;
        CLIENT_AGENT.md)
            cat > "$target_path" <<'EOF'
# CLIENT_AGENT Protocol

## Security Guardrails
- Never stage, commit, or push `.env`, OAuth tokens, credentials, or local database files.
- Always work on isolated feature or fix branches; keep `main` clean for releases.

## Flows
- Flow A: Feature Request -> Create a GitHub issue with label `proposal`.
- Flow B: Bug Report -> Create a GitHub issue with label `agent-bug` including version, error logs, and expected behavior.
- Flow C: Pull Request -> Open a PR targeting `main` with modified file summary and security verification.
EOF
            ;;
        ISSUE_TEMPLATE.md)
            cat > "$target_path" <<'EOF'
---
name: Bug Report
about: Report a reproducible bug or unexpected agent behavior
labels: agent-bug
---

## Summary
Describe what happened and what you expected.

## Environment & Logs
- Release / Tag:
- Error logs / traceback:
EOF
            ;;
        PR_TEMPLATE.md)
            cat > "$target_path" <<'EOF'
## Summary of Changes
Describe the modified files and logic.

## Security & Scope Checklist
- [ ] No `.env`, OAuth credentials, or local database files included
- [ ] Changes scoped to the target issue or feature branch
EOF
            ;;
    esac
}

inject_asset() {
    local asset_name="$1"
    local rel_target="$2"
    local src_path="$ASSETS_DIR/$asset_name"
    local dst_path="$RESOLVED_PROJECT_DIR/$rel_target"
    mkdir -p "$(dirname "$dst_path")"
    if [[ -f "$src_path" ]]; then
        cp -f "$src_path" "$dst_path"
    else
        log_err "[WARN] Asset '$src_path' not found; generating minimal fallback for '$rel_target'."
        write_fallback_asset "$asset_name" "$dst_path"
    fi
}

# Step 2: Local Git Initialization & Asset Injection
if [[ "$DRY_RUN" == "true" ]]; then
    if [[ -d "$PROJECT_DIR" ]]; then
        RESOLVED_PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
    else
        case "$PROJECT_DIR" in
            /*) RESOLVED_PROJECT_DIR="$PROJECT_DIR" ;;
            .) RESOLVED_PROJECT_DIR="$PWD" ;;
            *) RESOLVED_PROJECT_DIR="$PWD/${PROJECT_DIR#./}" ;;
        esac
    fi
    log_err "[DRY-RUN] Project directory: $RESOLVED_PROJECT_DIR"
    log_err "[DRY-RUN] Assets source: $ASSETS_DIR"
    log_err "[DRY-RUN] Would initialize git on 'main' (if .git absent) and inject 4 files."
    log_err "[DRY-RUN] Would create foundational commit and switch to 'feat/initial-mvp'."
    if [[ "$LOCAL_ONLY" == "false" ]]; then
        TARGET_REPO_NAME="${REPO_NAME:-$(basename "$RESOLVED_PROJECT_DIR")}"
        log_err "[DRY-RUN] Would create remote repo '$TARGET_REPO_NAME' ($VISIBILITY), governance labels, and collaborator '$COLLABORATOR'."
    fi
else
    mkdir -p "$PROJECT_DIR"
    RESOLVED_PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

    if [[ ! -d "$RESOLVED_PROJECT_DIR/.git" ]]; then
        if ! git -C "$RESOLVED_PROJECT_DIR" init -b main >/dev/null 2>&1; then
            git -C "$RESOLVED_PROJECT_DIR" init >/dev/null 2>&1
            git -C "$RESOLVED_PROJECT_DIR" checkout -b main >/dev/null 2>&1
        fi
    else
        if ! git -C "$RESOLVED_PROJECT_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
            CURRENT_BRANCH="$(git -C "$RESOLVED_PROJECT_DIR" symbolic-ref --short HEAD 2>/dev/null || true)"
            if [[ "$CURRENT_BRANCH" != "main" ]]; then
                git -C "$RESOLVED_PROJECT_DIR" checkout -b main >/dev/null 2>&1
            fi
        fi
    fi

    if [[ -z "$(git -C "$RESOLVED_PROJECT_DIR" config user.name 2>/dev/null || true)" ]]; then
        git -C "$RESOLVED_PROJECT_DIR" config --local user.name "Repository-First Bot"
    fi
    if [[ -z "$(git -C "$RESOLVED_PROJECT_DIR" config user.email 2>/dev/null || true)" ]]; then
        git -C "$RESOLVED_PROJECT_DIR" config --local user.email "bot@repository-first.local"
    fi

    inject_asset "gitignore.template" ".gitignore"
    inject_asset "CLIENT_AGENT.md" "CLIENT_AGENT.md"
    inject_asset "ISSUE_TEMPLATE.md" ".github/ISSUE_TEMPLATE/bug_report.md"
    inject_asset "PR_TEMPLATE.md" ".github/pull_request_template.md"

    # Step 3: Foundational Commit & Remote Governance
    git -C "$RESOLVED_PROJECT_DIR" add .gitignore CLIENT_AGENT.md .github
    if ! git -C "$RESOLVED_PROJECT_DIR" diff --cached --quiet; then
        git -C "$RESOLVED_PROJECT_DIR" commit -m "chore: initial repository-first structure and agent protocols" >/dev/null
    fi

    if [[ "$LOCAL_ONLY" == "false" ]]; then
        TARGET_REPO_NAME="${REPO_NAME:-$(basename "$RESOLVED_PROJECT_DIR")}"
        (
            cd "$RESOLVED_PROJECT_DIR"
            if ! git remote get-url origin >/dev/null 2>&1; then
                gh repo create "$TARGET_REPO_NAME" "--$VISIBILITY" "--source=$RESOLVED_PROJECT_DIR" --remote=origin --push >&2
            else
                git push -u origin main >&2
            fi
            gh label create "proposal" --color "0E8A16" --force >&2
            gh label create "agent-bug" --color "D93F0B" --force >&2
            if [[ -n "$COLLABORATOR" ]]; then
                gh repo edit --add-collaborator "$COLLABORATOR" >&2
            fi
        )
    fi

    # Step 4: Switch to Initial Development Branch
    if git -C "$RESOLVED_PROJECT_DIR" show-ref --verify --quiet refs/heads/feat/initial-mvp; then
        git -C "$RESOLVED_PROJECT_DIR" checkout feat/initial-mvp >/dev/null 2>&1
    else
        git -C "$RESOLVED_PROJECT_DIR" checkout -b feat/initial-mvp >/dev/null 2>&1
    fi
fi

# Step 5: Deterministic JSON Output
if [[ "$DRY_RUN" == "true" ]]; then
    MODE="dry_run"
elif [[ "$LOCAL_ONLY" == "true" ]]; then
    MODE="local_only"
else
    MODE="remote"
fi

ESCAPED_DIR="${RESOLVED_PROJECT_DIR//\\/\\\\}"
ESCAPED_DIR="${ESCAPED_DIR//\"/\\\"}"

printf '{"status": "ok", "mode": "%s", "project_dir": "%s", "active_branch": "feat/initial-mvp", "injected_files": [".gitignore", "CLIENT_AGENT.md", ".github/ISSUE_TEMPLATE/bug_report.md", ".github/pull_request_template.md"]}\n' \
    "$MODE" "$ESCAPED_DIR"
