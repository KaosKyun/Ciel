# Ciel — PostToolUse hook for Write/Edit (PowerShell)
# Trigger: PostToolUse on Write|Edit
# Purpose: inject relire-critic dispatch instruction after code write

$Input_ = [Console]::In.ReadToEnd()
$filePath = ""
try {
    $parsed = $Input_ | ConvertFrom-Json
    $filePath = $parsed.tool_input.file_path
    if (-not $filePath) { $filePath = $parsed.tool_input.path }
} catch {}

if (-not $filePath) { exit 0 }

if ($filePath -notmatch '\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$') {
    exit 0
}

$msg = "CIEL RELIRE OBLIGATOIRE — $filePath vient d'etre ecrit. Invoke relire-critic skill now (inline for Trivial, or dispatch critic agent MODE=RELIRE for Standard/Critical with 3+ files). Required: 3 RISQUES (functional + imports + data assumptions) + FIX/ACCEPT/DEFER + 8-item checklist. Ne pas continuer avant le verdict."

@{
    hookSpecificOutput = @{
        hookEventName = "PostToolUse"
        additionalContext = $msg
    }
} | ConvertTo-Json -Compress
exit 0
