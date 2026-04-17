# Ciel — PreToolUse hook for Bash|Read|Grep|Glob (PowerShell)
# Parity with pre-tool-count.sh — see that file for design notes.

$Input_ = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($Input_)) { exit 0 }

$sessionId = ""
try {
    $parsed = $Input_ | ConvertFrom-Json
    $sessionId = $parsed.session_id
} catch {}

if ([string]::IsNullOrWhiteSpace($sessionId)) { exit 0 }

$tmp = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$counterFile = Join-Path $tmp "ciel-counter-$sessionId"

$count = 0
if (Test-Path $counterFile) {
    $raw = Get-Content $counterFile -ErrorAction SilentlyContinue
    if ($raw -match '^\d+$') { $count = [int]$raw }
}

if ($count -ge 5) {
    @{
        hookSpecificOutput = @{
            hookEventName = "PreToolUse"
            permissionDecision = "deny"
            permissionDecisionReason = "[CIEL HARD-STOP] Dispatch gate exceeded ($count inline calls without a Task() on a Standard+ task). Emit Task(subagent_type=`"ciel-researcher`"|`"ciel-explorer`"|`"ciel-critic`") now with [ASSUMED] markers for unresolved inputs. Further investigation belongs INSIDE the fork, not in the main session."
        }
    } | ConvertTo-Json -Compress -Depth 5
    exit 0
}

$next = $count + 1
@{
    systemMessage = "[CIEL COUNTER: $next/5] inline Bash/Read/Grep/Glob call — on 5/5 the next non-Task tool call will be hard-stopped. Dispatch Task() now if input-gathering is complete."
} | ConvertTo-Json -Compress
exit 0
