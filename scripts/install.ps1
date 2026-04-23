#!/usr/bin/env pwsh
# Ciel Universal Installer v4.0.0 (PowerShell)
# Supports: Claude Code, Cursor, Windsurf, Codex CLI, OpenCode, Kilo Code, Ollama, LM Studio
# Usage: pwsh scripts/install.ps1 [project-root] [flags]
#        irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.ps1 | iex
#
# Flags:
#   --uninstall         Remove all files tracked in ~/.ciel/manifest.json
#   --check-update      Query GitHub for newer VERSION and report
#   --update            Uninstall + re-install latest from main
#   --platform=<name>   Skip auto-detection, install specified platform only
#   --with-mcp=LIST     Register MCP servers from .mcp.json (CSV: playwright,context7)
#   -y, --yes           Skip interactive confirmations
#
# Parity with install.sh v4.0.0:
#   - Non-destructive opencode.json merge via Python
#   - Platform detection with --platform override
#   - Whitelist preservation on uninstall
#   - Manifest tracking for clean uninstall

$ErrorActionPreference = "Stop"

function ok($msg)   { Write-Host "  v $msg" -ForegroundColor Green }
function info($msg) { Write-Host "  > $msg" -ForegroundColor Cyan }
function warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }
function has($cmd)  { $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue) }
function isDir($p)  { Test-Path $p -PathType Container }
function isFile($p) { Test-Path $p -PathType Leaf }

# ─── Pipe/irm|iex detection ───────────────────────────────────────────────────
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
        Write-Error "ERROR: git clone failed. Try: git clone https://github.com/KaosKyun/Ciel.git `$HOME/.ciel; pwsh `$HOME/.ciel/scripts/install.ps1"
        exit 1
    }
    $CIEL_DIR = $TEMP_DIR
    $script:_CielTempDir = $TEMP_DIR
    Register-EngineEvent PowerShell.Exiting -Action {
        if ($script:_CielTempDir) { Remove-Item $script:_CielTempDir -Recurse -Force -ErrorAction SilentlyContinue }
    } | Out-Null
}

# ─── Flag parsing ─────────────────────────────────────────────────────────────
$FLAG_UNINSTALL = $false
$FLAG_CHECK_UPDATE = $false
$FLAG_UPDATE = $false
$FLAG_YES = $false
$FLAG_PLATFORM = ""
$MCP_LIST = ""
$positionalArgs = @()

foreach ($arg in $args) {
    if ($arg -match "^--uninstall$") { $FLAG_UNINSTALL = $true }
    elseif ($arg -match "^--check-update$") { $FLAG_CHECK_UPDATE = $true }
    elseif ($arg -match "^--update$") { $FLAG_UPDATE = $true }
    elseif ($arg -match "^--platform=(.+)$") { $FLAG_PLATFORM = $matches[1] }
    elseif ($arg -match "^--with-mcp=(.+)$") { $MCP_LIST = $matches[1] }
    elseif ($arg -match "^-y$|^--yes$") { $FLAG_YES = $true }
    elseif ($arg -match "^-h$|^--help$") {
        Get-Content $MyInvocation.MyCommand.Path -TotalCount 20 | ForEach-Object {
            if ($_ -match "^# ") { Write-Host $_.Substring(2) }
        }
        exit 0
    }
    elseif ($arg -match "^-") {
        warn "Unknown flag: $arg (see --help)"
    }
    else {
        $positionalArgs += $arg
    }
}

$PROJECT_ROOT  = if ($positionalArgs[0]) { $positionalArgs[0] } else { (Get-Location).Path }
$PLATFORMS_DIR = "$CIEL_DIR/platforms"
$PLUGIN_DIR    = if ($env:CIEL_PLUGIN_DIR) { $env:CIEL_PLUGIN_DIR } else { "$HOME/.claude/plugins/ciel" }
$MANIFEST_PATH = "$HOME/.ciel/manifest.json"

# ─── Manifest helpers ─────────────────────────────────────────────────────────
$INSTALLED_FILES = @()

function _manifest_append_file($f) {
    if (Test-Path $f) {
        $INSTALLED_FILES += $f
    }
}

function _manifest_read_version {
    if (-not (isFile $MANIFEST_PATH)) { return $null }
    $manifest = Get-Content $MANIFEST_PATH -Raw | ConvertFrom-Json
    return $manifest.version
}

function _manifest_write {
    $version = if (isFile "$CIEL_DIR/VERSION") {
        (Get-Content "$CIEL_DIR/VERSION" -Raw).Trim()
    } else { "4.0.0" }
    
    $manifest = @{
        version = $version
        installed_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        files = $INSTALLED_FILES
    }
    
    New-Item -ItemType Directory -Force (Split-Path $MANIFEST_PATH) | Out-Null
    $manifest | ConvertTo-Json -Depth 3 | Set-Content $MANIFEST_PATH
    ok "Manifest written: $MANIFEST_PATH (v$version, $($INSTALLED_FILES.Count) files)"
}

function _register_installed_files {
    # Claude Code
    if (isDir "$HOME/.claude/skills/ciel") { _manifest_append_file "$HOME/.claude/skills/ciel" }
    foreach ($cat in @("workflow", "research", "domain", "utility", "meta")) {
        if (isDir "$CIEL_DIR/skills/$cat") {
            Get-ChildItem "$CIEL_DIR/skills/$cat" -Directory | ForEach-Object {
                $name = $_.Name
                if (isDir "$HOME/.claude/skills/$name") {
                    _manifest_append_file "$HOME/.claude/skills/$name"
                }
            }
        }
    }
    foreach ($a in @("researcher", "explorer", "critic", "improver")) {
        if (isFile "$HOME/.claude/agents/$a.md") { _manifest_append_file "$HOME/.claude/agents/$a.md" }
    }
    Get-ChildItem "$HOME/.claude/commands" -Filter "ciel*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        _manifest_append_file $_.FullName
    }
    if (isDir "$HOME/.claude/plugins/ciel") { _manifest_append_file "$HOME/.claude/plugins/ciel" }
    
    # Project-scope
    if (isFile "$PROJECT_ROOT/ciel-overlay.md") { _manifest_append_file "$PROJECT_ROOT/ciel-overlay.md" }
    if (isFile "$PROJECT_ROOT/.cursor/rules/ciel.mdc") { _manifest_append_file "$PROJECT_ROOT/.cursor/rules/ciel.mdc" }
    if (isFile "$PROJECT_ROOT/.windsurf/rules/ciel.md") { _manifest_append_file "$PROJECT_ROOT/.windsurf/rules/ciel.md" }
    if (isFile "$PROJECT_ROOT/.kilocode/rules/ciel.md") { _manifest_append_file "$PROJECT_ROOT/.kilocode/rules/ciel.md" }
    
    # OpenCode
    if (isFile "$PROJECT_ROOT/.opencode/plugins/ciel.ts") { _manifest_append_file "$PROJECT_ROOT/.opencode/plugins/ciel.ts" }
    Get-ChildItem "$PROJECT_ROOT/.opencode/agents" -Filter "ciel-*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        _manifest_append_file $_.FullName
    }
    Get-ChildItem "$PROJECT_ROOT/.opencode/commands" -Filter "ciel*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        _manifest_append_file $_.FullName
    }
}

# ─── Semver compare ───────────────────────────────────────────────────────────
function _semver_cmp($a, $b) {
    $a_parts = $a.Split('.') | ForEach-Object { [int]$_ }
    $b_parts = $b.Split('.') | ForEach-Object { [int]$_ }
    
    for ($i = 0; $i -lt 3; $i++) {
        $a_val = if ($i -lt $a_parts.Count) { $a_parts[$i] } else { 0 }
        $b_val = if ($i -lt $b_parts.Count) { $b_parts[$i] } else { 0 }
        if ($a_val -gt $b_val) { return 1 }
        if ($a_val -lt $b_val) { return -1 }
    }
    return 0
}

# ─── Update check ─────────────────────────────────────────────────────────────
function _check_update {
    $local_version = _manifest_read_version
    if (-not $local_version) {
        warn "No manifest at $MANIFEST_PATH — run a fresh install first"
        return 1
    }
    
    info "Local version:  $local_version"
    info "Checking GitHub..."
    
    try {
        $remote_version = (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION" -UseBasicParsing).Trim()
    } catch {
        warn "Could not fetch remote VERSION (network / GitHub unreachable)"
        return 1
    }
    
    info "Remote version: $remote_version"
    
    $cmp = _semver_cmp $remote_version $local_version
    if ($cmp -eq 0) {
        ok "Up to date."
        return 0
    } elseif ($cmp -eq -1) {
        ok "Up to date. (local ahead of remote — CDN stale or dev build)"
        return 0
    } else {
        Write-Host ""
        warn "Update available: v$local_version → v$remote_version"
        Write-Host "  Run: irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.ps1 | iex --update"
        return 2
    }
}

# ─── Uninstall ────────────────────────────────────────────────────────────────
function _do_uninstall {
    if (-not (isFile $MANIFEST_PATH)) {
        warn "No manifest at $MANIFEST_PATH — nothing to uninstall"
        return 1
    }
    
    $manifest = Get-Content $MANIFEST_PATH -Raw | ConvertFrom-Json
    $files = $manifest.files
    
    if (-not $files -or $files.Count -eq 0) {
        warn "Manifest has no file entries"
        return 1
    }
    
    info "Manifest lists $($files.Count) files."
    
    if (-not $FLAG_YES) {
        $ans = Read-Host "  Delete these files? [y/N]"
        if ($ans -notmatch "^[Yy]$") {
            Write-Host "  Aborted."
            return 0
        }
    }
    
    # Whitelist regex (preserve user configs)
    $preserve_re = '\.mcp\.json(\.backup-|$)|ciel-overlay\.md$|opencode\.json(\.bak-|$)|\.claude/settings\.json(\.bak-|$)'
    
    $removed = 0
    $preserved = 0
    
    foreach ($f in $files) {
        if (-not $f) { continue }
        if ($f -match $preserve_re) {
            info "Preserved (whitelist): $f"
            $preserved++
            continue
        }
        if (Test-Path $f) {
            Remove-Item $f -Recurse -Force
            $removed++
        }
    }
    
    # Clean empty dirs
    foreach ($d in @(
        "$HOME/.claude/skills/ciel",
        "$HOME/.claude/plugins/ciel",
        "$HOME/.ciel/ollama",
        "$HOME/.ciel/lmstudio"
    )) {
        if (isDir $d) {
            Remove-Item $d -Force -ErrorAction SilentlyContinue
        }
    }
    
    if (isFile $MANIFEST_PATH) { Remove-Item $MANIFEST_PATH -Force }
    if (isFile "$HOME/.ciel/.last-update-check") { Remove-Item "$HOME/.ciel/.last-update-check" -Force }
    if (isDir "$HOME/.ciel") { Remove-Item "$HOME/.ciel" -Force -ErrorAction SilentlyContinue }
    
    ok "Removed $removed files (preserved $preserved)."
}

# ─── Update ───────────────────────────────────────────────────────────────────
function _do_update {
    if (-not (isFile $MANIFEST_PATH)) {
        warn "No manifest — cannot --update (not installed via v2.1.0+)"
        Write-Host "  Run: pwsh scripts/install.ps1  (fresh install)"
        return 1
    }
    
    $rc = _check_update
    if ($rc -eq 0) {
        ok "Already on the latest version — nothing to do."
        return 0
    } elseif ($rc -eq 1) {
        warn "Update check failed — refusing to proceed"
        return 1
    }
    
    info "Proceeding with update..."
    $FLAG_YES = $true
    _do_uninstall
    
    info "Fetching latest installer..."
    $temp_installer = [System.IO.Path]::GetTempFileName() + ".ps1"
    try {
        Invoke-RestMethod -Uri "https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.ps1" -OutFile $temp_installer
        & pwsh -File $temp_installer -y
    } finally {
        if (Test-Path $temp_installer) { Remove-Item $temp_installer -Force }
    }
}

# ─── Flag short-circuits ──────────────────────────────────────────────────────
if ($FLAG_UNINSTALL) {
    Write-Host "`nCiel Uninstall" -ForegroundColor White
    _do_uninstall
    exit $LASTEXITCODE
}

if ($FLAG_CHECK_UPDATE) {
    Write-Host "`nCiel Update Check" -ForegroundColor White
    _check_update
    exit $LASTEXITCODE
}

if ($FLAG_UPDATE) {
    Write-Host "`nCiel Update" -ForegroundColor White
    _do_update
    exit $LASTEXITCODE
}

# ─── Detect existing install ──────────────────────────────────────────────────
$isUpdate = isFile "$PROJECT_ROOT/ciel-overlay.md"

Write-Host ""
if ($isUpdate) {
    Write-Host "Ciel Universal Installer v4.0.0 " -ForegroundColor White -NoNewline
    Write-Host "(update detected)" -ForegroundColor Yellow
} else {
    Write-Host "Ciel Universal Installer v4.0.0" -ForegroundColor White
}
Write-Host "Plugin : $CIEL_DIR"
Write-Host "Project: $PROJECT_ROOT"
Write-Host ""

# ─── Purge Ciel files helper ──────────────────────────────────────────────────
function _purge_ciel_files($dir, $pattern) {
    if (isDir $dir) {
        Get-ChildItem $dir -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item $_.FullName -Force
        }
    }
}

function _install_overlay {
    if (-not (isFile "$PROJECT_ROOT/ciel-overlay.md")) {
        Copy-Item "$CIEL_DIR/overlay-template.md" "$PROJECT_ROOT/ciel-overlay.md"
        warn "Created ciel-overlay.md — fill in your stack versions and CI config"
    }
}

# ─── Purge manual install ─────────────────────────────────────────────────────
function _purge_manual_install {
    info "Purging existing Ciel install..."
    
    if (isDir "$HOME/.claude/skills/ciel") {
        Remove-Item "$HOME/.claude/skills/ciel" -Recurse -Force
        ok "Removed `$HOME/.claude/skills/ciel/"
    }
    
    if (isDir "$HOME/.claude/commands") {
        Get-ChildItem "$HOME/.claude/commands" -Filter "ciel*.md" -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item $_.FullName -Force
        }
        ok "Removed ciel commands"
    }
    
    foreach ($agent in @("researcher.md", "explorer.md", "critic.md", "improver.md")) {
        $p = "$HOME/.claude/agents/$agent"
        if (isFile $p) { Remove-Item $p -Force }
    }
    ok "Removed ciel agents"
    
    if (isDir "$HOME/.claude/plugins/ciel") {
        Remove-Item "$HOME/.claude/plugins/ciel" -Recurse -Force
        ok "Removed `$HOME/.claude/plugins/ciel/"
    }
}

# ─── Platform installers ──────────────────────────────────────────────────────
function install_claude {
    info "Claude Code..."
    _purge_manual_install
    
    if (has "claude") {
        $result = & claude plugin install $CIEL_DIR 2>&1
        if ($LASTEXITCODE -eq 0) {
            ok "Installed via claude plugin install (full plugin)"
            _claude_hooks
            _install_overlay
            return $true
        }
    }
    
    info "Falling back to manual install..."
    
    New-Item -ItemType Directory -Force "$HOME/.claude/skills" | Out-Null
    Copy-Item "$CIEL_DIR/skills/ciel" "$HOME/.claude/skills/" -Recurse -Force
    ok "skills/ciel -> `$HOME/.claude/skills/ciel/"
    
    New-Item -ItemType Directory -Force "$HOME/.claude/agents" | Out-Null
    Get-ChildItem "$CIEL_DIR/agents" -Filter "*.md" | ForEach-Object {
        Copy-Item $_.FullName "$HOME/.claude/agents/"
    }
    ok "agents/ -> `$HOME/.claude/agents/"
    
    New-Item -ItemType Directory -Force "$HOME/.claude/commands" | Out-Null
    Get-ChildItem "$CIEL_DIR/commands" -Filter "*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName "$HOME/.claude/commands/"
    }
    ok "commands/ -> `$HOME/.claude/commands/"
    
    $manualPluginDir = "$HOME/.claude/plugins/ciel"
    New-Item -ItemType Directory -Force "$manualPluginDir/hooks" | Out-Null
    Copy-Item "$CIEL_DIR/hooks" "$manualPluginDir/" -Recurse -Force
    Copy-Item "$CIEL_DIR/overlay-template.md" "$manualPluginDir/"
    ok "hooks/ -> `$HOME/.claude/plugins/ciel/hooks/"
    _claude_hooks
    _install_overlay
    return $true
}

function _claude_hooks {
    $hooks_dir = "$HOME/.claude/plugins/ciel/hooks"
    if (isDir $hooks_dir) {
        Get-ChildItem $hooks_dir -Filter "*.sh" | ForEach-Object {
            $mode = (Get-Item $_.FullName).Attributes
            # Mark executable (Unix-style via chmod if available)
            if (has "chmod") { & chmod +x $_.FullName 2>$null }
        }
        ok "Hooks set executable"
    }
    
    $settings = "$HOME/.claude/settings.json"
    if (-not (isFile $settings)) {
        Copy-Item "$CIEL_DIR/settings.json" $settings
        ok "settings.json created with Ciel hooks"
    } else {
        if (Select-String -Path $settings -Pattern "(pre-write-gate|pre-tool-write|post-write-relire|post-tool-write)" -Quiet) {
            if (Select-String -Path $settings -Pattern "pre-write-gate|post-write-relire" -Quiet) {
                warn "settings.json references v1.x hook names — update to v2.0.0 names"
            } else {
                ok "Hooks already in settings.json"
            }
        } else {
            warn "settings.json exists — merge hooks manually from $CIEL_DIR/settings.json"
        }
    }
}

function install_cursor {
    info "Cursor..."
    New-Item -ItemType Directory -Force "$PROJECT_ROOT/.cursor/rules" | Out-Null
    if (isFile "$PLATFORMS_DIR/cursor/.cursor/rules/ciel.mdc") {
        Copy-Item "$PLATFORMS_DIR/cursor/.cursor/rules/ciel.mdc" "$PROJECT_ROOT/.cursor/rules/ciel.mdc"
        $size = (Get-Item "$PROJECT_ROOT/.cursor/rules/ciel.mdc").Length
        ok "Copied .cursor/rules/ciel.mdc ($size bytes)"
        _install_overlay
        return $true
    }
    warn "Missing cursor platform files"
    return $false
}

function install_windsurf {
    info "Windsurf..."
    New-Item -ItemType Directory -Force "$PROJECT_ROOT/.windsurf/rules" | Out-Null
    if (isFile "$PLATFORMS_DIR/windsurf/.windsurf/rules/ciel.md") {
        Copy-Item "$PLATFORMS_DIR/windsurf/.windsurf/rules/ciel.md" "$PROJECT_ROOT/.windsurf/rules/ciel.md"
        ok "Copied .windsurf/rules/ciel.md"
        _install_overlay
        return $true
    }
    warn "Missing windsurf platform files"
    return $false
}

function install_codex {
    info "Codex CLI..."
    if (isFile "$PLATFORMS_DIR/codex/AGENTS.md") {
        Copy-Item "$PLATFORMS_DIR/codex/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
        ok "Copied AGENTS.md"
        _install_overlay
        return $true
    }
    warn "Missing codex platform files"
    return $false
}

function install_opencode {
    info "OpenCode..."
    _purge_ciel_files "$PROJECT_ROOT/.opencode/agents" "ciel-*.md"
    _purge_ciel_files "$PROJECT_ROOT/.opencode/commands" "ciel*.md"
    _purge_ciel_files "$PROJECT_ROOT/.opencode/plugins" "ciel.ts"
    
    if (isFile "$PLATFORMS_DIR/opencode/AGENTS.md") {
        Copy-Item "$PLATFORMS_DIR/opencode/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
        ok "Copied AGENTS.md"
    }
    
    # opencode.json: non-destructive merge (parity with install.sh)
    $opencodeTarget = "$PROJECT_ROOT/opencode.json"
    if (-not (isFile $opencodeTarget)) {
        if (isFile "$PLATFORMS_DIR/opencode/opencode.json") {
            Copy-Item "$PLATFORMS_DIR/opencode/opencode.json" $opencodeTarget
            ok "Copied opencode.json"
        }
    } elseif (has "python3") {
        # Backup + merge via Python
        $timestamp = Get-Date -Format "yyyyMMddTHHmmss"
        $backup = "$opencodeTarget.bak-$timestamp"
        Copy-Item $opencodeTarget $backup
        ok "Backup: $backup"
        info "Merging opencode.json (preserving your model/provider/mcp/keybinds config)"
        
        $pythonScript = @'
import json, os, sys
target = sys.argv[1]
with open(target) as f:
    current = json.load(f)
current.setdefault("$schema", "https://opencode.ai/config.json")
ins = current.get("instructions")
if ins is None:
    current["instructions"] = ["AGENTS.md"]
elif isinstance(ins, str):
    current["instructions"] = [ins] if ins == "AGENTS.md" else [ins, "AGENTS.md"]
elif isinstance(ins, list) and "AGENTS.md" not in ins:
    current["instructions"] = ins + ["AGENTS.md"]
target_plugin = "./.opencode/plugins/ciel.ts"
plg = current.get("plugin")
if plg is None:
    current["plugin"] = [target_plugin]
elif isinstance(plg, str):
    current["plugin"] = [plg] if plg == target_plugin else [plg, target_plugin]
elif isinstance(plg, list) and target_plugin not in plg:
    current["plugin"] = plg + [target_plugin]
with open(target, "w") as f:
    json.dump(current, f, indent=2)
    f.write("\n")
'@
        & python3 -c $pythonScript $opencodeTarget
        ok "Merged opencode.json"
    } else {
        warn "opencode.json exists and python3 unavailable — merge manually"
    }
    
    # Install Ciel agents
    if (isDir "$PLATFORMS_DIR/opencode/.opencode/agents") {
        New-Item -ItemType Directory -Force "$PROJECT_ROOT/.opencode/agents" | Out-Null
        Get-ChildItem "$PLATFORMS_DIR/opencode/.opencode/agents" -Filter "*.md" | ForEach-Object {
            Copy-Item $_.FullName "$PROJECT_ROOT/.opencode/agents/"
        }
        ok "Copied .opencode/agents/ (ciel-researcher, explorer, critic, improver)"
    } else {
        warn "Missing .opencode/agents/ — run: bash scripts/build-platforms.sh --target=opencode"
    }
    
    # Install /ciel commands
    if (isDir "$PLATFORMS_DIR/opencode/.opencode/commands") {
        New-Item -ItemType Directory -Force "$PROJECT_ROOT/.opencode/commands" | Out-Null
        Get-ChildItem "$PLATFORMS_DIR/opencode/.opencode/commands" -Filter "*.md" | ForEach-Object {
            Copy-Item $_.FullName "$PROJECT_ROOT/.opencode/commands/"
        }
        ok "Copied .opencode/commands/ (ciel, ciel-improve, ciel-eval, ...)"
    }
    
    # Install Ciel plugin
    if (isFile "$PLATFORMS_DIR/opencode/.opencode/plugins/ciel.ts") {
        New-Item -ItemType Directory -Force "$PROJECT_ROOT/.opencode/plugins" | Out-Null
        Copy-Item "$PLATFORMS_DIR/opencode/.opencode/plugins/ciel.ts" "$PROJECT_ROOT/.opencode/plugins/ciel.ts"
        ok "Copied .opencode/plugins/ciel.ts"
    } else {
        warn "Missing ciel.ts — run: bash scripts/build-platforms.sh --target=opencode"
    }
    
    _install_overlay
    return $true
}

function install_kilocode {
    info "Kilo Code..."
    _purge_ciel_files "$PROJECT_ROOT/.kilocode/rules" "ciel*.md"
    _purge_ciel_files "$PROJECT_ROOT/.kilo/agents" "*.md"
    
    New-Item -ItemType Directory -Force "$PROJECT_ROOT/.kilocode/rules" | Out-Null
    if (isFile "$PLATFORMS_DIR/kilocode/.kilocode/rules/ciel.md") {
        Copy-Item "$PLATFORMS_DIR/kilocode/.kilocode/rules/ciel.md" "$PROJECT_ROOT/.kilocode/rules/ciel.md"
        ok "Copied .kilocode/rules/ciel.md"
    }
    
    if (isDir "$PLATFORMS_DIR/kilocode/.kilo/agents") {
        New-Item -ItemType Directory -Force "$PROJECT_ROOT/.kilo/agents" | Out-Null
        Get-ChildItem "$PLATFORMS_DIR/kilocode/.kilo/agents" -Filter "*.md" | ForEach-Object {
            Copy-Item $_.FullName "$PROJECT_ROOT/.kilo/agents/"
        }
        ok "Copied .kilo/agents/"
    }
    
    _install_overlay
    return $true
}

function install_ollama {
    info "Ollama..."
    $target = "$HOME/.ciel/ollama"
    New-Item -ItemType Directory -Force $target | Out-Null
    if (isFile "$PLATFORMS_DIR/ollama/Modelfile") {
        Copy-Item "$PLATFORMS_DIR/ollama/Modelfile" "$target/Modelfile"
        ok "Copied Modelfile to $target/"
        Write-Host ""
        Write-Host "    Next steps:"
        Write-Host "    1. Edit $target\Modelfile — change FROM line to your preferred model"
        Write-Host "    2. ollama create ciel -f `"$target\Modelfile`""
        Write-Host "    3. ollama run ciel"
    }
    return $true
}

function install_lmstudio {
    info "LM Studio..."
    $target = "$HOME/.ciel/lmstudio"
    New-Item -ItemType Directory -Force $target | Out-Null
    if (isFile "$PLATFORMS_DIR/lmstudio/system-prompt.md") {
        Copy-Item "$PLATFORMS_DIR/lmstudio/system-prompt.md" "$target/system-prompt.md"
        ok "Copied system-prompt.md to $target/"
        Write-Host ""
        Write-Host "    Next step: copy the prompt from $target\system-prompt.md"
        Write-Host "    into LM Studio -> Settings -> System Prompt -> Save preset 'Ciel'"
    }
    return $true
}

# ─── Platform detection ───────────────────────────────────────────────────────
$DETECTED_KEYS = @()
$DETECTED_LABELS = @()

if (-not $FLAG_PLATFORM) {
    if (has "claude") { $DETECTED_KEYS += "claude"; $DETECTED_LABELS += "Claude Code CLI" }
    if ((isDir "$PROJECT_ROOT/.cursor") -or (has "cursor")) { $DETECTED_KEYS += "cursor"; $DETECTED_LABELS += "Cursor IDE" }
    if ((isDir "$PROJECT_ROOT/.windsurf") -or (has "windsurf")) { $DETECTED_KEYS += "windsurf"; $DETECTED_LABELS += "Windsurf IDE" }
    if (has "codex") { $DETECTED_KEYS += "codex"; $DETECTED_LABELS += "Codex CLI" }
    if (has "opencode") { $DETECTED_KEYS += "opencode"; $DETECTED_LABELS += "OpenCode CLI" }
    if ((isDir "$PROJECT_ROOT/.kilocode") -or (has "code" -and (& code --list-extensions 2>$null) -match "kilocode")) {
        $DETECTED_KEYS += "kilocode"; $DETECTED_LABELS += "Kilo Code"
    }
    if (has "ollama") { $DETECTED_KEYS += "ollama"; $DETECTED_LABELS += "Ollama" }
    if ((has "lms") -or (isDir "$HOME/.lmstudio")) { $DETECTED_KEYS += "lmstudio"; $DETECTED_LABELS += "LM Studio" }
}

$DETECTED_COUNT = $DETECTED_KEYS.Count

# ─── User selection ───────────────────────────────────────────────────────────
$PLATFORMS = @()

if ($FLAG_PLATFORM) {
    $PLATFORMS = @($FLAG_PLATFORM)
    info "Using platform: $FLAG_PLATFORM (from --platform flag)"
} elseif ($DETECTED_COUNT -eq 0) {
    warn "No supported AI tool detected automatically."
    Write-Host "  Available: claude cursor windsurf codex opencode kilocode ollama lmstudio"
    $RAW = Read-Host "  Platforms to install (space-separated or 'all')"
    if ($RAW -eq "all") { $RAW = "claude cursor windsurf codex opencode kilocode ollama lmstudio" }
    $PLATFORMS = $RAW -split " "
} else {
    Write-Host "Detected:" -ForegroundColor White
    for ($i = 0; $i -lt $DETECTED_COUNT; $i++) {
        Write-Host "  " -NoNewline
        Write-Host "[$($i+1)]" -ForegroundColor Cyan -NoNewline
        Write-Host " $($DETECTED_LABELS[$i]) " -NoNewline
        Write-Host "[$($DETECTED_KEYS[$i])]" -ForegroundColor Yellow
    }
    Write-Host ""
    $ANS = Read-Host "  Install? [A]ll / numbers (e.g. 1,3) / [L]ist keys / [Q]uit"
    if (-not $ANS) { $ANS = "A" }
    
    if ($ANS -match "^[AaYy]$") {
        $PLATFORMS = $DETECTED_KEYS
    } elseif ($ANS -match "^[Qq]$") {
        Write-Host "`nAborted." -ForegroundColor White
        exit 0
    } elseif ($ANS -match "^[Ll]") {
        Write-Host "  Keys: $($DETECTED_KEYS -join ', ')"
        $RAW = Read-Host "  Platforms to install (space/comma-separated)"
        $PLATFORMS = $RAW -split "[, ]+" | Where-Object { $_ }
    } elseif ($ANS -match "^[\d,\s]+$") {
        $NUMS = $ANS -split "[, ]+" | Where-Object { $_ }
        foreach ($n in $NUMS) {
            $idx = [int]$n - 1
            if ($idx -ge 0 -and $idx -lt $DETECTED_COUNT) {
                $PLATFORMS += $DETECTED_KEYS[$idx]
            } else {
                warn "Invalid number: $n (expected 1-$DETECTED_COUNT)"
            }
        }
    } else {
        $PLATFORMS = $ANS -split "[, ]+" | Where-Object { $_ }
    }
}

Write-Host ""

# ─── Run ──────────────────────────────────────────────────────────────────────
$INSTALLED = @()

foreach ($p in $PLATFORMS) {
    $result = $false
    switch ($p) {
        "claude"   { $result = install_claude }
        "cursor"   { $result = install_cursor }
        "windsurf" { $result = install_windsurf }
        "codex"    { $result = install_codex }
        "opencode" { $result = install_opencode }
        "kilocode" { $result = install_kilocode }
        "ollama"   { $result = install_ollama }
        "lmstudio" { $result = install_lmstudio }
        default    { warn "Unknown platform '$p' — skipping" }
    }
    if ($result) { $INSTALLED += $p }
    Write-Host ""
}

# ─── Manifest + MCP ───────────────────────────────────────────────────────────
_register_installed_files
_manifest_write

Write-Host ""
Write-Host "Done." -ForegroundColor White
Write-Host "Installed: $($INSTALLED -join ', ')"
Write-Host ""

# Platform-specific next steps
if ($INSTALLED -contains "opencode") {
    Write-Host "OpenCode next steps:" -ForegroundColor Cyan
    Write-Host "  1. Restart OpenCode: opencode (or --reload-config if supported)"
    Write-Host "  2. Test: send a prompt with 'auth' → should see '[CIEL] Depth: Critical'"
    Write-Host "  3. Edit a .ts file → should see '[CIEL RELIRE REQUIRED]' reminder"
    Write-Host ""
}
if ($INSTALLED -contains "claude") {
    Write-Host "Claude Code next steps:" -ForegroundColor Cyan
    Write-Host "  1. Restart Claude Code"
    Write-Host "  2. Send any prompt → should see 'CIEL depth hint' in system-reminder"
    Write-Host ""
}

Write-Host "Edit ciel-overlay.md to set stack versions, CI config, and project rules."
Write-Host "Uninstall:     pwsh scripts/install.ps1 --uninstall"
Write-Host "Check update:  pwsh scripts/install.ps1 --check-update"
Write-Host "Full docs:     https://github.com/KaosKyun/Ciel"
