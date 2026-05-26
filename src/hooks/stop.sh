#!/bin/bash

# CIEL-DEFER-GUARD — a global plugin instance no-ops when the project ships AND
# wires its own copy of this hook. Paths are canonicalized (pwd -P) on BOTH sides
# so a symlinked or trailing-slash CLAUDE_PROJECT_DIR cannot make the project's
# own instance wrongly defer (which would disable Ciel entirely in the project).
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  _ciel_name="$(basename "${BASH_SOURCE[0]}")"
  _ciel_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
  _ciel_proj="$(cd "$CLAUDE_PROJECT_DIR/.claude/hooks" 2>/dev/null && pwd -P)"
  if [ -n "$_ciel_proj" ] && [ -f "$_ciel_proj/$_ciel_name" ] && [ "$_ciel_self" != "$_ciel_proj" ]; then
    exit 0
  fi
fi
# Ciel v9 — Stop hook
# Two jobs, one block:
#   1) Verification gate (autonomy keystone): if source code was edited this
#      session with no test run since, demand verification before "done".
#   2) META reflection (always): 3 questions before declaring finished.
# Blocks at most once per stop cycle (respects stop_hook_active to avoid loops).

INPUT=$(cat 2>/dev/null || echo "{}")

ACTIVE=$(python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    print('true' if d.get('stop_hook_active', False) else 'false')
except:
    print('false')
" "$INPUT" 2>/dev/null || echo "false")

[ "$ACTIVE" = "true" ] && exit 0

# ─── Verification gate ────────────────────────────────────────────────────
# .ciel/last-code-edit newer than .ciel/last-verification (or no verification at
# all) ⇒ code changed without a test run since. -nt is true when the left file
# exists and the right is older or missing; false when the left is missing.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
VERIF_MSG=""
if [ -n "$PROJECT_DIR" ] && [ "$PROJECT_DIR/.ciel/last-code-edit" -nt "$PROJECT_DIR/.ciel/last-verification" ]; then
  VERIF_MSG="VERIFICATION GATE — du code a ete modifie sans preuve d'execution des tests depuis. Lance la suite (npm test / pytest / go test...) et OBSERVE un signal POSITIF avant de declarer fini. Regle dure #4 : 'pas d'erreur dans les logs' n'est PAS une preuve. Si aucun test n'est applicable, dis-le explicitement.

"
fi

META_MSG="${VERIF_MSG}CIEL — 30s META reflection avant de declarer fini:
1. Qu'ai-je manque que l'utilisateur va me demander ensuite ?
2. Quelle decision ou decouverte merite d'etre sauvegardee en memoire ?
3. Si je devais refaire cette tache, que ferais-je differemment ?"

python3 -c "
import json, sys
print(json.dumps({'decision': 'block', 'reason': sys.argv[1]}))
" "$META_MSG"

exit 0
