# Caller Guide

This guide walks you through integrating `autonomous-claude-sandbox` into another skill. Two worked examples (BDD and SDD) at the end show real usage patterns.

## The Basic Flow

```
Your skill controller (on host):
  1. Prepare input artifacts in $PROJECT_DIR/artifacts/current/
  2. Pre-render your prompt file (substitute template variables)
  3. exec run-sandbox.sh with the right flags
  4. When run-sandbox.sh returns, read the report file
  5. Surface results to the user
```

The key idea: your skill owns the **what** (the prompt, the expected output schema, post-processing logic), while `autonomous-claude-sandbox` owns the **how** (container lifecycle, credential safety, runtime detection).

## Step-by-Step

### Step 1: Prepare input artifacts

Before calling the launcher, put any files your prompt will read into `$PROJECT_DIR/artifacts/current/`. The container mounts the project at `/workspace`, so these files will appear at `/workspace/artifacts/current/`.

### Step 2: Pre-render your prompt file

`run-sandbox.sh` does NOT do template substitution. You must resolve all `{variable}` placeholders in your prompt file before calling. Typical approach:

```bash
# Inside your skill's script
TEMP_DIR="$PROJECT_DIR/artifacts/current/temp"
mkdir -p "$TEMP_DIR"

# Option A: sed (fine if values don't contain sed metacharacters)
sed "s|{max_rounds}|$MAX_ROUNDS|g; s|{install_cmd}|$INSTALL_CMD|g" \
  "~/.claude/skills/my-skill/references/my-prompt.md" \
  > "$TEMP_DIR/my-prompt-resolved.md"

# Option B: python (safer for arbitrary values)
python3 -c "
import sys
content = open(sys.argv[1]).read()
for arg in sys.argv[2:]:
    k, v = arg.split('=', 1)
    content = content.replace('{' + k + '}', v)
print(content, end='')
" \
  "~/.claude/skills/my-skill/references/my-prompt.md" \
  "max_rounds=$MAX_ROUNDS" \
  "install_cmd=$INSTALL_CMD" \
  > "$TEMP_DIR/my-prompt-resolved.md"
```

Option B is preferred when values might contain `|`, `&`, newlines, or other sed-sensitive characters.

### Step 3: Call the launcher

```bash
bash ~/.claude/skills/autonomous-claude-sandbox/scripts/run-sandbox.sh \
  --project-dir "$PROJECT_DIR" \
  --prompt-file "$TEMP_DIR/my-prompt-resolved.md" \
  --expect-output "artifacts/current/temp/my-report.json" \
  --progress-pattern 'Task [0-9]+:|Error:' \
  --timeout 7200
```

The launcher runs in the foreground. It will print:
- Runtime detection summary
- Docker build progress
- Progress events from the stream log (filtered by `--progress-pattern`)
- A final summary

### Step 4: Read the report after the launcher exits

```bash
REPORT="$PROJECT_DIR/artifacts/current/temp/my-report.json"
if [[ -f "$REPORT" ]]; then
  status=$(jq -r '.status' "$REPORT")
  case "$status" in
    SUCCESS) echo "All good" ;;
    PARTIAL) echo "Some tasks failed, see report for details" ;;
    *) echo "Unexpected status: $status" ;;
  esac
else
  echo "Report not generated — sandbox likely failed. Check stream log."
fi
```

### Step 5: Surface results to the user

Your skill is responsible for presenting the sandbox outcome to the user in a way that makes sense for your workflow. The sandbox launcher only tells you whether it ran and whether the expected output file exists — interpretation is up to you.

## Exit Codes

- `0` — Docker exited cleanly AND expected output exists (or no `--expect-output` given)
- `2` — Docker exited cleanly BUT `--expect-output` file is missing (prompt ran but didn't produce its report)
- Other non-zero — Docker itself failed (build error, timeout, runtime crash); check the stream log

## Worked Example 1: BDD Verification (bdd-e2e-loop)

```bash
#!/usr/bin/env bash
# Inside bdd-e2e-loop/scripts/bdd-sandbox.sh
set -euo pipefail

PROJECT_DIR="${1:?}"
MAX_ROUNDS="${2:-5}"

ARTIFACTS="$PROJECT_DIR/artifacts/current"
TEMP_DIR="$ARTIFACTS/temp"
mkdir -p "$TEMP_DIR"

# 1. Find BDD artifacts (BDD-specific)
VERIFICATION_PLAN=$(ls "$ARTIFACTS"/verification-plan*.md 2>/dev/null | head -1)
BDD_SCENARIOS=$(ls "$ARTIFACTS"/bdd-scenarios*.md 2>/dev/null | head -1)
if [[ -z "$VERIFICATION_PLAN" || -z "$BDD_SCENARIOS" ]]; then
  echo "ERROR: BDD artifacts not found" >&2
  exit 1
fi

# 2. Detect browser-use need (BDD-specific)
BROWSER_FLAG=""
if grep -qi "browser" "$VERIFICATION_PLAN"; then
  BROWSER_FLAG="--browser-use"
fi

# 3. Compute install_cmd from package manager (BDD-specific)
INSTALL_CMD="echo 'no deps'"
[[ -f "$PROJECT_DIR/uv.lock" ]] && INSTALL_CMD="uv sync"
[[ -f "$PROJECT_DIR/poetry.lock" ]] && INSTALL_CMD="poetry install"

# 4. Render the Stage 1 prompt (BDD-specific template)
python3 - "$HOME/.claude/skills/bdd-e2e-loop/references/stage1-prompt.md" \
  "max_rounds=$MAX_ROUNDS" \
  "install_cmd=$INSTALL_CMD" \
  "container_home=/home/sandboxuser" \
  "verification_plan_file=$(basename "$VERIFICATION_PLAN")" \
  "bdd_scenarios_file=$(basename "$BDD_SCENARIOS")" \
  <<'PY' > "$TEMP_DIR/stage1-prompt-resolved.md"
import sys
content = open(sys.argv[1]).read()
for arg in sys.argv[2:]:
    k, v = arg.split('=', 1)
    content = content.replace('{' + k + '}', v)
# Strip the markdown fence wrapping
lines = content.split('\n')
start = next((i for i, l in enumerate(lines) if l.strip() == '````'), 0) + 1
end = next((i for i, l in enumerate(lines[start:], start) if l.strip() == '````'), len(lines))
print('\n'.join(lines[start:end]), end='')
PY

# 5. Call the sandbox launcher
bash ~/.claude/skills/autonomous-claude-sandbox/scripts/run-sandbox.sh \
  --project-dir "$PROJECT_DIR" \
  --prompt-file "$TEMP_DIR/stage1-prompt-resolved.md" \
  --expect-output "artifacts/current/temp/auto-stage-report.json" \
  --progress-pattern '# [SJ]-[^\\]*' \
  --image-prefix "bdd-sandbox" \
  $BROWSER_FLAG

# 6. Summarize (BDD-specific)
REPORT="$TEMP_DIR/auto-stage-report.json"
if [[ -f "$REPORT" ]]; then
  status=$(jq -r '.status' "$REPORT")
  rounds=$(jq -r '.rounds_completed' "$REPORT")
  passed=$(jq '[.scenarios | to_entries[] | select(.value.final_status == "PASS")] | length' "$REPORT")
  failed=$(jq '[.scenarios | to_entries[] | select(.value.final_status == "FAIL")] | length' "$REPORT")
  echo "=== BDD Stage 1 ==="
  echo "Status: $status | Rounds: $rounds | Passed: $passed | Failed: $failed"
fi
```

## Worked Example 2: Autonomous Implementation (subagent-driven-development)

```bash
#!/usr/bin/env bash
# Inside the subagent-driven-development controller
set -euo pipefail

PROJECT_DIR="${1:?}"
TIMEOUT="${2:-7200}"   # 2 hours default

ARTIFACTS="$PROJECT_DIR/artifacts/current"
TEMP_DIR="$ARTIFACTS/temp"
mkdir -p "$TEMP_DIR"

# 1. Ensure the plan exists (SDD-specific)
if [[ ! -f "$ARTIFACTS/implementation.md" ]]; then
  echo "ERROR: No implementation plan at $ARTIFACTS/implementation.md" >&2
  exit 1
fi

# 2. Render the orchestrator prompt (SDD-specific)
cp ~/.claude/skills/subagent-driven-development/references/sandbox-orchestrator-prompt.md \
   "$TEMP_DIR/orchestrator-prompt.md"

# 3. Call the sandbox launcher
bash ~/.claude/skills/autonomous-claude-sandbox/scripts/run-sandbox.sh \
  --project-dir "$PROJECT_DIR" \
  --prompt-file "$TEMP_DIR/orchestrator-prompt.md" \
  --expect-output "artifacts/current/temp/sdd-sandbox-report.json" \
  --progress-pattern 'Task [0-9]+:|Spec review|Quality review|Flow verification' \
  --image-prefix "sdd-sandbox" \
  --timeout "$TIMEOUT"

# 4. Read the report
REPORT="$TEMP_DIR/sdd-sandbox-report.json"
if [[ ! -f "$REPORT" ]]; then
  echo "ERROR: Sandbox did not produce a completion report" >&2
  echo "Check stream log at $TEMP_DIR/sandbox-stream.jsonl for details" >&2
  exit 1
fi

status=$(jq -r '.status' "$REPORT")
total=$(jq -r '.tasks | length' "$REPORT")
completed=$(jq -r '[.tasks[] | select(.status == "completed")] | length' "$REPORT")
failed=$(jq -r '[.tasks[] | select(.status == "failed")] | length' "$REPORT")

echo "=== SDD Sandbox Complete ==="
echo "Status: $status | Tasks: $completed/$total completed, $failed failed"
echo ""
echo "Host now has the full changeset uncommitted. Review with 'git diff'"
echo "and commit when ready."
```

## Common Pitfalls

1. **Forgetting to pre-render the prompt.** The launcher will happily pass `{max_rounds}` to Claude as a literal string. Always substitute template variables before calling.

2. **Relative paths in `--prompt-file`.** The launcher converts it to absolute, but the file must exist at call time. Render it into a temp dir first, not a non-existent path.

3. **Forgetting `--expect-output`.** Without it, the launcher can't distinguish "Claude ran but crashed halfway" from "Claude ran and succeeded." Always pass `--expect-output` pointing to the file your prompt promises to write.

4. **Using `--progress-pattern` too broadly.** A permissive regex matches noise; a too-narrow one shows nothing. Start with something that matches task boundaries in your prompt (e.g., `Task [0-9]+:`), and iterate.

5. **Running git commands inside the sandbox.** The `/workspace` mount may be a git worktree whose `.git` pointer references a host path that does NOT exist in the container. Any `git` command inside will either crash or corrupt state. Your prompt MUST instruct Claude not to run git commands. Defer all commits to the host after the container exits.

6. **Expecting per-run log files to be idempotent.** If two sandbox runs use the same `--stream-log` path, the second overwrites the first. Either use unique paths or accept that only the latest run's log is preserved.
