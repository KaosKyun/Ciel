# Ciel — PreToolUse hook for Write/Edit (PowerShell)
# Trigger: PreToolUse on Write|Edit
# Purpose: inject faire-gatekeeper reminder before code write

$Input_ = [Console]::In.ReadToEnd()
$filePath = ""
try {
    $parsed = $Input_ | ConvertFrom-Json
    $filePath = $parsed.tool_input.file_path
    if (-not $filePath) { $filePath = $parsed.tool_input.path }
} catch {}

if (-not $filePath) { exit 0 }

# Skip non-code files
if ($filePath -notmatch '\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$') {
    exit 0
}

$critical = $false
if ($filePath -match '(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret)') {
    $critical = $true
}

if ($critical) {
    $msg = "CIEL [CRITIQUE] $filePath — Avant d'ecrire: (1) Invoke faire-gatekeeper skill for gate checks (2) stride-analyzer must have run for Critical tasks (3) flux-narrator completed (4) test written BEFORE (RED). Dispatch critic agent MODE=RELIRE after FAIRE is mandatory."
} else {
    $msg = "CIEL $filePath — Invoke faire-gatekeeper skill for FAIRE gates (alternatives, idiomatic, quality, removal, test-first, chunked validation). If Standard/Critical: ensure researcher + explorer agents dispatched."
}

# PreToolUse hookSpecificOutput only accepts permissionDecision fields; use
# top-level systemMessage to surface the reminder without altering permissions.
@{
    systemMessage = $msg
} | ConvertTo-Json -Compress
exit 0
