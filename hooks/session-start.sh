#!/bin/bash
# Ciel — SessionStart hook
# Never blocks (exit 0 always)

shift $# 2>/dev/null || true

OVERLAY=""
[ -f "ciel-overlay.md" ] && OVERLAY=" Overlay loaded: $(pwd)/ciel-overlay.md."
TRACE_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"

echo "CIEL v4.0.1 — Skills-first deep-reasoning active.${OVERLAY} Trace ID: ${TRACE_ID}. Principle: Understand before generating. Verify before claiming done."
exit 0
