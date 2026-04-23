---
name: staging-verifier
description: Wraps correct usage of Monitor (for streaming logs) and Bash run_in_background (for one-shot waits like deploys) to capture staging evidence without the sleep+tail anti-pattern. Invoked by prouver-verifier during PROUVER step.
allowed-tools: Bash
---

# staging-verifier — Correct staging evidence capture

## What this covers
Prevents the most common PROUVER anti-pattern: `sleep N && tail logs` blocked by the harness. Uses the right tool for the right scenario.

## Core principle
**Never sleep-and-poll.** Use Monitor for streaming events, Bash background for one-shot waits. The harness delivers events asynchronously — trust it.

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

→ Returns PID immediately. You get notified when it completes.

## Common patterns

### Good evidence capture

```bash
# Snapshot — just read the logs
journalctl -u myapp -n 50 --no-pager | grep "ERROR"

# Stream — watch for deploy confirmation
Monitor(
  description: "deploy confirmation",
  persistent: false,
  timeout_ms: 120000,
  command: "journalctl -u myapp -f --since now | grep --line-buffered 'deploy.*complete\\|deploy.*failed'"
)

# Background — wait for long deploy
Bash(command="./deploy-staging.sh", run_in_background=true)
```

### Bad evidence capture (BLOCKED)

```bash
# BLOCKED by harness — wastes tokens, unreliable
sleep 60 && tail -20 /var/log/app.log
sleep 30 && journalctl -u app -n 50
```

Why it fails:
- Harness blocks leading `sleep N &&` patterns
- Even if it ran, the sleep is arbitrary (too short → miss, too long → waste)
- No way to react to the event when it happens

## Anti-patterns

- **`sleep N && tail`** — harness blocks it. Use Monitor or background instead.
- **Monitor for deploys** — Monitor doesn't wait synchronously. Use `run_in_background` for deploys.
- **No `grep --line-buffered`** — pipe buffering delays events by minutes
- **Indefinite Monitor** — always set `timeout_ms` (60s typical)
- **Too many Monitors** — auto-killed by harness. One event at a time.

## How to verify

- [ ] Mode correctly chosen? (Snapshot for aftermath, Stream for confirmation, Background for long-running)
- [ ] `grep --line-buffered` in all pipe-based commands?
- [ ] `timeout_ms` set for Monitor? (not indefinite)
- [ ] No `sleep N &&` patterns? (harness blocks them)
- [ ] Evidence captured is concrete (log line, exit status, curl output)?

## When triggered

- `prouver-verifier` during PROUVER step
- User says "check staging" / "tail the logs" / "wait for deploy"
- Any staging evidence capture
