# Ciel — PostToolUse hook for Bash|Read|Grep|Glob|Task (PowerShell)
# Parity with post-tool-count.sh — see that file for design notes.

$Input_ = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($Input_)) { exit 0 }

$sessionId = ""
$toolName = ""
try {
    $parsed = $Input_ | ConvertFrom-Json
    $sessionId = $parsed.session_id
    $toolName = $parsed.tool_name
} catch {}

if ([string]::IsNullOrWhiteSpace($sessionId)) { exit 0 }

$tmp = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$counterFile = Join-Path $tmp "ciel-counter-$sessionId"

if ($toolName -eq "Task") {
    Remove-Item $counterFile -ErrorAction SilentlyContinue
    exit 0
}

$count = 0
if (Test-Path $counterFile) {
    $raw = Get-Content $counterFile -ErrorAction SilentlyContinue
    if ($raw -match '^\d+$') { $count = [int]$raw }
}
($count + 1) | Set-Content -NoNewline $counterFile
exit 0
