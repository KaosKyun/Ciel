# Ciel — Stop hook (PowerShell)
# Trigger: Claude finishes responding
# Purpose: (1) block once with meta-critiquer instruction; (2) prepend release-gate reminder
# if on default branch with 3+ unreleased feat/fix commits. Single block event combines both.
# Schema: Stop rejects hookSpecificOutput.additionalContext, so we use
# {decision:"block",reason:"..."} and guard the loop via stop_hook_active.

$input_json = "{}"
if ([Console]::IsInputRedirected) {
    $raw = [Console]::In.ReadToEnd()
    if (-not [string]::IsNullOrWhiteSpace($raw)) { $input_json = $raw }
}

$active = $false
$cwd = ""
try {
    $parsed = $input_json | ConvertFrom-Json
    if ($parsed.stop_hook_active -eq $true) { $active = $true }
    if ($parsed.cwd) { $cwd = $parsed.cwd }
} catch {}

if ($active) { exit 0 }

function Check-ReleaseGate {
    param($cwd)
    if (-not $cwd) { return $null }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }

    & git -C $cwd rev-parse --git-dir 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { return $null }

    $current = (& git -C $cwd rev-parse --abbrev-ref HEAD 2>$null)
    if ($current) { $current = $current.Trim() }
    $defaultRaw = (& git -C $cwd symbolic-ref refs/remotes/origin/HEAD 2>$null)
    $default = if ($defaultRaw) { ($defaultRaw -replace '^refs/remotes/origin/', '').Trim() } else { "main" }
    if ($current -ne $default) { return $null }

    $snooze = Join-Path $cwd ".ciel-release-snooze"
    if (Test-Path $snooze) {
        $age = (Get-Date) - (Get-Item $snooze).LastWriteTime
        if ($age.TotalMinutes -lt 60) { return $null }
    }

    $lastTag = (& git -C $cwd describe --tags --abbrev=0 2>$null)
    if ($lastTag) { $lastTag = $lastTag.Trim() }
    $range = if ($lastTag) { "$lastTag..HEAD" } else { "HEAD" }

    $commits = & git -C $cwd log $range --oneline 2>$null
    if (-not $commits) { return $null }
    $pending = ($commits | Select-String -Pattern '^[a-f0-9]+ (feat|fix)(\(|:|!)').Count
    if ($pending -lt 3) { return $null }

    $tagLabel = if ($lastTag) { $lastTag } else { "<no previous tag>" }
    return @{
        Msg = "CIEL RELEASE-GATE — $pending feat/fix commit(s) on $default since $tagLabel without a release. Actions: (1) bump VERSION per conventional-commit scope (feat=minor, fix=patch, feat!/fix!=major), (2) append CHANGELOG.md entry, (3) git tag -a v<N.N.N>, (4) gh release create v<N.N.N> --generate-notes. Invoke changelog-updater + release-publisher skills. Snooze 60min: touch .ciel-release-snooze."
    }
}

$metaMsg = "CIEL STOP — 30s META-CRITIQUER obligatoire avant de declarer fini: (1) depth match? (2) new failure mode → Guard? (3) user correction → overlay/learnings? (4) stale branches? (5) uncovered issues? (6) context health? (7) session-progress.md written? (8) dead code sweep (ruff/knip/Detekt)? Invoke meta-critiquer skill then learnings-capture if corrections detected."

$rg = Check-ReleaseGate $cwd
$msg = if ($rg) { "$($rg.Msg)`n`n$metaMsg" } else { $metaMsg }

@{
    decision = "block"
    reason = $msg
} | ConvertTo-Json -Compress
exit 0
