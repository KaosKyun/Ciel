#!/usr/bin/env pwsh
# Ciel — Pre-write gate (PowerShell / Windows)
# Trigger: PreToolUse Write|Edit
# Injects FLUX checkpoint context before writing code files
# Never blocks (exit 0 always)
#
# Wire in settings.json:
#   "command": "pwsh -File \"%USERPROFILE%\\.claude\\plugins\\ciel\\hooks\\pre-write-gate.ps1\""

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

# Critical file patterns
if ($filePath -imatch '(auth|security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret)') {
    $msg = "CIEL [CRITIQUE] $filePath — Avant d'ecrire: (1) SECURITE STRIDE fait? (2) FLUX narre? (3) Dispatch critic apres FAIRE obligatoire."
} else {
    $msg = "CIEL $filePath — FLUX narre pour ce changement? Si Standard/Critical: researcher + explorer dispatche?"
}

$output = [ordered]@{
    hookSpecificOutput = [ordered]@{
        hookEventName   = "PreToolUse"
        additionalContext = $msg
    }
} | ConvertTo-Json -Compress

Write-Output $output
exit 0
