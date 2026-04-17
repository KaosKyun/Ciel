---
name: cicd-security-hardener
description: Audits CI/CD pipelines (GitHub Actions primarily, GitLab CI / CircleCI secondarily) against 2026 supply-chain security baselines — SLSA Level 3+, Sigstore/Cosign keyless signing, ephemeral runners, SBOM generation, dependency pinning. Flags long-lived secrets, `pull_request_target` misuse, and missing attestations. Invoked when creating or reviewing `.github/workflows/*.yml` or equivalent.
allowed-tools: Read, Grep, Glob, Bash
context: fork
agent: explorer
---

# cicd-security-hardener — SLSA 3 is table stakes in 2026

Supply-chain attacks moved from "rare incident" to "monthly news" (XZ, SolarWinds, CircleCI). The 2026 baseline is SLSA Level 3 + Sigstore keyless — not a wishlist, a minimum.

---

## Inputs

```
PIPELINE_FILES: [.github/workflows/*.yml | .gitlab-ci.yml | .circleci/config.yml]
PROJECT_TYPE: [library | service | CLI | container-image]
CURRENT_RELEASE_PROCESS: [manual | semantic-release | release-please | none]
```

---

## The 2026 baseline checklist

### 1. Source integrity

- [ ] **Required reviewers on protected branches** (1+ approval for `main`/`release-*`)
- [ ] **Signed commits enforced** (Sigstore via `gitsign` OR GPG; not both)
- [ ] **Branch protection rules immutable** (admin can't bypass without audit)

### 2. Build integrity

- [ ] **Ephemeral runners** — `runs-on: ubuntu-latest` (hosted) OR `runs-on: [self-hosted, ephemeral]`. Self-hosted with persistent state = FAIL.
- [ ] **No long-lived cloud credentials** — use OIDC federation (`aws-actions/configure-aws-credentials@v4` with `role-to-assume`, not `aws-access-key-id` secrets)
- [ ] **Pinned action versions** — `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2` (SHA pinning; tag pinning is insufficient per SLSA L3)
- [ ] **No `pull_request_target` with checkout of untrusted ref** — classic RCE vector

### 3. Artifact integrity

- [ ] **SLSA provenance generated** — use `slsa-framework/slsa-github-generator` on release
- [ ] **Artifacts signed with Sigstore/Cosign** — keyless via OIDC identity token
- [ ] **SBOM attached** — `syft` or `cyclonedx-bom` → attached as release asset
- [ ] **Attestations uploaded** — `actions/attest-build-provenance@v1` on `release` event

### 4. Deployment integrity

- [ ] **Attestation verification before deploy** — `cosign verify-attestation` before `kubectl apply`
- [ ] **No direct `kubectl` from local machines** — only via CI with OIDC

### 5. Secrets

- [ ] **No `${{ secrets.X }}` echoed to logs** — `::add-mask::` required
- [ ] **Secrets scoped to workflow, not org-wide** — unless genuinely needed
- [ ] **Rotation documented** — a `SECRETS.md` lists each secret, owner, rotation cadence

---

## Common anti-patterns (immediate BLOCK)

```yaml
# BLOCK 1 — untrusted checkout with write access
on: pull_request_target
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - run: npm install && npm run build  # runs attacker's code with repo secrets
```

```yaml
# BLOCK 2 — long-lived AWS credentials
- uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_KEY }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET }}
```

```yaml
# BLOCK 3 — unpinned action
- uses: some-org/questionable-action@main  # pulls latest at every run
```

```yaml
# BLOCK 4 — secret echoed
- run: echo "Using token ${{ secrets.DEPLOY_TOKEN }}"
```

---

## Canonical 2026 patterns

### OIDC to AWS (no long-lived keys)

```yaml
permissions:
  id-token: write
  contents: read
jobs:
  deploy:
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123:role/github-deploy
          aws-region: eu-west-1
```

### SLSA Level 3 release

```yaml
jobs:
  release:
    permissions:
      id-token: write
      contents: write
      attestations: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.0.0
    with:
      base64-subjects: ${{ needs.build.outputs.hashes }}
```

### Sigstore keyless signing of container

```yaml
- uses: sigstore/cosign-installer@v3
- run: cosign sign --yes ghcr.io/${{ github.repository }}@${{ steps.digest.outputs.digest }}
```

### SBOM generation

```yaml
- uses: anchore/sbom-action@v0
  with:
    image: ghcr.io/${{ github.repository }}:${{ github.sha }}
    format: cyclonedx-json
    output-file: sbom.cdx.json
```

---

## Report format

```
## CI/CD SECURITY AUDIT

### Files audited
- .github/workflows/build.yml
- .github/workflows/release.yml

### Findings
[BLOCK] release.yml:24 — AWS long-lived keys — migrate to OIDC federation
[BLOCK] build.yml:12 — pull_request_target + untrusted checkout — RCE vector
[WARN]  release.yml:55 — action pinned by tag (`@v4`) not SHA — SLSA L3 requires SHA
[WARN]  build.yml:66 — no SBOM generation
[INFO]  release.yml — no SLSA provenance generator integrated (add for L3)

### SLSA maturity assessment
Current: Level 1 (build is automated but not attested)
Target:  Level 3 (hermetic build + provenance + attestation verification)
Gap:     provenance generator, attestation verification, SHA pinning

### Suggested PRs
1. Replace AWS creds with OIDC role (release.yml) — 5 line change
2. Replace `pull_request_target` with `pull_request` + approval gate
3. Add SLSA generator workflow (canonical template provided)
4. Add `anchore/sbom-action` to release job
```

---

## Guardrails

- **BLOCK means don't merge** — long-lived keys, RCE vectors, echoed secrets.
- **Don't auto-rewrite pipelines** — propose, don't replace. Pipelines have team context this skill doesn't see.
- **SHA pinning exception**: `actions/checkout` pinned to `v4` (maintained by GitHub) is tolerable for Standard; BLOCK for Critical (government, healthcare, finance).
- **Self-hosted runners**: if used, require `ephemeral` + `no network to internal`. Otherwise treat as Critical security gap.
- **Don't audit GitLab CI with GitHub Actions lens** — rewrite recommendations for the actual platform syntax.
- **SLSA L4 is not expected** — L3 is the 2026 baseline for most orgs; L4 requires deterministic builds and is a specialty concern.

---

## When triggered

- Any PR touching `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/config.yml`
- Setting up release pipeline for a new project
- Security review (Critical task)
- `@ciel-explorer` dispatched with CATEGORY=devops

---

## References

- slsa.dev — SLSA Framework (Level 3 requirements)
- sigstore.dev — Keyless signing via OIDC
- github.com/slsa-framework/slsa-github-generator — canonical L3 provenance generator
- cisa.gov — Supply-chain security guidance 2026
- anchore.com/sbom — SBOM generation tooling
