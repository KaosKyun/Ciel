# Ciel — Stop hook (PowerShell)
# Trigger: Claude finishes responding
# Purpose: block once with meta-critiquer instruction; re-entry lets stop proceed.
# Schema: Stop rejects hookSpecificOutput.additionalContext, so we use
# {decision:"block",reason:"..."} and guard the loop via stop_hook_active.

$input_json = "{}"
if ([Console]::IsInputRedirected) {
    $raw = [Console]::In.ReadToEnd()
    if (-not [string]::IsNullOrWhiteSpace($raw)) { $input_json = $raw }
}

$active = $false
try {
    $parsed = $input_json | ConvertFrom-Json
    if ($parsed.stop_hook_active -eq $true) { $active = $true }
} catch {}

if ($active) { exit 0 }

$msg = "CIEL STOP — 30s META-CRITIQUER obligatoire avant de declarer fini: (1) depth match? (2) new failure mode → Guard? (3) user correction → overlay/learnings? (4) stale branches? (5) uncovered issues? (6) context health? (7) session-progress.md written? (8) dead code sweep (ruff/knip/Detekt)? Invoke meta-critiquer skill then learnings-capture if corrections detected."

@{
    decision = "block"
    reason = $msg
} | ConvertTo-Json -Compress
exit 0
