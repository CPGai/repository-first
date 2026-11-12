"""Verification suite for the Repository-First (Opción 3) skill package."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILL_MD = REPO_ROOT / "SKILL.md"
EVALUATION_MD = REPO_ROOT / "EVALUATION_OPCION3.md"
ASSETS_DIR = REPO_ROOT / "assets"
SCRIPTS_DIR = REPO_ROOT / "scripts"

FORBIDDEN_MARKERS = ("TO" + "DO", "FIX" + "ME")


def _read_utf8(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _assert_no_forbidden_markers(text: str, path: Path) -> None:
    for marker in FORBIDDEN_MARKERS:
        assert marker not in text, f"Unexpected placeholder {marker!r} in {path}"


# ---------------------------------------------------------------------------
# Test Group 1: SKILL.md & writing-great-skills compliance
# ---------------------------------------------------------------------------


def test_skill_md_frontmatter_and_metadata() -> None:
    assert SKILL_MD.is_file(), f"Missing {SKILL_MD}"
    text = _read_utf8(SKILL_MD)
    lines = text.splitlines()
    assert lines and lines[0].strip() == "---", "SKILL.md must start with YAML frontmatter '---'"

    closing_idx = None
    for idx, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            closing_idx = idx
            break
    assert closing_idx is not None, "SKILL.md frontmatter is not closed with '---'"

    frontmatter = "\n".join(lines[1:closing_idx])
    assert re.search(r"^name:\s*repository-first\s*$", frontmatter, re.MULTILINE), (
        "Frontmatter must contain 'name: repository-first'"
    )
    desc_match = re.search(r"^description:\s*(.+)$", frontmatter, re.MULTILINE)
    assert desc_match and desc_match.group(1).strip(), "Frontmatter must contain non-empty 'description:'"


def test_skill_md_no_sprawl_line_limit() -> None:
    text = _read_utf8(SKILL_MD)
    _assert_no_forbidden_markers(text, SKILL_MD)
    line_count = len(text.splitlines())
    assert 20 <= line_count <= 130, f"SKILL.md line count ({line_count}) exceeds 130-line anti-sprawl limit"


def test_skill_md_context_pointers() -> None:
    text = _read_utf8(SKILL_MD)
    expected_pointers = (
        "assets/CLIENT_AGENT.md",
        "assets/gitignore.template",
        "scripts/bootstrap_repo.ps1",
        "scripts/bootstrap_repo.sh",
    )
    for pointer in expected_pointers:
        assert pointer in text, f"SKILL.md missing Context Pointer {pointer!r}"


def test_skill_md_single_source_of_truth() -> None:
    skill_text = _read_utf8(SKILL_MD)
    forbidden_inline_snippets = (
        "### A. Cuando la usuaria diga",
        "### B. Cuando la usuaria diga",
        "### C. Cuando la usuaria diga",
        "Regla de Oro de Seguridad",
    )
    for snippet in forbidden_inline_snippets:
        assert snippet not in skill_text, (
            f"SKILL.md duplicates CLIENT_AGENT.md content ({snippet!r}), violating Single Source of Truth"
        )


def test_skill_md_completion_criteria() -> None:
    text = _read_utf8(SKILL_MD)
    matches = re.findall(r"Criterio de Completitud|Completion Criteri(?:on|a)", text, flags=re.IGNORECASE)
    assert len(matches) >= 3, (
        f"SKILL.md should define Completion Criteria across its operational phases (found {len(matches)})"
    )


# ---------------------------------------------------------------------------
# Test Group 2: EVALUATION_OPCION3.md quality
# ---------------------------------------------------------------------------


def test_evaluation_exists_and_substantive() -> None:
    assert EVALUATION_MD.is_file(), f"Missing {EVALUATION_MD}"
    text = _read_utf8(EVALUATION_MD)
    _assert_no_forbidden_markers(text, EVALUATION_MD)
    line_count = len(text.splitlines())
    assert line_count >= 60, f"EVALUATION_OPCION3.md must be >= 60 lines (got {line_count})"

    for option_num in ("1", "2", "3"):
        assert re.search(rf"Opci[oó]n\s+{option_num}", text, flags=re.IGNORECASE), (
            f"EVALUATION_OPCION3.md must analyze Opción {option_num}"
        )


def test_evaluation_writing_great_skills_concepts() -> None:
    text = _read_utf8(EVALUATION_MD)
    concept_groups = (
        ("Predictability", "Predecibilidad"),
        ("Progressive Disclosure", "Divulgación Progresiva", "Divulgacion Progresiva"),
        ("Single Source of Truth",),
        ("Completion Criterion", "Completion Criteria", "Criterio de Completitud", "Criterios de Completitud"),
        ("Negation", "Negación", "Negacion"),
        ("No-Op",),
    )
    for group in concept_groups:
        assert any(re.search(re.escape(term), text, flags=re.IGNORECASE) for term in group), (
            f"EVALUATION_OPCION3.md must reference one of {group}"
        )


# ---------------------------------------------------------------------------
# Test Group 3: assets/ completeness & grammar fix
# ---------------------------------------------------------------------------


def test_all_assets_exist_and_nonempty() -> None:
    expected_assets = (
        "CLIENT_AGENT.md",
        "gitignore.template",
        "ISSUE_TEMPLATE.md",
        "PR_TEMPLATE.md",
    )
    for filename in expected_assets:
        asset_path = ASSETS_DIR / filename
        assert asset_path.is_file(), f"Missing asset file {asset_path}"
        content = _read_utf8(asset_path)
        assert content.strip(), f"Asset file {asset_path} is empty"
        _assert_no_forbidden_markers(content, asset_path)


def test_client_agent_flows_and_guardrails() -> None:
    client_agent = ASSETS_DIR / "CLIENT_AGENT.md"
    text = _read_utf8(client_agent)

    for flow in ("Flujo A", "Flujo B", "Flujo C"):
        assert flow in text, f"CLIENT_AGENT.md must contain {flow}"

    assert ".env" in text, "CLIENT_AGENT.md must include .env security guardrail"
    assert re.search(r"oauth", text, flags=re.IGNORECASE), "CLIENT_AGENT.md must include OAuth security guardrail"
    assert re.search(r"Criterio de Completitud|Completion Criteri(?:on|a)", text, flags=re.IGNORECASE), (
        "CLIENT_AGENT.md must define explicit Completion Criteria"
    )


def test_client_agent_spanish_grammar_fixed() -> None:
    broken_strings = (
        "<Lo pasó que>",
        "<Versión actual, contexto de error logs técnico y>",
        "<Resumen archivos auditoría de lógica modificada para seguridad y>",
    )
    for path in (ASSETS_DIR / "CLIENT_AGENT.md", SKILL_MD):
        text = _read_utf8(path)
        for broken in broken_strings:
            assert broken not in text, f"Broken Spanish draft string {broken!r} still present in {path}"


def test_gitignore_template_patterns() -> None:
    gitignore_path = ASSETS_DIR / "gitignore.template"
    text = _read_utf8(gitignore_path)

    for required in (".env", "node_modules/", "__pycache__/"):
        assert required in text, f"gitignore.template must ignore {required!r}"

    oauth_or_cred_patterns = ("credentials", "token", ".pem", "oauth", ".agy_auth")
    assert any(pat in text.lower() for pat in oauth_or_cred_patterns), (
        "gitignore.template must ignore OAuth/credential files"
    )


# ---------------------------------------------------------------------------
# Test Group 4: scripts/ end-to-end execution test
# ---------------------------------------------------------------------------


def test_scripts_exist_and_clean() -> None:
    ps1_path = SCRIPTS_DIR / "bootstrap_repo.ps1"
    sh_path = SCRIPTS_DIR / "bootstrap_repo.sh"

    for script in (ps1_path, sh_path):
        assert script.is_file(), f"Missing script {script}"
        content = _read_utf8(script)
        assert content.strip(), f"Script {script} is empty"
        _assert_no_forbidden_markers(content, script)

    ps1_text = _read_utf8(ps1_path)
    sh_text = _read_utf8(sh_path)
    assert "LocalOnly" in ps1_text and "--local-only" in sh_text
    assert "feat/initial-mvp" in ps1_text and "feat/initial-mvp" in sh_text
    assert "chore: initial repository-first structure and agent protocols" in ps1_text
    assert "chore: initial repository-first structure and agent protocols" in sh_text


def test_bootstrap_ps1_end_to_end_local_only(tmp_path: Path) -> None:
    ps1_path = SCRIPTS_DIR / "bootstrap_repo.ps1"
    target_dir = tmp_path / "sample-project"
    target_dir.mkdir(parents=True, exist_ok=True)

    result = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ps1_path),
            "-ProjectDir",
            str(target_dir),
            "-LocalOnly",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    assert result.returncode == 0, (
        f"bootstrap_repo.ps1 failed with exit {result.returncode}.\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )

    assert (target_dir / ".git").is_dir(), ".git directory was not initialized"
    expected_injected = (
        target_dir / ".gitignore",
        target_dir / "CLIENT_AGENT.md",
        target_dir / ".github" / "ISSUE_TEMPLATE" / "bug_report.md",
        target_dir / ".github" / "pull_request_template.md",
    )
    for injected in expected_injected:
        assert injected.is_file(), f"Expected injected file missing: {injected}"

    branch_res = subprocess.run(
        ["git", "-C", str(target_dir), "branch", "--show-current"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    assert branch_res.stdout.strip() == "feat/initial-mvp", (
        f"Expected current branch 'feat/initial-mvp', got {branch_res.stdout.strip()!r}"
    )

    log_res = subprocess.run(
        ["git", "-C", str(target_dir), "log", "main", "-1", "--pretty=%B"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    assert "chore: initial repository-first structure and agent protocols" in log_res.stdout, (
        f"Unexpected main commit message: {log_res.stdout!r}"
    )


def test_bootstrap_ps1_emits_valid_json_status(tmp_path: Path) -> None:
    ps1_path = SCRIPTS_DIR / "bootstrap_repo.ps1"
    target_dir = tmp_path / "json-check-project"

    result = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ps1_path),
            "-ProjectDir",
            str(target_dir),
            "-LocalOnly",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    )
    json_lines = [line.strip() for line in result.stdout.splitlines() if line.strip().startswith("{")]
    assert json_lines, f"Expected JSON summary line on stdout, got:\n{result.stdout}"
    payload = json.loads(json_lines[-1])
    assert payload.get("status") == "ok"
    assert payload.get("active_branch") == "feat/initial-mvp"
    assert payload.get("mode") in ("local_only", "local-only")


def test_bootstrap_sh_syntax_parity_and_execution(tmp_path: Path) -> None:
    sh_path = SCRIPTS_DIR / "bootstrap_repo.sh"
    raw_bytes = sh_path.read_bytes()
    assert b"\r\n" not in raw_bytes, "bootstrap_repo.sh must use LF line endings (no CRLF)"

    sh_text = raw_bytes.decode("utf-8")
    assert sh_text.startswith("#!/usr/bin/env bash"), "bootstrap_repo.sh must start with bash shebang"
    assert "set -euo pipefail" in sh_text, "bootstrap_repo.sh must enable strict mode (set -euo pipefail)"

    for flag in ("--project-dir", "--repo-name", "--collaborator", "--visibility", "--local-only", "--dry-run"):
        assert flag in sh_text, f"bootstrap_repo.sh missing CLI flag {flag}"
    for target in (".gitignore", "CLIENT_AGENT.md", ".github/ISSUE_TEMPLATE/bug_report.md", ".github/pull_request_template.md"):
        assert target in sh_text, f"bootstrap_repo.sh missing asset target {target}"
    assert "gh auth status" in sh_text and "[HALT]" in sh_text

    bash_exe = shutil.which("bash")
    if bash_exe:
        syntax_res = subprocess.run(
            [bash_exe, "-n", str(sh_path)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=False,
        )
        assert syntax_res.returncode == 0, f"bash -n failed: {syntax_res.stderr}"

        target_dir = tmp_path / "sh-local-project"
        exec_res = subprocess.run(
            [bash_exe, str(sh_path), "--project-dir", str(target_dir), "--local-only"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=False,
        )
        assert exec_res.returncode == 0, f"bootstrap_repo.sh failed: {exec_res.stderr}"
        assert (target_dir / ".git").is_dir()
        assert (target_dir / "CLIENT_AGENT.md").is_file()

