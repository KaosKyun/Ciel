---
name: cicd-pipeline-designer
description: Designs and generates a professional CI/CD pipeline from scratch — detects project type (Node/Go/Python/Kotlin/Rust), infers deployment target, picks build matrix, caching keys, OIDC secret federation, test pyramid jobs, deployment strategy (rolling/canary/blue-green), preview environments, observability hooks. Writes YAML to `.github/workflows/` (or equivalent). Invoke on "create CI/CD", "set up pipeline", "add GitHub Actions", greenfield project without workflows, or CI/CD platform migration. Pairs with cicd-security-hardener (audit). Inline.
allowed-tools: Read, Grep, Glob, Bash, Write
context: inline
---

# cicd-pipeline-designer — Professional CI/CD from scratch

`cicd-security-hardener` audits existing workflows against SLSA L3. This skill GENERATES them from project signals + 2026 best practices. Together they cover both sides of the CI/CD capability.

Principle: **infer from the project, don't ask the user to decide what the project already declares.**

---

## Inputs

```
PROJECT_TYPE: [node | go | python | kotlin | rust | polyglot — auto-detect]
DEPLOYMENT_TARGET: [kubernetes | serverless | vps | edge | static | docker-registry | library]
PLATFORM: [github-actions | gitlab-ci | circleci — default: github-actions]
RISK_PROFILE: [low | medium | high — low=recreate, medium=rolling, high=canary/blue-green]
COMPLIANCE: [none | soc2 | hipaa | pci — affects signing, audit trail, approval gates]
MONOREPO: [auto-detect turbo.json | pnpm-workspace.yaml | nx.json | rush.json | go work]
```

### Auto-inference sources

- **PROJECT_TYPE** → `package.json` → node, `go.mod` → go, `pyproject.toml`/`requirements.txt` → python, `build.gradle*`/`pom.xml` → kotlin/java, `Cargo.toml` → rust, multiple → polyglot.
- **DEPLOYMENT_TARGET** → `k8s/` or `helm/` → kubernetes; `serverless.yml`/`sam.yml` → serverless; `netlify.toml`/`vercel.json` → edge; `fly.toml` → containerized-edge; `Dockerfile` only + no deploy config → docker-registry; published package → library (tag-driven release, no deploy).
- **PLATFORM** → presence of `.github/` → github-actions; `.gitlab-ci.yml` → gitlab-ci; `.circleci/` → circleci.
- **RISK_PROFILE** → default `low` for libraries / static sites, `medium` for typical services, `high` when `auth/`, `payment/`, `data/` directories exist.
- **COMPLIANCE** → `SECURITY.md` mentions SOC2/HIPAA/PCI → set; else `none`.
- **MONOREPO** → glob match on workspace manifests above.

---

## Preflight

```bash
# Writing permission to .github/workflows/
mkdir -p .github/workflows 2>/dev/null
[ -w .github/workflows ] || { echo "Cannot write .github/workflows/"; exit 1; }

# Existing workflows → backup before overwrite
for f in .github/workflows/*.yml .github/workflows/*.yaml; do
  [ -f "$f" ] && cp "$f" "$f.bak.$(date +%s)"
done

# Test script exists + runs (sanity)
case "$PROJECT_TYPE" in
  node) jq -e '.scripts.test' package.json >/dev/null || echo "WARN: no npm test script" ;;
  go) test -n "$(find . -name '*_test.go' -not -path './vendor/*' | head -1)" || echo "WARN: no _test.go files" ;;
  python) test -f pyproject.toml && grep -qE 'pytest|ruff' pyproject.toml || echo "WARN: no pytest config" ;;
esac

# gh CLI (optional — for post-write verification)
command -v gh && gh auth status 2>&1 | grep -q "Logged in"
```

---

## Process

### 1. Detect project shape

```bash
# Manifest discovery
find . -maxdepth 3 \( -name package.json -o -name go.mod -o -name pyproject.toml \
  -o -name Cargo.toml -o -name build.gradle.kts -o -name pom.xml \) -not -path ./node_modules/*
```

Extract:
- Language version (engines.node, go.mod toolchain, python_requires, rustc edition, jvmTarget)
- Test runner (jest/vitest/go test/pytest/cargo test/gradle test)
- Build tool (vite/webpack/tsc, go build, setuptools/poetry, cargo, gradle)
- Lint/format tools (eslint/biome, golangci-lint, ruff, clippy, ktlint)
- Deployment artifacts (Dockerfile, Procfile, serverless.yml)

### 2. Infer build matrix

| Project | Matrix dimensions (default) |
|---|---|
| node | OS: ubuntu-latest; node: current engines.node + previous LTS |
| go | OS: ubuntu-latest (+ macOS, Windows if public lib); go: toolchain version |
| python | OS: ubuntu-latest (+ macOS if public lib); python: `python_requires` range |
| kotlin | OS: ubuntu-latest; jdk: 17 + 21 (if public lib); else jdk: target only |
| rust | OS: ubuntu-latest (+ macOS, Windows if public lib); rust: stable + MSRV |
| library | All supported OSes + all supported versions (cartesian) |
| service | Single OS + single version (deploy-pinned) |

Minimize matrix for services (faster CI), maximize for libraries (broad compat).

### 3. Select test pyramid jobs

| Level | Trigger | Blocking? |
|---|---|---|
| lint + typecheck | every push | yes |
| unit | every push | yes |
| integration (if docker-compose / test DB detected) | every push | yes |
| e2e (if playwright/cypress detected) | PR against main + nightly | yes on PR, alert on nightly |
| load tests (if k6/artillery detected) | weekly + manual | no |
| accessibility (if `accessibility-wcag-auditor` relevant) | PR on frontend changes | yes |

### 4. Apply 2026 core recipes

**Always included** (see `reference.md` for details):

1. **SHA-pinned actions** — `uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2` (tools: [pin-github-action], [Renovate])
2. **Minimum permissions** — `permissions: contents: read` at workflow top; escalate per job.
3. **Concurrency** — `concurrency: group: ${{ github.workflow }}-${{ github.ref }}; cancel-in-progress: ${{ github.event_name == 'pull_request' }}`
4. **Caching** — `actions/cache@v4` keyed on lockfile hash:
   - node: `~/.npm` keyed on `hashFiles('**/package-lock.json')`
   - go: `~/go/pkg/mod` + `~/.cache/go-build` keyed on `hashFiles('**/go.sum')`
   - python: `~/.cache/pip` + `.venv` keyed on `hashFiles('**/poetry.lock', '**/requirements*.txt')`
   - rust: `~/.cargo`, `target/` keyed on `hashFiles('**/Cargo.lock')`
5. **Timeout** — every job has `timeout-minutes: 10` (adjust per job reality)
6. **OIDC federation** — no long-lived cloud secrets (AWS/GCP/Azure):
   - `permissions: id-token: write` on deploy jobs
   - `aws-actions/configure-aws-credentials@v4` with `role-to-assume`
7. **fail-fast: false** in matrix — see all OS/version failures at once
8. **Artifact upload** — test reports, coverage, SBOM → `actions/upload-artifact@v4` with short retention (7 days PR, 90 days main)

### 5. Apply deployment strategy

Decide from RISK_PROFILE × DEPLOYMENT_TARGET:

| Risk | Target | Strategy | Mechanism |
|---|---|---|---|
| low | static/edge | recreate | Netlify/Vercel deploy action |
| low | library | tag-driven release | `release-publisher` handoff |
| medium | kubernetes | rolling | `kubectl rollout restart` with readiness probes |
| medium | serverless | immediate (versioned) | AWS SAM / Serverless Framework with aliases |
| high | kubernetes | canary (10% → 50% → 100% over 15min) | Argo Rollouts / Flagger |
| high | kubernetes | blue-green | two services, DNS switch |
| high | serverless | weighted alias | AWS Lambda weighted alias 10→100 over 15min |

Add post-deploy health check as the last step. On fail → auto-rollback (`kubectl rollout undo` or alias swap).

### 6. Add preview environments (PR workflow)

If deployment target supports it:

- **Vercel/Netlify/Cloudflare Pages**: built-in PR preview — add the provider's action.
- **Fly.io**: `flyctl deploy --app <base>-pr-${{ github.event.number }}` + tear-down on `closed`.
- **Docker Compose** (any): spin up on PR-labeled runner with `docker compose up -d`, post URL as PR comment, tear down on close.

Preview URLs post to PR via `actions/github-script@v7` with a sticky comment.

### 7. Observability hooks

Emit on every deploy:

- Structured log line (JSON) with commit SHA, actor, environment, duration
- Datadog/Sentry release creation (`sentry/action-release` or `DataDog/datadog-ci`)
- Metric: `deploy.count{env=production,status=success|failure}`
- Slack/Discord webhook on failure only (don't spam on success)

### 8. Write workflow files

Default file layout:

```
.github/workflows/
├── ci.yml          # lint + typecheck + unit + integration
├── build.yml       # build + SBOM + sign (needs: ci)
├── e2e.yml         # e2e (PR only, needs: build)
├── deploy-staging.yml  # auto on main (needs: ci, build)
├── deploy-production.yml  # manual or on tag (needs: deploy-staging)
├── release.yml     # on tag v* (handoff to release-publisher)
└── scheduled.yml   # nightly: full e2e + security scan + perf regression
```

For simple projects, consolidate into `ci.yml` + `deploy.yml`.

Use `Write` tool to emit each YAML file. Start from the core recipes + project-specific matrix.

### 9. Align branch protection

After writing, emit recommended branch protection config for `main`:

```
[BRANCH PROTECTION — suggested]
Required status checks:
  - ci / lint-typecheck
  - ci / unit
  - ci / integration
  - build / build-sign
  - e2e / playwright (if PR)
Required reviews: 1 (RISK_PROFILE=medium), 2 (high)
CODEOWNERS required: yes (COMPLIANCE != none)
Dismiss stale reviews on new commit: yes
Require conversation resolution: yes (pairs with pr-review-responder)
```

Also apply via `gh api repos/{owner}/{repo}/branches/main/protection` if user consents.

### 10. Emit report + handoff

```
[CI/CD PIPELINE DESIGNED]
Platform: github-actions
Project: node (pnpm, vitest, playwright)
Deployment: kubernetes, risk=medium → rolling
Files written:
  .github/workflows/ci.yml (4 jobs, est 3-5 min)
  .github/workflows/build.yml (2 jobs, SBOM + cosign)
  .github/workflows/e2e.yml (1 job, matrix 3 browsers)
  .github/workflows/deploy-staging.yml (+ health check + rollback)
  .github/workflows/deploy-production.yml (manual approval gate)
  .github/workflows/release.yml (on tag)

Secrets required (OIDC — zero long-lived):
  AWS_ROLE_ARN (repository secret, not token)

Branch protection: applied via gh api / manual config URL

Handoff:
  → cicd-security-hardener — audit the generated workflows (catches gaps)
  → accessibility-wcag-auditor — if frontend project
  → Update README "Status: ![CI](...badge)"
```

---

## Embedded core templates (abbreviated)

Full templates live in `reference.md`. Below are the minimal node + go examples.

### node — ci.yml (pnpm + vitest)

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
jobs:
  lint-typecheck:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: pnpm/action-setup@fe02b34f77f8bc703788d5817da081398fad5dd2 # v4.0.0
      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af # v4.1.0
        with:
          node-version-file: '.nvmrc'
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint
      - run: pnpm typecheck
  unit:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: pnpm/action-setup@fe02b34f77f8bc703788d5817da081398fad5dd2 # v4.0.0
      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af # v4.1.0
        with:
          node-version-file: '.nvmrc'
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm test:unit --reporter=junit --outputFile=junit.xml
      - uses: actions/upload-artifact@b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882 # v4.4.3
        if: always()
        with:
          name: junit
          path: junit.xml
          retention-days: 7
```

### go — ci.yml

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
jobs:
  lint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: actions/setup-go@41dfa10bad2bb2ae585af6ee5bb4d7d973ad74ed # v5.1.0
        with:
          go-version-file: go.mod
          cache: true
      - uses: golangci/golangci-lint-action@2e788936b09dd82dc280e845628a40d2ba6b204c # v6.3.0
        with:
          version: v1.61.0
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: actions/setup-go@41dfa10bad2bb2ae585af6ee5bb4d7d973ad74ed # v5.1.0
        with:
          go-version-file: go.mod
          cache: true
      - run: go test -race -coverprofile=cover.out ./...
      - uses: actions/upload-artifact@b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882 # v4.4.3
        with:
          name: coverage
          path: cover.out
          retention-days: 7
```

Python, Kotlin, Rust templates in `reference.md`.

---

## Guardrails

- **Never emit plaintext secrets** — always `${{ secrets.X }}`.
- **Never use floating tags** (`@v1`, `@main`) — pin to SHA with version comment. Tools: `pin-github-action`, Renovate auto-updates SHAs.
- **Never set `permissions:` above minimum needed** — default `contents: read`, add per-job as required.
- **Never enable `pull_request_target`** unless absolutely necessary + gated by `if: github.actor == ...` + reviewed.
- **Never skip tests via `continue-on-error: true`** — if a test is flaky, tag it, don't silence it.
- **Always set `timeout-minutes`** — default 10, adjust per job.
- **Always include `concurrency.cancel-in-progress` on PR workflows** — stale runs waste CI.
- **Deployment must have post-deploy health check** — else a broken deploy sits unnoticed.
- **No long-lived cloud tokens** when OIDC federation is available (AWS, GCP, Azure, Vault all support it).
- **Matrix `fail-fast: false`** — developer needs full signal, not first-failure-only.
- **Do NOT generate workflows that bypass branch protection** — `--admin` or `pull_request_target` without gate is a security hole.
- **COMPLIANCE=soc2/hipaa/pci** → require approval gate on production deploy; enforce SBOM + Sigstore attestations (handoff `cicd-security-hardener`).

---

## When triggered

- User says: "create CI/CD", "set up pipeline", "add GitHub Actions", "bootstrap CI", "CI/CD for this project"
- Greenfield project without `.github/workflows/` or equivalent
- CI/CD platform migration (GitLab → GitHub, CircleCI → Actions, etc.)
- After `branch-setup` on a repo with no CI detected

---

## Anti-pattern

```
❌ Copied StackOverflow YAML
   - actions/checkout@v2 (EOL, no SHA pin)
   - hardcoded AWS_ACCESS_KEY_ID in env
   - no caching → 8 min install on every PR
   - no permissions: default = all → security risk
   - one giant job (lint+test+build+deploy) → slow feedback
```

```
✅ cicd-pipeline-designer generated
   - SHA-pinned actions, auto-updatable via Renovate
   - OIDC federated AWS role — zero long-lived secrets
   - Caching: pnpm store → install in 30s after first run
   - permissions: contents: read top, id-token: write only on deploy
   - Job graph: ci → build → deploy — short feedback, parallelism
```

---

## Handoff

- **`cicd-security-hardener`** — audits the generated workflow for SLSA L3 conformance (SBOM presence, Sigstore attestation, dependency pinning, secret hygiene). ALWAYS dispatch after this skill.
- **`release-publisher`** — if `release.yml` was generated, release-publisher activates on tag push.
- **`accessibility-wcag-auditor`** — if the project is a frontend, add the axe-core job to `e2e.yml`.
- **Branch protection** — apply via `gh api` OR emit manual-config URL.

---

## References

- SLSA L3 — slsa.dev/spec/v1.0/levels
- GitHub Actions hardening — securitylab.github.com/research/github-actions-preventing-pwn-requests
- OIDC federation AWS — docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html
- Sigstore cosign — docs.sigstore.dev/cosign/
- Argo Rollouts (canary / blue-green) — argoproj.github.io/argo-rollouts/
- pin-github-action tool — github.com/mheap/pin-github-action
- Renovate action-pinning — docs.renovatebot.com/modules/manager/github-actions/
- ThoughtWorks Technology Radar 2026 — CI/CD platform trends
- Ciel pipeline: cicd-pipeline-designer → cicd-security-hardener (audit) → release-publisher (on tag)
