#!/bin/bash
# Ciel v9 — Stop hook
# Injects 3 META reflection questions via decision:block.
# Never blocks more than once per session.

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

META_MSG="CIEL — 30s META reflection avant de declarer fini:
1. Qu'ai-je manque que l'utilisateur va me demander ensuite ?
2. Quelle decision ou decouverte merite d'etre sauvegardee en memoire ?
3. Si je devais refaire cette tache, que ferais-je differemment ?"

python3 -c "
import json, sys
print(json.dumps({'decision': 'block', 'reason': sys.argv[1]}))
" "$META_MSG"

exit 0
