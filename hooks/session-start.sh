#!/bin/bash
# Ciel — SessionStart hook
# Never blocks (exit 0 always)

# Ignore all arguments (Claude passes session metadata as args)
shift $# 2>/dev/null || true

echo "CIEL v3.5.0 — Deep-reasoning active. Principle: Understand before generating. Verify before claiming done."
exit 0
