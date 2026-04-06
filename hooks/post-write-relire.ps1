#!/usr/bin/env pwsh
# Ciel — Post-write RELIRE injection (PowerShell / Windows)
# Trigger: PostToolUse Write|Edit
# Forces RELIRE after every code file write
# Never blocks (exit 0 always)
#
# Wire in settings.json:
#   "command": "pwsh -File \"%USERPROFILE%\\.claude\\plugins\\ciel\\hooks\\post-write-relire.ps1\""

$json = [Console]::In.ReadToEnd()

$filePath = ""
try {
    $data = $json | ConvertFrom-Json
    $toolInput = $data.tool_input
    if ($toolInput.file_path) { $filePath = $toolInput.file_path }
    elseif ($toolInput.path)  { $filePath = $toolInput.path }
} catch { }

if (-not $filePath) { exit 0 }

# Skip non-code files
if ($filePath -notmatch '\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte)$') {
    exit 0
}

$pluginDir = if ($env:CIEL_PLUGIN_DIR) { $env:CIEL_PLUGIN_DIR } else { "$HOME\.claude\plugins\ciel" }
$criticPath = "$pluginDir\agents\critic.md"

$msg = "CIEL RELIRE OBLIGATOIRE — $filePath vient d'etre ecrit. Dispatch un general-purpose Agent en utilisant $criticPath comme prompt (pas superpowers:code-reviewer). Input: MODE=RELIRE, CHANGED_FILES=[$filePath+autres], QUOI_GOAL=[objectif], IMPLEMENTATION=[resume 3-5 phrases]. Ne pas continuer avant le verdict BLOCKING/IMPORTANT/MINOR."

$output = [ordered]@{
    hookSpecificOutput = [ordered]@{
        hookEventName     = "PostToolUse"
        additionalContext = $msg
    }
} | ConvertTo-Json -Compress

Write-Output $output
exit 0
