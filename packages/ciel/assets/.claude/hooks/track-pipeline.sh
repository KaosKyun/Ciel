#!/bin/bash
# Ciel — Pipeline state tracker (PostToolUse hook)
# Trigger: after Skill() or Agent() tool use
# Purpose: record pipeline step completion in .ciel/pipeline-state.json
# Never blocks (exit 0 always)

INPUT=$(cat 2>/dev/null || echo "{}")
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except:
    print('')
" 2>/dev/null || echo "")

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
[ -z "$PROJECT_DIR" ] && exit 0
[ -z "$TOOL_NAME" ] && exit 0

STATE_FILE="$PROJECT_DIR/.ciel/pipeline-state.json"
mkdir -p "$PROJECT_DIR/.ciel" 2>/dev/null || true

STEP=""
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [ "$TOOL_NAME" = "Skill" ]; then
  SKILL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('skill', ''))
except:
    print('')
" 2>/dev/null || echo "")

  case "$SKILL_NAME" in
    depth-classifier)     STEP="DOCS" ;;
    quoi-framer)          STEP="QUOI" ;;
    ask-window)           STEP="ASK" ;;
    avec-quoi-versioner)  STEP="AVEC QUOI" ;;
    diverge)              STEP="DIVERGE" ;;
    stride-analyzer)      STEP="SECURITE" ;;
    evaluer-sizer)        STEP="EVALUER" ;;
    faire-gatekeeper)     STEP="FAIRE" ;;
    adr-auto)             STEP="ADR" ;;
    relire-critic)        STEP="RELIRE" ;;
    prouver-verifier)     STEP="PROUVER" ;;
    memoire)              STEP="MEMOIRE" ;;
    savoir-compiler)      STEP="COMPILER" ;;
    meta-critiquer)       STEP="META" ;;
  esac
elif [ "$TOOL_NAME" = "Agent" ]; then
  SUBAGENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('subagent_type', ''))
except:
    print('')
" 2>/dev/null || echo "")

  case "$SUBAGENT" in
    ciel-researcher)  STEP="RECHERCHE" ;;
    ciel-explorer)    STEP="CODEBASE" ;;
  esac
fi

[ -z "$STEP" ] && exit 0

# Write pipeline state via python heredoc — avoids -c quoting fragility
export STATE_FILE STEP NOW
python3 << 'PYEOF'
import json, os, sys

state_file = os.environ.get('STATE_FILE', '')
step = os.environ.get('STEP', '')
now = os.environ.get('NOW', '')

if not state_file or not step:
    sys.exit(0)

state = {}
if os.path.exists(state_file):
    try:
        with open(state_file) as f:
            state = json.load(f)
    except Exception:
        pass

if 'steps' not in state:
    state['steps'] = {}

# DOCS call means new task — reset but preserve MEMOIRE/COMPILER/META
if step == 'DOCS' and state.get('current_step') != 'DOCS':
    old_steps = state.get('steps', {})
    state['steps'] = {}
    for s in ['MEMOIRE', 'COMPILER', 'META']:
        if s in old_steps:
            state['steps'][s] = old_steps[s]
    state['task_started_at'] = now

state['steps'][step] = {'status': 'done', 'at': now}
state['current_step'] = step
state['updated_at'] = now

with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)
PYEOF

# Compact progress line to stderr (visible in CLI)
export STATE_FILE
python3 << 'PYEOF'
import json, os, sys

state_file = os.environ.get('STATE_FILE', '')
if not state_file or not os.path.exists(state_file):
    sys.exit(0)

with open(state_file) as f:
    state = json.load(f)

steps = state.get('steps', {})
pipeline_order = [
    'DOCS', 'QUOI', 'ASK', 'AVEC QUOI', 'DIVERGE',
    'RECHERCHE', 'SECURITE', 'CODEBASE', 'EVALUER', 'ASK2',
    'FAIRE', 'TESTER', 'ADR', 'RELIRE', 'PROUVER',
    'MEMOIRE', 'COMPILER', 'META'
]

done = [s for s in pipeline_order if s in steps and steps[s].get('status') == 'done']
done_count = len(done)
total = len(pipeline_order)
current = state.get('current_step', '?')

display = []
show = done[-5:] if len(done) > 5 else done[:]
for s in show:
    display.append(s)
if current and current not in done:
    display.append('●' + current)

line = ' → '.join(display)
print(f'[CIEL] {line} ({done_count}/{total})', file=sys.stderr)
PYEOF

exit 0
