# Ciel — SubagentStop hook (PowerShell)
# Trigger: subagent finishes
# Purpose: log agent report size; warn on truncation

$Input_ = [Console]::In.ReadToEnd()
$agent = "unknown"
$resultLen = 0
try {
    $parsed = $Input_ | ConvertFrom-Json
    $agent = $parsed.agent_type
    if (-not $agent) { $agent = $parsed.subagent_type }
    if (-not $agent) { $agent = "unknown" }
    $result = $parsed.result
    if (-not $result) { $result = $parsed.output }
    if ($result) { $resultLen = ($result -split '\s+').Count }
} catch {}

$tokens = [int]($resultLen * 1.33)

if ($env:CIEL_TRACE_ID) {
    $logDir = "$env:USERPROFILE/.claude/plugins/ciel/evals/results"
    New-Item -ItemType Directory -Force -Path $logDir -ErrorAction SilentlyContinue | Out-Null
    $entry = @{
        trace_id = $env:CIEL_TRACE_ID
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        agent = $agent
        tokens = $tokens
    } | ConvertTo-Json -Compress
    Add-Content -Path "$logDir/subagent-stops.jsonl" -Value $entry
}

if ($tokens -lt 200 -and $tokens -gt 0) {
    Write-Error "CIEL WARN — $agent agent report is only $tokens tokens. Suspect truncation on Standard/Critical task."
}

exit 0
