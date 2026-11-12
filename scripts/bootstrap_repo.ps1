<#
.SYNOPSIS
    Deterministic Repository-First bootstrap script for Windows PowerShell.

.DESCRIPTION
    Implements the Opción 3 automated bootstrap workflow:
    1. Pre-flight passive checks for git and (unless -LocalOnly / -DryRun) gh auth.
    2. Local Git initialization on 'main' with CI-safe git identity fallbacks and asset injection.
    3. Foundational commit and optional remote GitHub creation, governance labels, and collaborator setup.
    4. Switch to initial development branch 'feat/initial-mvp'.
    5. Emit a single-line deterministic JSON result on stdout.
#>
[CmdletBinding()]
param(
    [string]$ProjectDir = ".",
    [string]$RepoName = "",
    [string]$Collaborator = "",
    [ValidateSet("private", "public", "internal")]
    [string]$Visibility = "private",
    [switch]$LocalOnly,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

function Write-Log {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
}

function Fail-Halt {
    param(
        [string]$Message,
        [int]$ExitCode = 2
    )
    [Console]::Error.WriteLine("[HALT] $Message")
    exit $ExitCode
}

function Invoke-Git {
    param(
        [string[]]$GitArgs,
        [switch]$IgnoreExitCode
    )
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & git @GitArgs 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevPref
    }
    if (-not $IgnoreExitCode -and $code -ne 0) {
        $detail = ($output | Out-String).Trim()
        Fail-Halt "git $($GitArgs -join ' ') failed (exit $code): $detail" 2
    }
    return [pscustomobject]@{
        ExitCode = $code
        Output   = ($output | Out-String).Trim()
    }
}

function Invoke-Gh {
    param(
        [string[]]$GhArgs,
        [switch]$IgnoreExitCode
    )
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & gh @GhArgs 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevPref
    }
    if (-not $IgnoreExitCode -and $code -ne 0) {
        $detail = ($output | Out-String).Trim()
        Fail-Halt "gh $($GhArgs -join ' ') failed (exit $code): $detail" 2
    }
    return [pscustomobject]@{
        ExitCode = $code
        Output   = ($output | Out-String).Trim()
    }
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Get-FallbackAssetContent {
    param([string]$AssetName)
    switch ($AssetName) {
        "gitignore.template" {
            return @"
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
"@
        }
        "CLIENT_AGENT.md" {
            return @"
# CLIENT_AGENT Protocol

## Security Guardrails
- Never stage, commit, or push `.env`, OAuth tokens, credentials, or local database files.
- Always work on isolated feature or fix branches; keep `main` clean for releases.

## Flows
- Flow A: Feature Request -> Create a GitHub issue with label `proposal`.
- Flow B: Bug Report -> Create a GitHub issue with label `agent-bug` including version, error logs, and expected behavior.
- Flow C: Pull Request -> Open a PR targeting `main` with modified file summary and security verification.
"@
        }
        "ISSUE_TEMPLATE.md" {
            return @"
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
"@
        }
        "PR_TEMPLATE.md" {
            return @"
## Summary of Changes
Describe the modified files and logic.

## Security & Scope Checklist
- [ ] No `.env`, OAuth credentials, or local database files included
- [ ] Changes scoped to the target issue or feature branch
"@
        }
        default {
            return ""
        }
    }
}

# Resolve skill assets directory relative to script location
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$AssetsDir = [System.IO.Path]::GetFullPath((Join-Path $ScriptRoot "..\assets"))

# Step 1: Pre-flight Check (Diagnóstico Pasivo)
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Fail-Halt "git is not installed or not in PATH. Install Git and re-run." 2
}
$gitVer = Invoke-Git -GitArgs @("--version") -IgnoreExitCode
if ($gitVer.ExitCode -ne 0) {
    Fail-Halt "git --version failed. Verify your Git installation." 2
}

if ((-not $LocalOnly) -and (-not $DryRun)) {
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghCmd) {
        Fail-Halt "GitHub CLI (gh) is not installed. Install gh and authenticate with 'gh auth login' (or pass -LocalOnly)." 2
    }
    $ghAuth = Invoke-Gh -GhArgs @("auth", "status") -IgnoreExitCode
    if ($ghAuth.ExitCode -ne 0) {
        Fail-Halt "GitHub CLI is not authenticated. Run 'gh auth login' to authenticate (or pass -LocalOnly)." 2
    }
}

# Step 2: Local Git Initialization & Asset Injection
if ($DryRun) {
    if ([System.IO.Path]::IsPathRooted($ProjectDir)) {
        $ResolvedProjectDir = [System.IO.Path]::GetFullPath($ProjectDir)
    } else {
        $ResolvedProjectDir = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $ProjectDir))
    }
} else {
    if (-not (Test-Path -LiteralPath $ProjectDir)) {
        New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
    }
    $ResolvedProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path
}

$assetMappings = @(
    @{ Source = "gitignore.template"; Target = ".gitignore" },
    @{ Source = "CLIENT_AGENT.md";    Target = "CLIENT_AGENT.md" },
    @{ Source = "ISSUE_TEMPLATE.md";  Target = ".github/ISSUE_TEMPLATE/bug_report.md" },
    @{ Source = "PR_TEMPLATE.md";     Target = ".github/pull_request_template.md" }
)

if ($DryRun) {
    Write-Log "[DRY-RUN] Project directory: $ResolvedProjectDir"
    Write-Log "[DRY-RUN] Assets source: $AssetsDir"
    Write-Log "[DRY-RUN] Would initialize git on 'main' (if .git absent) and inject 4 files."
    Write-Log "[DRY-RUN] Would create foundational commit and switch to 'feat/initial-mvp'."
    if (-not $LocalOnly) {
        $targetRepo = if ([string]::IsNullOrWhiteSpace($RepoName)) { Split-Path -Leaf $ResolvedProjectDir } else { $RepoName }
        Write-Log "[DRY-RUN] Would create remote repo '$targetRepo' ($Visibility), governance labels, and collaborator '$Collaborator'."
    }
} else {
    $gitDirPath = Join-Path $ResolvedProjectDir ".git"
    if (-not (Test-Path -LiteralPath $gitDirPath)) {
        $initRes = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "init", "-b", "main") -IgnoreExitCode
        if ($initRes.ExitCode -ne 0) {
            $null = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "init")
            $null = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "checkout", "-b", "main")
        }
    } else {
        # Ensure unborn pre-existing repo lands on 'main'
        $headCheck = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "rev-parse", "--verify", "HEAD") -IgnoreExitCode
        if ($headCheck.ExitCode -ne 0) {
            $curBranch = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "symbolic-ref", "--short", "HEAD") -IgnoreExitCode
            if ($curBranch.Output -ne "main") {
                $null = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "checkout", "-b", "main")
            }
        }
    }

    # Ensure git identity defaults locally if unset globally
    $userNameRes = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "config", "user.name") -IgnoreExitCode
    if ($userNameRes.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($userNameRes.Output)) {
        $null = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "config", "--local", "user.name", "Repository-First Bot")
    }
    $userEmailRes = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "config", "user.email") -IgnoreExitCode
    if ($userEmailRes.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($userEmailRes.Output)) {
        $null = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "config", "--local", "user.email", "bot@repository-first.local")
    }

    # Inject assets (copy from assets/ or generate minimal safe fallback if missing)
    foreach ($mapping in $assetMappings) {
        $srcPath = Join-Path $AssetsDir $mapping.Source
        $relTarget = $mapping.Target.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
        $dstPath = Join-Path $ResolvedProjectDir $relTarget
        $dstParent = Split-Path -Parent $dstPath
        if (-not (Test-Path -LiteralPath $dstParent)) {
            New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
        }
        if (Test-Path -LiteralPath $srcPath -PathType Leaf) {
            Copy-Item -LiteralPath $srcPath -Destination $dstPath -Force
        } else {
            Write-Log "[WARN] Asset '$srcPath' not found; generating minimal fallback for '$($mapping.Target)'."
            Write-Utf8NoBom -Path $dstPath -Content (Get-FallbackAssetContent -AssetName $mapping.Source)
        }
    }

    # Step 3: Foundational Commit & Remote Governance
    $null = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "add", ".gitignore", "CLIENT_AGENT.md", ".github")
    $diffCheck = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "diff", "--cached", "--quiet") -IgnoreExitCode
    if ($diffCheck.ExitCode -ne 0) {
        $null = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "commit", "-m", "chore: initial repository-first structure and agent protocols")
    }

    if (-not $LocalOnly) {
        $targetRepoName = if ([string]::IsNullOrWhiteSpace($RepoName)) { Split-Path -Leaf $ResolvedProjectDir } else { $RepoName }
        Push-Location -LiteralPath $ResolvedProjectDir
        try {
            $originCheck = Invoke-Git -GitArgs @("remote", "get-url", "origin") -IgnoreExitCode
            if ($originCheck.ExitCode -ne 0) {
                $null = Invoke-Gh -GhArgs @("repo", "create", $targetRepoName, "--$Visibility", "--source=$ResolvedProjectDir", "--remote=origin", "--push")
            } else {
                $null = Invoke-Git -GitArgs @("push", "-u", "origin", "main")
            }

            $null = Invoke-Gh -GhArgs @("label", "create", "proposal", "--color", "0E8A16", "--force")
            $null = Invoke-Gh -GhArgs @("label", "create", "agent-bug", "--color", "D93F0B", "--force")

            if (-not [string]::IsNullOrWhiteSpace($Collaborator)) {
                $null = Invoke-Gh -GhArgs @("repo", "edit", "--add-collaborator", $Collaborator)
            }
        } finally {
            Pop-Location
        }
    }

    # Step 4: Switch to Initial Development Branch
    $branchCheck = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "show-ref", "--verify", "--quiet", "refs/heads/feat/initial-mvp") -IgnoreExitCode
    if ($branchCheck.ExitCode -eq 0) {
        $null = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "checkout", "feat/initial-mvp")
    } else {
        $null = Invoke-Git -GitArgs @("-C", $ResolvedProjectDir, "checkout", "-b", "feat/initial-mvp")
    }
}

# Step 5: Deterministic JSON Output
$mode = if ($DryRun) {
    "dry_run"
} elseif ($LocalOnly) {
    "local_only"
} else {
    "remote"
}

$result = [ordered]@{
    status         = "ok"
    mode           = $mode
    project_dir    = $ResolvedProjectDir
    active_branch  = "feat/initial-mvp"
    injected_files = @(
        ".gitignore",
        "CLIENT_AGENT.md",
        ".github/ISSUE_TEMPLATE/bug_report.md",
        ".github/pull_request_template.md"
    )
}

Write-Output ($result | ConvertTo-Json -Compress)
