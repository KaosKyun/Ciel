# Ciel v5 Universal Installer (PowerShell)
# Usage: irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.ps1 | iex
#        pwsh scripts/install.ps1 [--update] [--uninstall]
#
# Zero-config, auto-detects platform (OpenCode or Claude Code).

$ErrorActionPreference = "Stop"
$CIEL_VERSION = "5.1.1"
$GITHUB_RAW = "https://raw.githubusercontent.com/KaosKyun/Ciel/main"

function ok($m)   { Write-Host "  v $m" -ForegroundColor Green }
function info($m) { Write-Host "  > $m" -ForegroundColor Cyan }
function warn($m) { Write-Host "  ! $m" -ForegroundColor Yellow }
function dl($u, $d) {
  $dir = Split-Path $d -Parent
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Invoke-WebRequest -Uri "$GITHUB_RAW/$u" -OutFile $d -ErrorAction SilentlyContinue
}

$DO_UNINSTALL = $args -contains "--uninstall"
$DO_UPDATE = $args -contains "--update"

if ($DO_UNINSTALL) {
  Write-Host "`nCiel v$CIEL_VERSION -- Uninstall`n"
  Remove-Item -Recurse -Force "$HOME\.ciel" -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force ".claude\agents" -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force ".claude\hooks" -ErrorAction SilentlyContinue
  Remove-Item -Force ".claude\settings.json" -ErrorAction SilentlyContinue
  Remove-Item -Force "CLAUDE.md" -ErrorAction SilentlyContinue
  Remove-Item -Force ".opencode\plugins\ciel.ts" -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force ".opencode\agents" -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force ".opencode\commands" -ErrorAction SilentlyContinue
  ok "Ciel uninstalled"
  exit 0
}

# Detect platform
$IS_PIPE = $MyInvocation.InvocationName -eq "&" -or $MyInvocation.Line -match "iex"
if (Test-Path ".claude\settings.json") { $PLATFORM = "claude" }
elseif (Test-Path "opencode.json") { $PLATFORM = "opencode" }
else { $PLATFORM = "unknown" }

Write-Host "`nCiel v$CIEL_VERSION Installer`n"
Write-Host "  Platform: $PLATFORM`n"

if ($PLATFORM -eq "unknown") {
  warn "Could not detect platform. Run from your project root."
  exit 1
}

if ($IS_PIPE) {
  # Download files to temp
  $tmp = Join-Path $env:TEMP "ciel-install-$([System.IO.Path]::GetRandomFileName())"
  New-Item -ItemType Directory -Path "$tmp\files" -Force | Out-Null
  $src = "$tmp\files"
} else {
  $src = Split-Path -Parent $MyInvocation.MyCommand.Path
  $src = Split-Path -Parent $src # go up to project root
}

if ($PLATFORM -eq "opencode") {
  New-Item -ItemType Directory -Force -Path ".opencode\plugins", ".opencode\agents", ".opencode\commands" | Out-Null
  if ($IS_PIPE) {
    dl ".opencode/plugins/ciel.ts" "$src\.opencode\plugins\ciel.ts"
    @("ciel.md", "ciel-researcher.md", "ciel-explorer.md", "ciel-critic.md", "ciel-improver.md") | ForEach-Object {
      dl ".opencode/agents/$_" "$src\.opencode\agents\$_"
    }
    @("ciel-init.md", "ciel-update.md", "ciel-refresh.md", "ciel-improve.md", "ciel-eval.md", "ciel-create-skill.md", "ciel-recommend.md", "ciel-audit.md") | ForEach-Object {
      dl ".opencode/commands/$_" "$src\.opencode\commands\$_"
    }
  }
  Copy-Item "$src\.opencode\plugins\ciel.ts" ".opencode\plugins\" -Force
  Copy-Item "$src\.opencode\agents\*.md" ".opencode\agents\" -Force
  Copy-Item "$src\.opencode\commands\*.md" ".opencode\commands\" -Force
  ok "OpenCode plugin and agents installed"

  if (!(Test-Path "AGENTS.md")) {
    if ($IS_PIPE) { dl "AGENTS.md" "$src\AGENTS.md" }
    Copy-Item "$src\AGENTS.md" "AGENTS.md" -Force
    ok "AGENTS.md created"
  }

  # opencode.json
  $cfg = "opencode.json"
  if (!(Test-Path $cfg)) {
    @'{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["./.opencode/plugins/ciel.ts"],
  "instructions": ["AGENTS.md"]
}'@ | Set-Content $cfg -Encoding UTF8
    ok "opencode.json created"
  } else {
    warn "opencode.json exists -- add .opencode/plugins/ciel.ts to plugin array manually if needed"
  }
}

if ($PLATFORM -eq "claude") {
  New-Item -ItemType Directory -Force -Path ".claude\agents", ".claude\hooks" | Out-Null
  if ($IS_PIPE) {
    @("ciel-researcher.md", "ciel-explorer.md", "ciel-critic.md", "ciel-improver.md") | ForEach-Object {
      dl ".claude/agents/$_" "$src\.claude\agents\$_"
    }
    @("check-test-first.sh", "block-destructive.sh", "track-file.sh", "meta-critiquer.sh") | ForEach-Object {
      dl ".claude/hooks/$_" "$src\.claude\hooks\$_"
    }
    dl ".claude/settings.json" "$src\.claude\settings.json"
    dl "CLAUDE.md" "$src\CLAUDE.md"
  }
  Copy-Item "$src\.claude\agents\*.md" ".claude\agents\" -Force
  Copy-Item "$src\.claude\hooks\*.sh" ".claude\hooks\" -Force
  Copy-Item "$src\.claude\settings.json" ".claude\settings.json" -Force
  Copy-Item "$src\CLAUDE.md" "CLAUDE.md" -Force
  ok "Claude Code agents and hooks installed"

  if (!(Test-Path "AGENTS.md")) {
    if ($IS_PIPE) { dl "AGENTS.md" "$src\AGENTS.md" }
    Copy-Item "$src\AGENTS.md" "AGENTS.md" -Force
    ok "AGENTS.md created"
  }
}

# .ciel directory
New-Item -ItemType Directory -Force -Path ".ciel" | Out-Null
if (!(Test-Path ".ciel\map.json")) { '{"modules":[],"lastUpdated":""}' | Set-Content ".ciel\map.json" -Encoding UTF8 }
if (!(Test-Path ".ciel\memory.json")) { '{}' | Set-Content ".ciel\memory.json" -Encoding UTF8 }
ok ".ciel/ directory initialized"

Write-Host "`nDone`n"
Write-Host "  > Restart your coding agent to load Ciel v$CIEL_VERSION`n"
