#!/usr/bin/env bash
#
# bdd-sandbox.sh — BDD-specific launcher that delegates container lifecycle
#                  to autonomous-claude-sandbox.
#
# Responsibilities (BDD-specific):
#   1. Locate verification-plan*.md and bdd-scenarios*.md artifacts
#   2. Compute install_cmd from detected Python/Node package managers
#   3. Auto-detect browser-use need by grepping the verification plan
#   4. Pre-render references/stage1-prompt.md template variables
#   5. Delegate to autonomous-claude-sandbox/scripts/run-sandbox.sh
#   6. Parse auto-stage-report.json and print a BDD-style summary
#
# Container lifecycle (Docker build, credential setup, stream monitoring,
# cleanup) is handled by autonomous-claude-sandbox.
#
# Usage:
#   bdd-sandbox.sh <project-dir> [--max-rounds N] [--browser-use]
set -euo pipefail

SANDBOX_SKILL_DIR="$HOME/.claude/skills/autonomous-claude-sandbox"
SANDBOX_LAUNCHER="$SANDBOX_SKILL_DIR/scripts/run-sandbox.sh"

if [[ ! -x "$SANDBOX_LAUNCHER" ]]; then
  echo "ERROR: autonomous-claude-sandbox launcher not found at $SANDBOX_LAUNCHER" >&2
  echo "Make sure the autonomous-claude-sandbox skill is installed." >&2
  exit 1
fi

# ─── Arguments ───────────────────────────────────────────────────────────────

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
MAX_ROUNDS=5
FORCE_BROWSER_USE=false

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-rounds) MAX_ROUNDS="$2"; shift 2 ;;
    --browser-use) FORCE_BROWSER_USE=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ─── Paths ───────────────────────────────────────────────────────────────────

ARTIFACTS_DIR="$PROJECT_DIR/artifacts/current"
TEMP_DIR="$ARTIFACTS_DIR/temp"
mkdir -p "$TEMP_DIR"

STAGE1_PROMPT="$HOME/.claude/skills/bdd-e2e-loop/references/stage1-prompt.md"
RENDERED_PROMPT="$TEMP_DIR/stage1-prompt-resolved.md"
REPORT="$TEMP_DIR/auto-stage-report.json"

# ─── Locate BDD artifacts (BDD-specific) ────────────────────────────────────

find_artifact() {
  local base="$1"  # e.g. "verification-plan" or "bdd-scenarios"
  local underscore_name="${base//-/_}"
  for pattern in \
      "$ARTIFACTS_DIR/${base}.md" \
      "$ARTIFACTS_DIR/${underscore_name}.md" \
      "$ARTIFACTS_DIR/${underscore_name}_"*.md \
      "$ARTIFACTS_DIR/${base}_"*.md; do
    local match
    # shellcheck disable=SC2086
    match=$(ls $pattern 2>/dev/null | head -1)
    if [[ -n "$match" ]]; then
      echo "$match"
      return 0
    fi
  done
  return 1
}

VERIFICATION_PLAN=$(find_artifact "verification-plan") || {
  echo "ERROR: No verification plan found in $ARTIFACTS_DIR/" >&2
  echo "Searched: verification-plan.md, verification_plan.md, verification_plan_*.md" >&2
  echo "Run behavior-validation-plan first." >&2
  exit 1
}
echo "Verification plan: $(basename "$VERIFICATION_PLAN")"

BDD_SCENARIOS=$(find_artifact "bdd-scenarios") || {
  echo "ERROR: No BDD scenarios found in $ARTIFACTS_DIR/" >&2
  echo "Searched: bdd-scenarios.md, bdd_scenarios.md, bdd_scenarios_*.md" >&2
  echo "Run behavior-validation-plan first." >&2
  exit 1
}
echo "BDD scenarios:     $(basename "$BDD_SCENARIOS")"

# ─── Detect runtimes via autonomous-claude-sandbox helper ───────────────────
# We need the detection result locally to compute install_cmd for the prompt template.
# The launcher will detect again when it runs; duplication is negligible (no I/O cost).

# shellcheck disable=SC1090
source "$SANDBOX_SKILL_DIR/scripts/detect-runtime.sh"

echo "Python:            $HAS_PYTHON (version: $PYTHON_VERSION, pkg: ${PYTHON_PKG_MGR:-none})"
echo "Node:              $HAS_NODE (version: $NODE_VERSION, pkg: ${NODE_PKG_MGR:-none}${NODE_SUBDIR:+, subdir: $NODE_SUBDIR})"

# ─── Compute install_cmd (BDD-specific) ─────────────────────────────────────

install_cmd="echo 'No package manager detected, skipping dependency install'"
case "${PYTHON_PKG_MGR:-}" in
  uv)      install_cmd="uv sync" ;;
  poetry)  install_cmd="poetry install" ;;
  pipenv)  install_cmd="pipenv install --dev" ;;
  pip)     install_cmd="pip install -r requirements.txt" ;;
esac

if [[ -n "${NODE_PKG_MGR:-}" ]]; then
  node_install=""
  cd_prefix=""
  if [[ -n "${NODE_SUBDIR:-}" ]]; then
    cd_prefix="cd /workspace/$NODE_SUBDIR && "
  fi
  case "$NODE_PKG_MGR" in
    pnpm) node_install="${cd_prefix}pnpm install --frozen-lockfile" ;;
    yarn) node_install="${cd_prefix}yarn install --frozen-lockfile" ;;
    npm)  node_install="${cd_prefix}npm ci" ;;
  esac
  if [[ -n "$node_install" ]]; then
    if [[ "$install_cmd" == "echo"* ]]; then
      install_cmd="$node_install"
    else
      install_cmd="${install_cmd} && ${node_install}"
    fi
  fi
fi

echo "Install cmd:       $install_cmd"

# ─── Auto-detect browser-use need (BDD-specific) ────────────────────────────

NEED_BROWSER_USE=$FORCE_BROWSER_USE
if ! $NEED_BROWSER_USE && grep -qi "browser" "$VERIFICATION_PLAN" 2>/dev/null; then
  NEED_BROWSER_USE=true
fi
echo "browser-use:       $NEED_BROWSER_USE"
echo ""

# ─── Pre-render Stage 1 prompt (BDD-specific) ───────────────────────────────
# Uses python3 for safe substitution — avoids sed escaping issues with install_cmd's &&

if [[ ! -f "$STAGE1_PROMPT" ]]; then
  echo "ERROR: Stage 1 prompt template not found at $STAGE1_PROMPT" >&2
  exit 1
fi

VPLAN_BASENAME=$(basename "$VERIFICATION_PLAN")
BDD_BASENAME=$(basename "$BDD_SCENARIOS")
CONTAINER_HOME="/home/sandboxuser"

BDD_MAX_ROUNDS="$MAX_ROUNDS" \
BDD_CONTAINER_HOME="$CONTAINER_HOME" \
BDD_INSTALL_CMD="$install_cmd" \
BDD_VPLAN_FILE="$VPLAN_BASENAME" \
BDD_SCENARIOS_FILE="$BDD_BASENAME" \
python3 - "$STAGE1_PROMPT" > "$RENDERED_PROMPT" <<'PY'
import os
import sys

template_path = sys.argv[1]
with open(template_path) as f:
    content = f.read()

substitutions = {
    "max_rounds":             os.environ["BDD_MAX_ROUNDS"],
    "container_home":         os.environ["BDD_CONTAINER_HOME"],
    "install_cmd":            os.environ["BDD_INSTALL_CMD"],
    "verification_plan_file": os.environ["BDD_VPLAN_FILE"],
    "bdd_scenarios_file":     os.environ["BDD_SCENARIOS_FILE"],
}

for key, value in substitutions.items():
    content = content.replace("{" + key + "}", value)

# stage1-prompt.md wraps the real prompt in ```` ... ```` fences. Strip them.
FENCE = "````"
lines = content.split("\n")
start_idx = None
end_idx = None
for i, line in enumerate(lines):
    if line.strip() == FENCE:
        if start_idx is None:
            start_idx = i + 1
        else:
            end_idx = i
            break

if start_idx is not None and end_idx is not None:
    content = "\n".join(lines[start_idx:end_idx])

sys.stdout.write(content)
PY

echo "Rendered prompt:   $RENDERED_PROMPT ($(wc -c < "$RENDERED_PROMPT" | tr -d ' ') bytes)"
echo ""

# ─── Delegate to autonomous-claude-sandbox ──────────────────────────────────

LAUNCHER_ARGS=(
  --project-dir "$PROJECT_DIR"
  --prompt-file "$RENDERED_PROMPT"
  --expect-output "artifacts/current/temp/auto-stage-report.json"
  --progress-pattern '# [SJ]-[^\\]*'
  --image-prefix "bdd-sandbox"
)
if $NEED_BROWSER_USE; then
  LAUNCHER_ARGS+=(--browser-use)
fi

bash "$SANDBOX_LAUNCHER" "${LAUNCHER_ARGS[@]}" || true

# ─── Parse report and print BDD-specific summary ────────────────────────────

echo ""
if [[ -f "$REPORT" ]]; then
  echo "=== Stage 1 Complete ==="
  echo "Report: $REPORT"
  echo ""
  status=$(jq -r '.status' "$REPORT" 2>/dev/null || echo "UNKNOWN")
  rounds=$(jq -r '.rounds_completed' "$REPORT" 2>/dev/null || echo "?")
  passed=$(jq '[.scenarios | to_entries[] | select(.value.final_status == "PASS")] | length' "$REPORT" 2>/dev/null || echo "?")
  failed=$(jq '[.scenarios | to_entries[] | select(.value.final_status == "FAIL")] | length' "$REPORT" 2>/dev/null || echo "?")
  echo "Status:  $status"
  echo "Rounds:  $rounds / $MAX_ROUNDS"
  echo "Passed:  $passed"
  echo "Failed:  $failed"
else
  echo "WARNING: auto-stage-report.json was not generated." >&2
  echo "Check the sandbox stream log for details." >&2
  exit 1
fi
