#!/usr/bin/env pwsh
# Ciel — Self-update script (PowerShell / Windows)
# Compares local SKILL.md SHA with GitHub remote.
# If different -> downloads updated files via gh CLI.
# Requires: gh CLI authenticated (gh auth status)
#
# Usage: pwsh scripts/self-update.ps1
# Or via /ciel-update command

$ErrorActionPreference = "Stop"

$REPO              = "KaosKyun/Ciel"
$LOCAL_SKILL       = "$HOME/.claude/skills/ciel/SKILL.md"
$LOCAL_COMMAND_DIR = Join-Path (Get-Location) ".claude/commands"
$LOCAL_HOOKS_DIR   = "$HOME/.claude/plugins/ciel/hooks"
$VERSION_FILE      = "$HOME/.claude/plugins/ciel/.version"

Write-Host "Ciel update check..."

# Check gh CLI available and authenticated
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: gh CLI not found. Install: https://cli.github.com"
    exit 1
}

$authCheck = & gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: gh CLI not authenticated. Run: gh auth login"
    exit 1
}

# Get remote SHA for SKILL.md
$remoteSha = ""
try {
    $remoteSha = & gh api "repos/$REPO/contents/skills/ciel/SKILL.md" --jq '.sha' 2>$null
} catch { }
if (-not $remoteSha) {
    Write-Host "Could not reach GitHub (private repo / network). Skipping update."
    exit 0
}

# Get stored SHA
$storedSha = ""
if (Test-Path $VERSION_FILE -PathType Leaf) {
    $storedSha = (Get-Content $VERSION_FILE -Raw).Trim()
}

if ($remoteSha -eq $storedSha -and $storedSha) {
    Write-Host "Ciel is up to date (SHA: $($remoteSha.Substring(0, 8)))."
    exit 0
}

Write-Host "Update available — downloading..."

# Helper: download a repo file and decode base64 content
function Download-File($apiPath, $destPath) {
    New-Item -ItemType Directory -Force (Split-Path $destPath) | Out-Null
    $b64 = & gh api "repos/$REPO/contents/$apiPath" --jq '.content' 2>$null
    if ($b64) {
        # GitHub returns base64 with newlines — strip them before decoding
        $bytes = [System.Convert]::FromBase64String(($b64 -replace '\s',''))
        [System.IO.File]::WriteAllBytes($destPath, $bytes)
        Write-Host "  Updated: $destPath"
    }
}

# Download SKILL.md
Download-File "skills/ciel/SKILL.md" $LOCAL_SKILL

# Download ciel.md command
Download-File "commands/ciel.md" "$LOCAL_COMMAND_DIR/ciel.md"

# Download ciel-update command (optional)
try { Download-File "commands/ciel-update.md" "$LOCAL_COMMAND_DIR/ciel-update.md" } catch { }

# Download hooks (.sh for Linux/Mac, .ps1 for Windows)
Download-File "hooks/pre-write-gate.sh"   "$LOCAL_HOOKS_DIR/pre-write-gate.sh"
Download-File "hooks/post-write-relire.sh" "$LOCAL_HOOKS_DIR/post-write-relire.sh"
Download-File "hooks/pre-write-gate.ps1"   "$LOCAL_HOOKS_DIR/pre-write-gate.ps1"
Download-File "hooks/post-write-relire.ps1" "$LOCAL_HOOKS_DIR/post-write-relire.ps1"

# Store new SHA
Set-Content $VERSION_FILE $remoteSha

Write-Host ""
Write-Host "Ciel updated successfully (SHA: $($remoteSha.Substring(0, 8)))."
Write-Host "Restart Claude Code to apply changes (/restart or reopen session)."
