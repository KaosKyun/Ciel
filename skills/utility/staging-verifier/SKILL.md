---
name: staging-verifier
description: Wraps correct usage of Monitor (for streaming logs) and Bash run_in_background (for one-shot waits like deploys) to capture staging evidence without the sleep+tail anti-pattern blocked by the harness. Invoked by prouver-verifier during PROUVER step.
allowed-tools: Bash
---

# staging-verifier — Correct staging evidence capture

Small utility to prevent the most common PROUVER anti-pattern: `sleep N && tail logs` blocked by the harness.

---

## Three modes — pick the right one

### Mode 1: Snapshot (last N lines)

When: you've already deployed and just need to read what happened.

```bash
journalctl -u <service> -n 50 --no-pager
```

Use **Bash** (not Monitor, not background).

### Mode 2: Stream (watch for specific event)

When: you've just triggered a scenario and want to see the log line confirming it.

```
Monitor(
  description: "staging logs after trigger",
  persistent: false,
  timeout_ms: 60000,
  command: "journalctl -u <service> -f --since now | grep --line-buffered 'KEYWORD'"
)
```

Use **Monitor** — each stdout line is a notification, harness delivers them asynchronously.

Critical: `grep --line-buffered` — without it, pipe buffering delays events minutes.

### Mode 3: One-shot wait (deploy done?)

When: long-running command that blocks until complete (deploy script, test run).

```
Bash(command="deploy-staging.sh", run_in_background=true)
```

→ Returns PID immediately. You get notified when it completes. Use `BashOutput` to retrieve output.

---

## Anti-pattern (never use)

```bash
# BLOCKED by harness — wastes tokens, unreliable
sleep 60 && tail -20 /var/log/app.log
sleep 30 && journalctl -u app -n 50
```

Why it fails:
- Harness blocks leading `sleep N &&` patterns
- Even if it ran, the sleep is arbitrary (too short → miss, too long → waste)
- No way to react to the event when it happens

---

## Process

### 1. Identify what you're checking

- Already triggered, check aftermath → **Mode 1**
- About to trigger, watch for confirmation → **Mode 2**
- Need to wait for a long-running command → **Mode 3**

### 2. Build the command

Include:
- Service / log file identification
- Filter (grep with `--line-buffered`) for the specific event
- Time bound (`--since now` to avoid historical noise)

### 3. Execute + capture

For Mode 2: until-loop pattern in Monitor:

```
Monitor(
  command: "journalctl -u app -f --since now | grep --line-buffered '[SUCCESS]'",
  timeout_ms: 60000,
  persistent: false
)
```

---

## Output format

```
## STAGING EVIDENCE CAPTURE

### Mode used
<Mode 1 | 2 | 3>

### Command
<command used>

### Evidence captured
<log excerpt / curl response / deploy exit status>

### Next action
<proceed to APRÈS verification | wait for more events>
```

---

## Guardrails

- **Never `sleep N && tail`** — harness blocks it
- **Always `grep --line-buffered`** in pipes (prevents buffering delay)
- **Time-bound Mode 2** — `timeout_ms` short (60s typical), not indefinite
- **Mode 3 for deploys** — don't Monitor a deploy, Monitor doesn't wait synchronously
- **One event at a time** — too many Monitor events get auto-killed by harness

---

## When triggered

- `prouver-verifier` during PROUVER step
- User says "check staging" / "tail the logs" / "wait for deploy"
- Any staging evidence capture
