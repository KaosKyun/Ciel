# cicd-pipeline-designer — Reference Library

Progressive disclosure companion to `SKILL.md`. Full templates + deployment/preview/OIDC/monorepo recipes. Load only when generating a non-trivial pipeline.

All SHAs below are valid as of 2026-04. Renovate / `pin-github-action` will rotate them automatically if configured.

---

## 1. Full per-language templates

### 1.1 Python — ci.yml (Poetry + pytest + ruff)

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
      - uses: actions/setup-python@0b93645e9fea7318ecaed2b359559ac225c90a2b # v5.3.0
        with:
          python-version-file: pyproject.toml
          cache: poetry
      - uses: snok/install-poetry@76e04a911780d5b312d89783f7b1cd627778900a # v1.4.1
        with:
          virtualenvs-in-project: true
      - run: poetry install --no-interaction --no-root
      - run: poetry run ruff check .
      - run: poetry run mypy .
  unit:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    strategy:
      fail-fast: false
      matrix:
        python-version: ["3.11", "3.12"]
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: actions/setup-python@0b93645e9fea7318ecaed2b359559ac225c90a2b # v5.3.0
        with:
          python-version: ${{ matrix.python-version }}
          cache: poetry
      - uses: snok/install-poetry@76e04a911780d5b312d89783f7b1cd627778900a # v1.4.1
      - run: poetry install --no-interaction --no-root
      - run: poetry run pytest --cov --cov-report=xml --junit-xml=junit.xml
      - uses: actions/upload-artifact@b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882 # v4.4.3
        if: always()
        with:
          name: pytest-py${{ matrix.python-version }}
          path: junit.xml
          retention-days: 7
```

Matrix only on libraries. Services pin one Python version.

### 1.2 Kotlin — ci.yml (Gradle + ktlint + Detekt)

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
  build-test:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: actions/setup-java@8df1039502a15bceb9433410b1a100fbe190c53b # v4.5.0
        with:
          distribution: temurin
          java-version: 21
      - uses: gradle/actions/setup-gradle@d9c87d481d55275bb5441eef3fe0e46805f9ef70 # v3.5.0
        with:
          cache-read-only: ${{ github.ref != 'refs/heads/main' }}
      - run: ./gradlew ktlintCheck detekt --no-daemon
      - run: ./gradlew test --no-daemon
      - uses: actions/upload-artifact@b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882 # v4.4.3
        if: always()
        with:
          name: test-reports
          path: '**/build/reports/tests/**'
          retention-days: 7
```

Gradle's `setup-gradle` action does configuration cache + dependency cache automatically. No manual `actions/cache` needed.

### 1.3 Rust — ci.yml (cargo + clippy + MSRV matrix)

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
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: dtolnay/rust-toolchain@4f647fc679bcd3b11499ccb42104547c83dabe96 # stable
        with:
          toolchain: stable
          components: rustfmt, clippy
      - uses: Swatinem/rust-cache@f0deed1e0edfc6a9be95417288c0e1099b1eeec3 # v2.7.7
      - run: cargo fmt --all -- --check
      - run: cargo clippy --all-targets --all-features -- -D warnings
  test:
    runs-on: ${{ matrix.os }}
    timeout-minutes: 15
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest]
        rust: [stable, "1.75"]  # stable + MSRV
        include:
          - os: macos-latest
            rust: stable
          - os: windows-latest
            rust: stable
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: dtolnay/rust-toolchain@4f647fc679bcd3b11499ccb42104547c83dabe96
        with:
          toolchain: ${{ matrix.rust }}
      - uses: Swatinem/rust-cache@f0deed1e0edfc6a9be95417288c0e1099b1eeec3 # v2.7.7
        with:
          key: ${{ matrix.os }}-${{ matrix.rust }}
      - run: cargo test --all-features --workspace
```

Use `Swatinem/rust-cache` instead of manual `actions/cache` — it knows Cargo's quirks (build artifact incremental compilation).

---

## 2. Deployment strategy recipes

### 2.1 Kubernetes rolling (medium risk)

```yaml
deploy:
  runs-on: ubuntu-latest
  timeout-minutes: 15
  environment:
    name: production
    url: https://app.example.com
  needs: [build]
  permissions:
    id-token: write  # OIDC
    contents: read
  steps:
    - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502 # v4.0.2
      with:
        role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE }}
        aws-region: eu-west-1
    - uses: azure/setup-kubectl@901a10e89ea615cf61f57ac05cecdf23e7de06d8 # v4.0.0
    - run: aws eks update-kubeconfig --name prod-cluster
    - name: Deploy (rolling update)
      run: |
        kubectl set image deployment/app app=ghcr.io/${{ github.repository }}:${{ github.sha }}
        kubectl rollout status deployment/app --timeout=5m
    - name: Post-deploy health check
      run: |
        for i in {1..30}; do
          curl -fsS https://app.example.com/health && exit 0
          sleep 10
        done
        echo "Health check failed — rolling back"
        kubectl rollout undo deployment/app
        exit 1
```

Readiness probes in the Deployment manifest are the primary gate; the health curl is a belt-and-suspenders.

### 2.2 Canary with Argo Rollouts (high risk)

```yaml
# Kubernetes Rollout resource (not in CI YAML, but required)
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: app
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: { duration: 5m }
        - setWeight: 50
        - pause: { duration: 10m }
        - setWeight: 100
      analysis:
        templates: [{ templateName: error-rate-slo }]
        startingStep: 1  # evaluate from 10% step
```

CI updates the image; Argo handles the gradual rollout + SLO analysis + auto-rollback on breach.

```yaml
# ci deploy job (minimal)
- run: |
    kubectl argo rollouts set image app app=ghcr.io/${{ github.repository }}:${{ github.sha }}
    kubectl argo rollouts status app --timeout 30m
```

### 2.3 Blue-green (high risk, immutable)

```yaml
deploy-blue-green:
  steps:
    - name: Deploy inactive color
      run: |
        ACTIVE=$(kubectl get svc app -o jsonpath='{.spec.selector.color}')
        INACTIVE=$([ "$ACTIVE" = "blue" ] && echo green || echo blue)
        kubectl set image deployment/app-$INACTIVE app=${{ github.sha }}
        kubectl rollout status deployment/app-$INACTIVE --timeout=5m
    - name: Smoke test inactive
      run: |
        INACTIVE_POD=$(kubectl get pod -l color=$INACTIVE -o name | head -1)
        kubectl exec $INACTIVE_POD -- curl -fsS http://localhost:8080/health
    - name: Swap traffic
      run: kubectl patch svc app -p '{"spec":{"selector":{"color":"'$INACTIVE'"}}}'
    - name: Keep previous as rollback target
      run: echo "Previous color $ACTIVE remains running for 30 min rollback window"
```

### 2.4 Serverless weighted alias (AWS Lambda, high risk)

```yaml
deploy-lambda:
  steps:
    - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502 # v4.0.2
      with:
        role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE }}
        aws-region: eu-west-1
    - name: Publish version
      id: publish
      run: |
        VERSION=$(aws lambda publish-version --function-name app --query Version --output text)
        echo "version=$VERSION" >> $GITHUB_OUTPUT
    - name: Shift traffic 10%
      run: |
        aws lambda update-alias --function-name app --name live \
          --function-version ${{ steps.publish.outputs.version }} \
          --routing-config "AdditionalVersionWeights={$(aws lambda get-alias --function-name app --name live --query FunctionVersion --output text)=0.9}"
    - name: Wait 5min + check CloudWatch errors
      run: |
        sleep 300
        ERRORS=$(aws cloudwatch get-metric-statistics --namespace AWS/Lambda \
          --metric-name Errors --dimensions Name=FunctionName,Value=app \
          --start-time $(date -u -v-5M +%Y-%m-%dT%H:%M:%S) \
          --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
          --period 300 --statistics Sum --query 'Datapoints[0].Sum' --output text)
        [ "$ERRORS" -lt 5 ] || { aws lambda update-alias ... rollback; exit 1; }
    - name: Shift 100%
      run: aws lambda update-alias --function-name app --name live --function-version ${{ steps.publish.outputs.version }} --routing-config "{}"
```

---

## 3. Preview environments per PR

### 3.1 Vercel / Netlify / Cloudflare Pages — trivial

Managed providers auto-build every PR. Just install the GitHub App; no CI YAML needed. Ensure the deployment URL is posted as a PR check.

### 3.2 Fly.io — per-PR app

```yaml
preview:
  if: github.event_name == 'pull_request'
  runs-on: ubuntu-latest
  concurrency:
    group: preview-${{ github.event.pull_request.number }}
  steps:
    - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
    - uses: superfly/flyctl-actions/setup-flyctl@fc53c09e1bc3be6f54706524e3b82c4f462f77be # v1.5
    - run: |
        APP_NAME="myapp-pr-${{ github.event.pull_request.number }}"
        flyctl apps list | grep -q "$APP_NAME" || flyctl apps create "$APP_NAME" --org personal
        flyctl deploy --app "$APP_NAME" --remote-only --wait-timeout 300
        echo "URL=https://$APP_NAME.fly.dev" >> $GITHUB_ENV
      env:
        FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
    - uses: marocchino/sticky-pull-request-comment@52423e01640425a022ef5fd42c6fb5f633a02728 # v2.9.0
      with:
        header: preview-url
        message: |
          Preview: ${{ env.URL }}

tear-down:
  if: github.event.action == 'closed'
  runs-on: ubuntu-latest
  steps:
    - uses: superfly/flyctl-actions/setup-flyctl@fc53c09e1bc3be6f54706524e3b82c4f462f77be
    - run: flyctl apps destroy "myapp-pr-${{ github.event.pull_request.number }}" --yes
      env:
        FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

### 3.3 Docker Compose — self-hosted runner

```yaml
preview-compose:
  if: github.event_name == 'pull_request'
  runs-on: [self-hosted, linux, preview-pool]
  steps:
    - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
    - name: Compose up
      run: |
        export PR=${{ github.event.pull_request.number }}
        export IMAGE_TAG=${{ github.sha }}
        docker compose -p pr-$PR -f docker-compose.preview.yml up -d
        echo "URL=https://pr-$PR.preview.example.com" >> $GITHUB_ENV
    - uses: marocchino/sticky-pull-request-comment@52423e01640425a022ef5fd42c6fb5f633a02728
      with:
        header: preview-url
        message: Preview: ${{ env.URL }}

preview-tear-down:
  if: github.event.action == 'closed'
  runs-on: [self-hosted, linux, preview-pool]
  steps:
    - run: docker compose -p pr-${{ github.event.pull_request.number }} -f docker-compose.preview.yml down -v
```

---

## 4. OIDC federation (zero long-lived cloud tokens)

### 4.1 AWS

Trust policy on the IAM role (once, in Terraform / CloudFormation):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike": { "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:ref:refs/heads/main" }
    }
  }]
}
```

Restrict `sub` to specific refs/environments — never `repo:ORG/REPO:*`.

Workflow usage:

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502 # v4.0.2
    with:
      role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions-deploy
      role-session-name: gh-actions-${{ github.run_id }}
      aws-region: eu-west-1
```

### 4.2 GCP (Workload Identity Federation)

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: google-github-actions/auth@71f986410dfbc7added4569d411d040a91dc6935 # v2.1.8
    with:
      workload_identity_provider: projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/gh/providers/gh-provider
      service_account: deploy@PROJECT.iam.gserviceaccount.com
```

### 4.3 Azure

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: azure/login@a65d910e8af852a8061c627c456678983e180302 # v2.2.0
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

`secrets.AZURE_CLIENT_ID` is the app registration ID (not a secret value) — paired with a federated credential on the app registration pointing to `repo:ORG/REPO:ref:refs/heads/main`.

---

## 5. Monorepo change-based CI

### 5.1 Turborepo (Node)

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
        with:
          fetch-depth: 0  # turbo needs full history for diff
      - uses: pnpm/action-setup@fe02b34f77f8bc703788d5817da081398fad5dd2 # v4.0.0
      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af # v4.1.0
        with:
          node-version-file: .nvmrc
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm turbo build test lint --filter=[origin/main]
        env:
          TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
          TURBO_TEAM: ${{ vars.TURBO_TEAM }}
```

`--filter=[origin/main]` runs only tasks for packages changed vs `main`. Remote cache (`TURBO_TOKEN`) shares build artifacts across CI + developer machines.

### 5.2 Nx

```yaml
- run: npx nx affected --target=build,test,lint --base=origin/${{ github.base_ref || 'main' }}
```

### 5.3 Bazel (polyglot)

```yaml
- run: bazel build //...
  # with remote cache:
  # --remote_cache=https://cache.example.com --remote_upload_local_results=${{ github.ref == 'refs/heads/main' }}
```

### 5.4 Changesets (releases in monorepos)

```yaml
release:
  if: github.ref == 'refs/heads/main'
  runs-on: ubuntu-latest
  permissions:
    contents: write  # for tag push
    pull-requests: write  # for version-PR
    id-token: write  # for npm provenance
  steps:
    - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
    - uses: changesets/action@c2b8277e9b8b21f72dc0dbc58f14a1a5d0a99bd6 # v1.4.10
      with:
        publish: pnpm release
      env:
        NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

`npm provenance` (via `id-token: write` + `--provenance` in publish script) ties the package to the specific commit + workflow.

---

## 6. SLSA Level 3 attestation workflow

Minimal workflow that emits a verifiable build provenance:

```yaml
name: release-slsa
on:
  push:
    tags: ['v*']
permissions:
  contents: write
  id-token: write  # for Sigstore
  attestations: write  # for gh attestation
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      digest: ${{ steps.hash.outputs.digest }}
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - run: make build  # produces ./dist/
      - id: hash
        run: |
          sha256sum dist/* | base64 -w0 > digest.txt
          echo "digest=$(cat digest.txt)" >> $GITHUB_OUTPUT
      - uses: actions/attest-build-provenance@c4fbc648846ca6f503a13a2281a5e7b98aa57202 # v2.0.1
        with:
          subject-path: 'dist/*'
      - uses: actions/upload-artifact@b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882 # v4.4.3
        with:
          name: dist
          path: dist/
          retention-days: 90
```

Consumers verify with:

```bash
gh attestation verify ./dist/binary --repo ORG/REPO
```

Hands off cleanly to `release-publisher` which uploads the `.intoto.jsonl` attestation alongside the release.

---

## 7. Scheduled / nightly jobs

```yaml
name: nightly
on:
  schedule:
    - cron: '0 3 * * *'  # 03:00 UTC
  workflow_dispatch:
permissions:
  contents: read
  issues: write  # auto-file issue on failure
jobs:
  full-e2e:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - run: pnpm test:e2e:full
      - if: failure()
        uses: JasonEtco/create-an-issue@1b14a70e4d8dc185e5cc76d3bec9eab20257b2c5 # v2.9.2
        with:
          filename: .github/ISSUE_TEMPLATE/nightly-failure.md
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Pair with `debug-reasoning-rca` on the filed issue for auto-RCA on next session.

---

## 8. Feature-matrix decision table

Use when designing the full workflow set — maps (project type × risk × compliance) to needed workflows.

| Combo | ci | build | e2e | deploy-staging | deploy-prod | release | nightly | preview |
|---|---|---|---|---|---|---|---|---|
| library, low risk, no compliance | ✓ | ✓ | — | — | — | ✓ | — | — |
| service, medium risk, no compliance | ✓ | ✓ | ✓ | ✓ | manual | — | ✓ | PR-scoped |
| service, high risk, SOC2 | ✓ | ✓ | ✓ | ✓ | manual + approval | ✓ | ✓ | ✓ |
| static/edge, low risk | ✓ | — | lighthouse-ci | auto | auto (protected branch) | — | — | auto (Vercel/Netlify) |
| monorepo N services | ✓ (affected) | ✓ (affected) | ✓ (affected) | matrix per service | matrix | changesets | ✓ | per-service |

---

## 9. 2026 platform comparison (quick picker)

| Platform | Best for | Notes |
|---|---|---|
| GitHub Actions | Most projects on GitHub | OIDC to all major clouds, best marketplace, Dependabot integrated |
| GitLab CI | GitLab-hosted, complex pipelines | DAG stages, merge trains, integrated registry |
| CircleCI | High-perf Docker workloads | Best remote Docker layer caching, orbs |
| Woodpecker CI | Self-hosted, lightweight | Docker-native, Drone fork, no vendor lock |
| Buildkite | Hybrid runners (SaaS control + self-hosted agents) | Best for regulated enterprises with on-prem data |
| Dagger | Pipeline-as-code (SDK, not YAML) | Engine-portable; same pipeline runs locally + any CI |

ThoughtWorks Radar 2026 Adopt: GitHub Actions for open source, Dagger for polyglot teams reducing YAML bloat.

---

## 10. Common mistakes this skill prevents

| Mistake | Consequence | Prevention |
|---|---|---|
| `uses: actions/checkout@v4` (floating tag) | Supply-chain: tag can be moved to malicious commit | Pin to SHA + version comment |
| `env: AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET }}` | Long-lived credential leak | OIDC federation instead |
| Single giant job (install+lint+test+build+deploy) | 15-min feedback loop, no parallelism | Split into ci → build → deploy with `needs:` |
| `permissions:` not declared | Default = all scopes | Declare `contents: read` at workflow top |
| No `timeout-minutes` | Hung job burns runner minutes | Every job has `timeout-minutes` |
| No `concurrency.cancel-in-progress` on PRs | Stale PR runs queue up | Cancel old PR runs on new push |
| `continue-on-error: true` on tests | Red tests silently ignored | Fix/quarantine, don't silence |
| `pull_request_target` without `if:` guard | Secrets leaked to fork PRs | Use `pull_request`; if really needed, guard on actor + repo |
| No artifact retention policy | Storage bloat + cost | `retention-days: 7` for PRs, 90 for main |
| Cache key = branch name | Cache hit rate drops | Key on lockfile hash: `hashFiles('**/lock')` |

---

## References (2026-current)

- GitHub Actions hardening — github.com/ossf/scorecard + securitylab.github.com
- SLSA spec v1.0 — slsa.dev/spec/v1.0/levels
- OIDC GitHub docs — docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect
- Sigstore cosign v2.x — docs.sigstore.dev/cosign/
- Argo Rollouts — argoproj.github.io/argo-rollouts/
- Turborepo remote cache — turbo.build/repo/docs/core-concepts/remote-caching
- Nx affected — nx.dev/ci/features/affected
- Dagger (pipeline-as-code) — dagger.io
- ThoughtWorks Technology Radar vol. 31+ (2026) — thoughtworks.com/radar
