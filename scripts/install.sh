#!/bin/bash
# Ciel — Post-install setup
# Run after: claude plugin install github:KaosKyun/Ciel
# Usage: bash scripts/install.sh [project-root]

set -e

PROJECT_ROOT="${1:-$(pwd)}"
OVERLAY_PATH="$PROJECT_ROOT/ciel-overlay.md"
PLUGIN_DIR="${CIEL_PLUGIN_DIR:-$HOME/.claude/plugins/ciel}"

echo "Ciel — Setup"
echo "Project root: $PROJECT_ROOT"

# ─── Stack detection ──────────────────────────────────────────────────────────
detect_skills() {
  local root="$1"
  local skills=()

  # Frontend
  if [ -f "$root/package.json" ]; then
    if grep -qE '"react"' "$root/package.json" 2>/dev/null; then
      skills+=("frontend-mastery")
    fi
    if grep -qE '"vue"' "$root/package.json" 2>/dev/null; then
      skills+=("frontend-mastery")
    fi
    if grep -qE '"svelte"' "$root/package.json" 2>/dev/null; then
      skills+=("frontend-mastery")
    fi
    # Testing
    if grep -qE '"vitest"|"jest"|"playwright"' "$root/package.json" 2>/dev/null; then
      skills+=("frontend-mastery")
    fi
  fi

  # Backend Kotlin/JVM
  if [ -f "$root/build.gradle.kts" ] || [ -f "$root/build.gradle" ] || \
     find "$root" -name "build.gradle.kts" -maxdepth 3 2>/dev/null | grep -q .; then
    skills+=("backend-mastery")
    if grep -rqE 'ktor|spring|micronaut' "$root" --include="*.kts" --include="*.gradle" 2>/dev/null; then
      skills+=("backend-mastery")
    fi
  fi

  # Backend Python
  if [ -f "$root/requirements.txt" ] || [ -f "$root/pyproject.toml" ] || [ -f "$root/setup.py" ]; then
    skills+=("backend-mastery")
  fi

  # Backend Go
  if [ -f "$root/go.mod" ]; then
    skills+=("backend-mastery")
  fi

  # Backend Rust
  if [ -f "$root/Cargo.toml" ]; then
    skills+=("backend-mastery")
  fi

  # Database
  if [ -d "$root/supabase/migrations" ] || [ -d "$root/prisma" ] || \
     find "$root" -name "*.sql" -maxdepth 4 2>/dev/null | grep -q .; then
    skills+=("database-mastery")
  fi

  # Security (auth patterns)
  if find "$root" -type d \( -name "auth" -o -name "security" \) -maxdepth 5 2>/dev/null | grep -q .; then
    skills+=("security-hardening")
  fi
  if grep -rqE 'jwt|oauth|totp|webauthn|bcrypt|password' "$root" \
     --include="*.ts" --include="*.kt" --include="*.py" --include="*.go" \
     --max-depth=5 2>/dev/null | head -1 | grep -q .; then
    skills+=("security-hardening")
  fi

  # API design
  if grep -rqE 'route|router|endpoint|@Get|@Post|fun get|fun post' "$root" \
     --include="*.kt" --include="*.ts" --include="*.py" --include="*.go" \
     --max-depth=5 2>/dev/null | head -1 | grep -q .; then
    skills+=("api-architecture")
  fi

  # Observability
  if grep -rqE 'logger|logging|metrics|tracing|opentelemetry' "$root" \
     --include="*.kt" --include="*.ts" --include="*.py" --include="*.go" \
     --max-depth=5 2>/dev/null | head -1 | grep -q .; then
    skills+=("observability")
  fi

  # Deduplicate
  printf '%s\n' "${skills[@]}" | sort -u
}

# ─── Overlay generation ───────────────────────────────────────────────────────
generate_skills_section() {
  local root="$1"
  local detected
  detected=$(detect_skills "$root")

  echo "## Domain Skills (auto-detected)"
  echo ""
  if [ -z "$detected" ]; then
    echo "<!-- No stack detected automatically. Add skills manually below. -->"
    echo "<!-- Available: frontend-mastery, backend-mastery, database-mastery, security-hardening, api-architecture, observability, performance-engineering, refactoring-patterns -->"
  else
    echo "Ciel will invoke these domain skills IN PARALLEL with the researcher agent at RECHERCHE."
    echo "Remove any that don't apply. Add others as needed."
    echo ""
    while IFS= read -r skill; do
      [ -n "$skill" ] && echo "- $skill"
    done <<< "$detected"
  fi
  echo ""
}

# ─── Create or update overlay ─────────────────────────────────────────────────
if [ ! -f "$OVERLAY_PATH" ]; then
  echo "Detecting stack in $PROJECT_ROOT..."
  DETECTED=$(detect_skills "$PROJECT_ROOT")
  if [ -n "$DETECTED" ]; then
    echo "→ Detected skills: $(echo "$DETECTED" | tr '\n' ' ')"
  else
    echo "→ No stack detected — overlay will have manual placeholders."
  fi

  # Build overlay from template + inject skills section
  TEMPLATE="$PLUGIN_DIR/overlay-template.md"
  if [ -f "$TEMPLATE" ]; then
    # Insert skills section after the header block (after first ---)
    awk -v skills_section="$(generate_skills_section "$PROJECT_ROOT")" \
      'NR==1{print; print ""; print skills_section; next} {print}' \
      "$TEMPLATE" > "$OVERLAY_PATH"
  else
    # Fallback: create minimal overlay with skills section
    {
      echo "# Ciel Overlay — $(basename "$PROJECT_ROOT")"
      echo ""
      generate_skills_section "$PROJECT_ROOT"
      echo "## Stack"
      echo ""
      echo "- Frontend: [specify]"
      echo "- Backend: [specify]"
      echo "- DB: [specify]"
      echo ""
      echo "## Rules"
      echo ""
      echo "[Project-specific rules]"
    } > "$OVERLAY_PATH"
  fi
  echo "→ Created $OVERLAY_PATH"
  echo "  Review detected skills and fill in stack versions."
else
  # Overlay exists — inject/update skills section if missing
  if ! grep -q "## Domain Skills" "$OVERLAY_PATH"; then
    echo "Updating existing overlay with Domain Skills section..."
    SKILLS_SECTION=$(generate_skills_section "$PROJECT_ROOT")
    # Prepend skills section after first heading
    awk -v section="$SKILLS_SECTION" \
      '/^## /{if(!done){print section; done=1}} {print}' \
      "$OVERLAY_PATH" > "${OVERLAY_PATH}.tmp" && mv "${OVERLAY_PATH}.tmp" "$OVERLAY_PATH"
    echo "→ Domain Skills section added to existing overlay."
  else
    echo "→ ciel-overlay.md already has Domain Skills section — skipping."
  fi
fi

# ─── Make hooks executable ────────────────────────────────────────────────────
if [ -d "$PLUGIN_DIR/hooks" ]; then
  chmod +x "$PLUGIN_DIR/hooks/"*.sh 2>/dev/null || true
  echo "→ Hooks set as executable."
fi

# ─── Seed .version ────────────────────────────────────────────────────────────
VERSION_FILE="$PLUGIN_DIR/.version"
if [ ! -f "$VERSION_FILE" ]; then
  # Fetch current SHA from GitHub if gh is available
  if command -v gh &>/dev/null; then
    SHA=$(gh api repos/KaosKyun/Ciel/contents/skills/ciel/SKILL.md --jq '.sha' 2>/dev/null || echo "")
    if [ -n "$SHA" ]; then
      echo "$SHA" > "$VERSION_FILE"
      echo "→ .version seeded: $SHA"
    fi
  fi
fi

echo ""
echo "Setup complete."
echo "  /ciel <task>       — start workflow"
echo "  /ciel-update       — pull latest Ciel version"
echo "  Edit ciel-overlay.md to fill in stack versions and project rules."
