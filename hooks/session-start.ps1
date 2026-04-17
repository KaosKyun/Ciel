# Ciel — SessionStart hook (PowerShell)
# Trigger: session begins or resumes
# Purpose: print Ciel banner, load overlay context, set TRACE_ID for eval logging

$Input_ = [Console]::In.ReadToEnd()
$cwd = (Get-Location).Path
try {
    $parsed = $Input_ | ConvertFrom-Json
    if ($parsed.cwd) { $cwd = $parsed.cwd }
} catch {}

$overlay = ""
foreach ($candidate in @("$cwd/ciel-overlay.md", "$cwd/.claude/ciel-overlay.md")) {
    if (Test-Path $candidate) {
        $overlay = $candidate
        break
    }
}

$traceId = (Get-Date -Format "yyyyMMddTHHmmssZ") + "-" + $PID
$env:CIEL_TRACE_ID = $traceId

$msg = "CIEL v2.0.0 — Skills-first deep-reasoning active. "
if ($overlay) {
    $msg += "Overlay loaded: $overlay. "
} else {
    $msg += "No overlay found at $cwd/ciel-overlay.md — create one for project-specific rules. "
}
$msg += "Trace ID: $traceId. Principle: Understand before generating. Verify before claiming done."

Write-Output $msg
exit 0
