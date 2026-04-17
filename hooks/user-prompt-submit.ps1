# Ciel — UserPromptSubmit hook (PowerShell)
# Trigger: user submits a prompt (before Claude processes)
# Purpose: light depth pre-classification hint

$Input_ = [Console]::In.ReadToEnd()
$prompt = ""
try {
    $parsed = $Input_ | ConvertFrom-Json
    $prompt = $parsed.prompt
} catch {}

if (-not $prompt) { exit 0 }

$depth = "Standard"
$reason = ""

if ($prompt -match '\b(auth|authenti|author|jwt|oauth|password|secret|token|session|payment|credit.card|migration.*schema|2fa|mfa|encryption|credential)\b') {
    $depth = "Critical"
    $reason = "auth/security/payment keyword detected"
} elseif ($prompt -match '\b(rename|typo|copyright|comment|readme|1-line|one.line|fix.typo|spelling)\b') {
    $depth = "Trivial"
    $reason = "rename/typo/docs keyword detected"
}

$msg = "CIEL depth hint: $depth ($reason). Invoke depth-classifier if ambiguous before routing pipeline."

@{
    hookSpecificOutput = @{
        hookEventName = "UserPromptSubmit"
        additionalContext = $msg
    }
} | ConvertTo-Json -Compress
exit 0
