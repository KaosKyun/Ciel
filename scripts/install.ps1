#!/usr/bin/env pwsh
# Ciel Universal Installer v2 (PowerShell / Windows)
# Supports: Claude Code, Cursor, Windsurf, Codex CLI, OpenCode, Kilo Code, Ollama, LM Studio
# Usage: pwsh scripts/install.ps1 [project-root]
#        irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.ps1 | iex

$ErrorActionPreference = "Stop"

function ok($msg)   { Write-Host "  v $msg" -ForegroundColor Green }
function info($msg) { Write-Host "  > $msg" -ForegroundColor Cyan }
function warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }
function has($cmd)  { $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue) }
function isDir($p)  { Test-Path $p -PathType Container }
function isFile($p) { Test-Path $p -PathType Leaf }

# ─── Pipe/irm|iex detection ───────────────────────────────────────────────────
# When run via irm ... | iex, $PSScriptRoot is empty.
$CIEL_DIR = ""
if ($PSScriptRoot -and (isFile "$PSScriptRoot/../settings.json")) {
    $CIEL_DIR = (Resolve-Path "$PSScriptRoot/..").Path
}

if (-not $CIEL_DIR) {
    $TEMP_DIR = Join-Path ([System.IO.Path]::GetTempPath()) "ciel-install-$([System.IO.Path]::GetRandomFileName())"
    New-Item -ItemType Directory -Force $TEMP_DIR | Out-Null
    Write-Host "> Detected pipe execution — cloning KaosKyun/Ciel to $TEMP_DIR ..." -ForegroundColor Cyan
    git clone --depth=1 --quiet https://github.com/KaosKyun/Ciel.git $TEMP_DIR 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ERROR: git clone failed. Try: git clone https://github.com/KaosKyun/Ciel.git ~/.ciel; pwsh ~/.ciel/scripts/install.ps1"
        exit 1
    }
    $CIEL_DIR = $TEMP_DIR
    $script:_CielTempDir = $TEMP_DIR
    Register-EngineEvent PowerShell.Exiting -Action {
        if ($script:_CielTempDir) { Remove-Item $script:_CielTempDir -Recurse -Force -ErrorAction SilentlyContinue }
    } | Out-Null
}

$PROJECT_ROOT  = if ($args[0]) { $args[0] } else { (Get-Location).Path }
$PLATFORMS_DIR = "$CIEL_DIR/platforms"
$PLUGIN_DIR    = if ($env:CIEL_PLUGIN_DIR) { $env:CIEL_PLUGIN_DIR } else { "$HOME/.claude/plugins/ciel" }

Write-Host ""
Write-Host "Ciel Universal Installer v2" -ForegroundColor White
Write-Host "Plugin : $CIEL_DIR"
Write-Host "Project: $PROJECT_ROOT"
Write-Host ""

# ─── Stack detection (for overlay) ───────────────────────────────────────────
function Detect-Skills($root) {
    $skills = @()
    if (isFile "$root/package.json") {
        $pkg = Get-Content "$root/package.json" -Raw
        if ($pkg -match '"react"|"vue"|"svelte"') { $skills += "frontend-mastery" }
    }
    $hasGradle = (isFile "$root/build.gradle.kts") -or (isFile "$root/build.gradle") -or
                 (Get-ChildItem $root -Filter "build.gradle.kts" -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($hasGradle) { $skills += "backend-mastery" }
    if ((isFile "$root/requirements.txt") -or (isFile "$root/pyproject.toml") -or
        (isFile "$root/go.mod") -or (isFile "$root/Cargo.toml")) { $skills += "backend-mastery" }
    if ((isDir "$root/supabase/migrations") -or (isDir "$root/prisma") -or
        (Get-ChildItem $root -Filter "*.sql" -Recurse -Depth 4 -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        $skills += "database-mastery"
    }
    if (Get-ChildItem $root -Directory -Recurse -Depth 5 -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "auth" -or $_.Name -eq "security" } | Select-Object -First 1) {
        $skills += "security-hardening"
    }
    return $skills | Sort-Object -Unique
}

function Install-Overlay {
    if (-not (isFile "$PROJECT_ROOT/ciel-overlay.md")) {
        Copy-Item "$CIEL_DIR/overlay-template.md" "$PROJECT_ROOT/ciel-overlay.md"
        warn "Created ciel-overlay.md — fill in your stack versions and CI config"
    }
}

# ─── Purge any existing manual install ───────────────────────────────────────
# Prevents duplicate /ciel entries when reinstalling or upgrading.
# Does NOT touch settings.json (hooks stay in place).
function Invoke-PurgeManualInstall {
    info "Purging existing Ciel install..."

    # Skill
    if (isDir "$HOME/.claude/skills/ciel") {
        Remove-Item "$HOME/.claude/skills/ciel" -Recurse -Force
        ok "Removed ~/.claude/skills/ciel/"
    }

    # Commands (ciel*.md)
    if (isDir "$HOME/.claude/commands") {
        Get-ChildItem "$HOME/.claude/commands" -Filter "ciel*.md" -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item $_.FullName -Force }
        ok "Removed ciel commands"
    }

    # Agents (researcher, explorer, critic — Ciel-specific)
    foreach ($agent in @("researcher.md", "explorer.md", "critic.md")) {
        $p = "$HOME/.claude/agents/$agent"
        if (isFile $p) { Remove-Item $p -Force }
    }
    ok "Removed ciel agents"

    # Plugin hooks dir — will be re-created
    if (isDir "$HOME/.claude/plugins/ciel") {
        Remove-Item "$HOME/.claude/plugins/ciel" -Recurse -Force
        ok "Removed ~/.claude/plugins/ciel/"
    }
}

# ─── Platform installers ──────────────────────────────────────────────────────
function Install-Claude {
    info "Claude Code..."

    # Always purge first to avoid duplicate skill/command entries
    Invoke-PurgeManualInstall

    if (has "claude") {
        $result = & claude plugin install $CIEL_DIR 2>&1
        if ($LASTEXITCODE -eq 0) {
            ok "Installed via claude plugin install (full plugin)"
            Set-ClaudeHooks
            Install-Overlay
            return
        }
    }

    info "Falling back to manual install..."

    New-Item -ItemType Directory -Force "$HOME/.claude/skills" | Out-Null
    Copy-Item "$CIEL_DIR/skills/ciel" "$HOME/.claude/skills/" -Recurse -Force
    ok "skills/ciel -> ~/.claude/skills/ciel/"

    New-Item -ItemType Directory -Force "$HOME/.claude/agents" | Out-Null
    Get-ChildItem "$CIEL_DIR/agents" -Filter "*.md" | ForEach-Object {
        Copy-Item $_.FullName "$HOME/.claude/agents/"
    }
    ok "agents/ -> ~/.claude/agents/"

    New-Item -ItemType Directory -Force "$HOME/.claude/commands" | Out-Null
    Get-ChildItem "$CIEL_DIR/commands" -Filter "*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName "$HOME/.claude/commands/"
    }
    ok "commands/ -> ~/.claude/commands/"

    $manualPluginDir = "$HOME/.claude/plugins/ciel"
    New-Item -ItemType Directory -Force "$manualPluginDir/hooks" | Out-Null
    Copy-Item "$CIEL_DIR/hooks" "$manualPluginDir/" -Recurse -Force
    Copy-Item "$CIEL_DIR/overlay-template.md" "$manualPluginDir/"
    ok "hooks/ -> ~/.claude/plugins/ciel/hooks/"
    Set-ClaudeHooks
    Install-Overlay
}

function Set-ClaudeHooks {
    $settings = "$HOME/.claude/settings.json"
    if (-not (isFile $settings)) {
        Copy-Item "$CIEL_DIR/settings.json" $settings
        $content = Get-Content $settings -Raw
        $content = $content -replace 'bash (.+pre-write-gate)\.sh',   'pwsh -File $1.ps1'
        $content = $content -replace 'bash (.+post-write-relire)\.sh', 'pwsh -File $1.ps1'
        Set-Content $settings $content
        ok "settings.json created with Ciel hooks (PowerShell commands)"
    } else {
        if (Select-String -Path $settings -Pattern "pre-write-gate" -Quiet) {
            ok "Hooks already in settings.json"
        } else {
            warn "settings.json exists — merge hooks manually from $CIEL_DIR/settings.json"
            warn "Use pwsh -File ... commands instead of bash for Windows"
        }
    }
}

function Install-Cursor {
    info "Cursor..."
    New-Item -ItemType Directory -Force "$PROJECT_ROOT/.cursor/rules" | Out-Null
    Copy-Item "$PLATFORMS_DIR/cursor/.cursor/rules/ciel.mdc" "$PROJECT_ROOT/.cursor/rules/ciel.mdc"
    ok "Copied .cursor/rules/ciel.mdc"
    Install-Overlay
}

function Install-Windsurf {
    info "Windsurf..."
    New-Item -ItemType Directory -Force "$PROJECT_ROOT/.windsurf/rules" | Out-Null
    Copy-Item "$PLATFORMS_DIR/windsurf/.windsurf/rules/ciel.md" "$PROJECT_ROOT/.windsurf/rules/ciel.md"
    ok "Copied .windsurf/rules/ciel.md"
    Install-Overlay
}

function Install-Codex {
    info "Codex CLI..."
    Copy-Item "$PLATFORMS_DIR/codex/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
    ok "Copied AGENTS.md"
    Install-Overlay
}

function Install-OpenCode {
    info "OpenCode..."
    Copy-Item "$PLATFORMS_DIR/opencode/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
    ok "Copied AGENTS.md"
    if (-not (isFile "$PROJECT_ROOT/opencode.json")) {
        Copy-Item "$PLATFORMS_DIR/opencode/opencode.json" "$PROJECT_ROOT/opencode.json"
        ok "Copied opencode.json"
    } else {
        warn "opencode.json exists — add AGENTS.md to the instructions array manually"
    }
    Install-Overlay
}

function Install-KiloCode {
    info "Kilo Code..."
    New-Item -ItemType Directory -Force "$PROJECT_ROOT/.kilocode/rules" | Out-Null
    Copy-Item "$PLATFORMS_DIR/kilocode/.kilocode/rules/ciel.md" "$PROJECT_ROOT/.kilocode/rules/ciel.md"
    ok "Copied .kilocode/rules/ciel.md"
    Install-Overlay
}

function Install-Ollama {
    info "Ollama..."
    $target = "$HOME/.ciel/ollama"
    New-Item -ItemType Directory -Force $target | Out-Null
    Copy-Item "$PLATFORMS_DIR/ollama/Modelfile" "$target/Modelfile"
    ok "Copied Modelfile to $target/"
    Write-Host ""
    Write-Host "    Next steps:"
    Write-Host "    1. Edit $target\Modelfile — change FROM line to your preferred model"
    Write-Host "    2. ollama create ciel -f `"$target\Modelfile`""
    Write-Host "    3. ollama run ciel"
}

function Install-LmStudio {
    info "LM Studio..."
    $target = "$HOME/.ciel/lmstudio"
    New-Item -ItemType Directory -Force $target | Out-Null
    Copy-Item "$PLATFORMS_DIR/lmstudio/system-prompt.md" "$target/system-prompt.md"
    ok "Copied system-prompt.md to $target/"
    Write-Host ""
    Write-Host "    Next step: copy the prompt from $target\system-prompt.md"
    Write-Host "    into LM Studio -> Settings -> System Prompt -> Save preset 'Ciel'"
}

# ─── Platform detection ───────────────────────────────────────────────────────
$detected = [ordered]@{}
if (has "claude")    { $detected["claude"]    = "Claude Code CLI" }
if ((isDir "$PROJECT_ROOT/.cursor") -or (has "cursor"))      { $detected["cursor"]    = "Cursor IDE" }
if ((isDir "$PROJECT_ROOT/.windsurf") -or (has "windsurf"))  { $detected["windsurf"]  = "Windsurf IDE" }
if (has "codex")     { $detected["codex"]     = "Codex CLI" }
if (has "opencode")  { $detected["opencode"]  = "OpenCode CLI" }
if ((isDir "$PROJECT_ROOT/.kilocode") -or
    (has "code" -and (& code --list-extensions 2>$null) -match "kilocode")) {
    $detected["kilocode"] = "Kilo Code"
}
if (has "ollama")    { $detected["ollama"]    = "Ollama" }
if ((has "lms") -or (isDir "$HOME/.lmstudio")) { $detected["lmstudio"] = "LM Studio" }

# ─── User selection ───────────────────────────────────────────────────────────
$platforms = @()
if ($detected.Count -eq 0) {
    warn "No supported AI tool detected automatically."
    Write-Host "  Available: claude cursor windsurf codex opencode kilocode ollama lmstudio"
    $raw = Read-Host "  Platforms to install (space-separated or 'all')"
    if ($raw -eq "all") { $raw = "claude cursor windsurf codex opencode kilocode ollama lmstudio" }
    $platforms = $raw -split " "
} else {
    # Build indexed list for selection
    $detectedKeys = @($detected.Keys)
    $detectedCount = $detectedKeys.Count

    Write-Host "Detected:" -ForegroundColor White
    for ($i = 0; $i -lt $detectedCount; $i++) {
        $k = $detectedKeys[$i]
        Write-Host "  " -NoNewline
        Write-Host "[$($i+1)]" -ForegroundColor Cyan -NoNewline
        Write-Host " $($detected[$k]) " -NoNewline
        Write-Host "[$k]" -ForegroundColor Yellow
    }
    Write-Host ""
    $ans = Read-Host "  Install? [A]ll / numbers (e.g. 1,3) / [L]ist keys / [Q]uit"
    if (-not $ans) { $ans = "A" }

    if ($ans -match "^[AaYy]$") {
        $platforms = $detectedKeys
    } elseif ($ans -match "^[Qq]$") {
        Write-Host "`nAborted." -ForegroundColor White
        exit 0
    } elseif ($ans -match "^[Ll]") {
        Write-Host "  Keys: $($detectedKeys -join ', ')"
        $raw = Read-Host "  Platforms to install (space/comma-separated)"
        $platforms = $raw -split "[, ]+" | Where-Object { $_ }
    } elseif ($ans -match "^[\d,\s]+$") {
        # Number selection: "1,3" or "1 3" or "2"
        $nums = $ans -split "[, ]+" | Where-Object { $_ }
        $platforms = @()
        foreach ($n in $nums) {
            $idx = [int]$n - 1
            if ($idx -ge 0 -and $idx -lt $detectedCount) {
                $platforms += $detectedKeys[$idx]
            } else {
                warn "Invalid number: $n (expected 1-$detectedCount)"
            }
        }
    } else {
        # Treat as space/comma-separated platform keys
        $platforms = $ans -split "[, ]+" | Where-Object { $_ }
    }
}

Write-Host ""

# ─── Run ──────────────────────────────────────────────────────────────────────
$installed = @()
foreach ($p in $platforms) {
    switch ($p) {
        "claude"   { Install-Claude;   $installed += "claude"   }
        "cursor"   { Install-Cursor;   $installed += "cursor"   }
        "windsurf" { Install-Windsurf; $installed += "windsurf" }
        "codex"    { Install-Codex;    $installed += "codex"    }
        "opencode" { Install-OpenCode; $installed += "opencode" }
        "kilocode" { Install-KiloCode; $installed += "kilocode" }
        "ollama"   { Install-Ollama;   $installed += "ollama"   }
        "lmstudio" { Install-LmStudio; $installed += "lmstudio" }
        default    { warn "Unknown platform '$p' — skipping" }
    }
    Write-Host ""
}

Write-Host "Done." -ForegroundColor White
Write-Host "Installed: $($installed -join ', ')"
Write-Host ""
Write-Host "Edit ciel-overlay.md to set stack versions, CI config, and project rules."
Write-Host "Full docs: https://github.com/KaosKyun/Ciel"
