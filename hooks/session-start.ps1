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

$msg = "CIEL v2.2.0 — Skills-first deep-reasoning active. "
if ($overlay) {
    $msg += "Overlay loaded: $overlay. "
} else {
    $msg += "No overlay found at $cwd/ciel-overlay.md — create one for project-specific rules. "
}
$msg += "Trace ID: $traceId. Principle: Understand before generating. Verify before claiming done."

# Update check (throttled 24h, non-blocking max 2s, silent on failure)
$manifest = Join-Path $HOME ".ciel/manifest.json"
$lastCheck = Join-Path $HOME ".ciel/.last-update-check"
if (Test-Path $manifest) {
    $stale = $true
    if (Test-Path $lastCheck) {
        $age = (Get-Date) - (Get-Item $lastCheck).LastWriteTime
        if ($age.TotalMinutes -le 1440) { $stale = $false }
    }
    if ($stale) {
        try {
            $local = (Get-Content $manifest -Raw | ConvertFrom-Json).version
            $remote = (Invoke-WebRequest `
                -Uri "https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION" `
                -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop).Content.Trim()
            if ($local -and $remote -and $local -ne $remote) {
                $msg += " [UPDATE] Ciel v$local -> v$remote available. Run /ciel-update."
            }
        } catch {}
        New-Item -ItemType Directory -Path (Split-Path $lastCheck) -Force -ErrorAction SilentlyContinue | Out-Null
        New-Item -ItemType File -Path $lastCheck -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

Write-Output $msg
exit 0
