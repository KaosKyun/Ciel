# skill-variant-evaluator — Reference

## Eval dataset format (JSONL)

One JSON object per line:

```json
{"id": "research-gate-001", "input": {"task": "add pagination to user list", "lib": "ktor", "version": "3.0.0", "overlay": "..."}, "expected_behavior": {"has_finding": true, "has_anti_pattern": true, "has_philosophy": true, "has_version_stamp": true, "output_under_500_tokens": true}, "skill": "research-web-sources"}
```

Required fields:
- `id`: unique identifier within dataset
- `input`: object passed to the skill (typically the user prompt or dispatch block)
- `expected_behavior`: object mapping criterion name → boolean (what the skill MUST produce)
- `skill`: skill name this dataset targets

Optional:
- `tags`: array for filtering
- `weight`: float multiplier for aggregate scoring (default 1.0)

## Criterion evaluators

Each criterion name maps to a simple check function. Current supported:

| Criterion | Check |
|-----------|-------|
| `has_finding` | Output contains "## FINDINGS" with at least 1 bullet |
| `has_anti_pattern` | Output contains "ANTI-PATTERN" with at least 1 entry |
| `has_philosophy` | Output contains "PHILOSOPHY" section |
| `has_version_stamp` | Output contains at least one version number (regex `\d+\.\d+(\.\d+)?`) |
| `has_uncertainties_flagged` | Output contains "## INCERTITUDES" non-empty |
| `output_under_N_tokens` | Output token count ≤ N |
| `triggered_skill` | Skill invocation log present (check from subagent-stop hook output) |
| `has_3_risques` | Output contains exactly 3 RISQUE entries |
| `has_stride_6` | Output mentions all 6 STRIDE categories |
| `has_mini_repo_map` | Output contains "## MINI REPO-MAP" with signatures + dependents |
| `has_flux_narration` | Output contains "When ... → ... → ..." pattern |
| `has_avant_apres` | Output contains both "AVANT" and "APRÈS" sections |
| `depth_match` | Output depth classification matches dataset's expected depth |

Custom criteria can be added by extending `evals/runners/scoring.sh`.

## Headless execution via claude --print

Example command (all flags):

```bash
claude --print \
  --plugin-dir /home/user/Ciel \
  --allowed-tools "Read Grep Glob WebSearch WebFetch Bash" \
  --model claude-opus-4-7 \
  --disallowed-tools "Write Edit NotebookEdit" \
  --max-turns 10 \
  "<prompt>"
```

- `--print` = headless, non-interactive, exits after response
- `--plugin-dir` = local plugin root for testing (instead of installed version)
- `--max-turns` = cap tool-use turns to prevent runaway loops
- `--disallowed-tools` = explicitly forbid modification (read-only eval)

Stdout contains the final response. Stderr contains trace logs. Exit code: 0 on success, 1 on max-turns reached, 2 on API error.

**Known limitation**: `claude --print` headless behavior is not officially documented for CI. Behavior may change. Fallback: manual evals via interactive session + results captured by user.

## Variant file structure

Variants are temp files:

```
skills/workflow/flux-narrator/
├── SKILL.md                        ← current (Variant A baseline)
├── reference.md
├── variants/                       ← variants storage (optional)
│   ├── tightened.md                ← Variant B candidate
│   └── reduced.md                  ← Variant C candidate
├── SKILL.md.eval.A                 ← temp: copy of baseline during eval
├── SKILL.md.eval.B                 ← temp: Variant B content
└── SKILL.md.eval.C                 ← temp: Variant C content
```

During evaluation, the evaluator temporarily replaces SKILL.md with each variant (via symlink or copy), runs the eval, then restores.

## Results schema

```json
{
  "skill": "<skill-name>",
  "skill_path": "<path-to-SKILL.md>",
  "timestamp": "<ISO 8601>",
  "ciel_version": "<git SHA>",
  "dataset": "<dataset path>",
  "dataset_entries": <int>,
  "variants": [
    {
      "letter": "A",
      "source": "baseline" | "provided" | "variants/<name>.md",
      "content_hash": "<sha256>",
      "per_entry_scores": [
        {"id": "research-gate-001", "criteria_passed": 4, "criteria_total": 5, "score": 0.8, "tokens": 15000, "duration_ms": 13000}
      ],
      "aggregate_score": 0.72,
      "total_tokens": 290000,
      "total_duration_ms": 265000
    }
  ],
  "winner": "B",
  "winner_reason": "highest_score" | "tiebreak_tokens" | "tiebreak_specificity"
}
```

## Aggregate scoring formula

```
aggregate_score = Σ(weight_i × score_i) / Σ(weight_i)
```

Where weight defaults to 1.0 per entry unless specified in dataset.

## When headless mode unavailable

If `claude --print` exits with error or is not installed:

1. Output the full list of eval prompts as a markdown doc: `evals/manual/<skill>-<timestamp>.md`
2. User runs each prompt manually in a fresh session, captures output to `evals/manual/<skill>-<timestamp>/<variant>-<entry-id>.md`
3. User runs `scripts/run-evals.sh --score evals/manual/<skill>-<timestamp>/` to compute scores from manual outputs
4. Results persisted normally

## Cost estimation

Before running, estimate:

```
cost_tokens = num_variants × num_dataset_entries × avg_response_tokens
```

Where `avg_response_tokens` defaults to 15,000 (pessimistic for skill output).

Thresholds:
- < 100k tokens: proceed silently
- 100k–500k: inform user, proceed
- > 500k: require user confirmation ("This eval will cost ~<X>k tokens. Continue? [y/n]")

## Anti-patterns in eval design

- **Single-criterion evals**: if the dataset has only 1 criterion per entry, winner is binary (pass/fail) — noisier scores. Prefer 3-5 criteria per entry.
- **Trivial criteria**: "output not empty" is useless. Every criterion should catch a real failure mode.
- **Overfit to baseline**: if you design criteria by inspecting baseline output, your baseline will always "win". Design criteria from the spec, not from output.
- **Dataset drift**: skills evolve; datasets don't. Revisit datasets every CHANGELOG version bump.
