---
name: bdd-e2e-loop
description: >-
  Execute BDD verification scenarios against implemented code in an automated
  loop. Runs the verification plan from behavior-validation-plan — executing
  curl commands, browser automation, and scripts — then dispatches a fixer for
  implementation bugs and surfaces design issues to the user. Handles manual
  verification via an interactive HTML checklist with screenshot support.
  Supports Docker Sandbox Mode for permission-free automated execution.
  Use this skill after coding is complete (subagent-driven-development finished)
  or after code-review-loop finishes its review cycle. Also trigger on phrases
  like "run BDD verification", "E2E verification loop", "execute test scenarios",
  "verify the implementation", "run the verification plan", "BDD loop",
  "run BDD", "跑 BDD", "執行驗證", "跑 E2E 測試", "驗證實作", "行為驗證",
  "跑驗證計畫", "verification loop", "run BDD in sandbox", "sandbox 跑 BDD",
  or "Docker BDD". This skill should also be triggered automatically by
  code-review-loop after its review cycle completes.
---

# BDD End-to-End Verification Loop

At the start, let the user know you're using this skill and what to expect — the process involves automated verification, potential fix rounds, and eventually manual testing.

## Overview

Execute the verification plan produced by behavior-validation-plan against the implemented code. This skill reads `bdd-scenarios.md` and `verification-plan.md`, resolves post-coding placeholders, runs all automated verifications, fixes failures in a loop, and presents manual verification to the user.

Two execution modes:
- **Standard Mode** — Run everything in the current session. Suitable when the user has configured permission allowlists or is willing to approve commands interactively.
- **Docker Sandbox Mode** — Run the automated loop inside an ephemeral Docker container with `--dangerously-skip-permissions`. The manual phase runs on the host. Use when the user wants zero-prompt automated verification.

Three phases regardless of mode:
1. **Automated Verification Loop** (max 5 rounds) — Execute scenarios, classify failures, fix implementation bugs, surface design issues
2. **Manual Verification Phase** — After all automated scenarios pass, present manual tests via an interactive HTML checklist on the host
3. **Final Report** — Generate a comprehensive report with full test history and fix journey

## Prerequisites

- `artifacts/current/bdd-scenarios.md` exists (from behavior-validation-plan)
- `artifacts/current/verification-plan.md` exists (from behavior-validation-plan)
- Implementation is complete (from subagent-driven-development or after code-review-loop)
- **Docker Sandbox Mode only**: Docker installed and running, `~/.claude/.credentials.json` exists (macOS: export from Keychain with `security find-generic-password -s "Claude Code-credentials" -w > ~/.claude/.credentials.json && chmod 600 ~/.claude/.credentials.json`), `~/.claude.json` exists. The container lifecycle (runtime detection, Dockerfile generation, credential copy, stream monitoring, cleanup) is provided by the `autonomous-claude-sandbox` skill — `bdd-sandbox.sh` is a thin BDD-specific wrapper around its `run-sandbox.sh` launcher.

If either BDD file is missing, tell the user and suggest running behavior-validation-plan first. Do not attempt to derive scenarios on the fly — baseless scenarios give false confidence.

## Process

```
Step 0: Preparation + Mode selection
         │
         ├── Standard Mode ──────────────────┐
         │                                    │
         │   ╔══════════════════════════════╗ │
         │   ║  AUTOMATED LOOP (local)      ║ │
         │   ║  Subagent Verifier/Fixer     ║ │
         │   ╚══════════════════════════════╝ │
         │                                    │
         ├── Docker Sandbox Mode ────────────┐│
         │                                   ││
         │   ╔══════════════════════════════╗ ││
         │   ║  STAGE 1 (Docker container)  ║ ││
         │   ║  bdd-sandbox.sh → claude -p  ║ ││
         │   ║  → auto-stage-report.json    ║ ││
         │   ╚══════════════════════════════╝ ││
         │            │                       ││
         │   ╔══════════════════════════════╗ ││
         │   ║  STAGE 2 (host session)      ║ ││
         │   ║  Read report → Design issues ║ ││
         │   ╚══════════════════════════════╝ ││
         │                                    ││
         ├────────────────────────────────────┘│
         ▼                                     │
╔════════════════════════════════════╗          │
║  MANUAL PHASE (always on host)    ║ ◄────────┘
║  HTML checklist → User tests →    ║
║  Fix if needed → Re-verify auto   ║
║  (max 3 rounds) → Repeat manual   ║
╚════════════════════════════════════╝
         │
         ▼
  bdd-verification-report.md
```

### Step 0: Preparation

1. Read `artifacts/current/verification-plan.md`
2. **Select execution mode**: Ask the user if they want Docker Sandbox Mode. Trigger sandbox if: user mentions "sandbox", "Docker", or the session is not running with `--dangerously-skip-permissions` and there are many automated scenarios.
3. If **Standard Mode** → continue to Step 0a
4. If **Docker Sandbox Mode** → jump to Docker Sandbox Automated Verification

#### Step 0a: Standard Mode Preparation

1. Resolve all `[POST-CODING: ...]` placeholders by inspecting the codebase — find the specific file paths, function names, CLI arguments, log patterns, or entry points described in each placeholder
2. If a placeholder cannot be resolved (expected code structure doesn't exist), flag it to the user immediately rather than guessing
3. Separate automated scenarios (Deterministic + Browser Automation) from manual scenarios (Manual Behavior Test + User Acceptance Test)
4. Create `artifacts/current/temp/` directory if it doesn't exist
5. Write `artifacts/current/executable-verification.md` — the verification plan with all placeholders resolved
6. Proceed to Standard Mode Automated Verification Loop

---

## Standard Mode: Automated Verification Loop

```
ROUND = 1
MAX_ROUNDS = 5
FIX_HISTORY = []        # [{round, fixes, not_fixed, tests_run}]
TARGETED_SCENARIOS = []  # empty = run all (Round 1)
```

### Round 1: Full Suite

Dispatch Verifier (read-only subagent, `references/verifier-prompt.md`) with ALL automated scenarios. Save results to `artifacts/current/temp/bdd-verification-round-1.md`.

If all pass → proceed to Manual Verification Phase.

If failures exist → classify, dispatch Fixer, set `TARGETED_SCENARIOS` to the failed scenario IDs, `ROUND++`.

### Round N (N > 1): Two-Phase Verification

#### Phase 1 — Targeted Verification

Dispatch Verifier with **only `TARGETED_SCENARIOS`** (the scenarios that failed last round and were supposedly fixed).

**If any targeted scenario still fails:**
1. Classify using the escalation ladder (see below)
2. Level 3 (technical limitation / design issue) → surface to user, wait for judgment
3. Level 1-2 (implementation bug) → dispatch Fixer → `ROUND++` → repeat Phase 1
4. If `ROUND >= MAX_ROUNDS` → stop, report remaining failures

**If all targeted scenarios pass** → proceed to Phase 2.

#### Phase 2 — Regression Check

Dispatch Verifier with **ALL automated scenarios** (full suite). This catches regressions introduced by the fixes.

**If new failures (regressions):**
→ Classify, dispatch Fixer → set `TARGETED_SCENARIOS` to the regressed scenario IDs → `ROUND++` → back to Phase 1

**If all pass** → proceed to Manual Verification Phase.

### Failure Classification

For each failed scenario, determine whether it's an implementation bug or a design issue:

**Level 1 — Clear implementation bug (send to Fixer):**
- Runtime error, stack trace, crash
- HTTP 5xx server error
- Timeout where design specifies responsiveness
- Wrong response format or missing fields vs. explicit design spec
- Feature produces no output or visibly broken output

**Level 2 — Ambiguous (default to implementation bug, try fixing first):**
- Feature responds but result doesn't match expected
- Partially correct output
- Inconsistent behavior across runs

**Level 3 — Escalate to design issue (only with evidence):**
- Same scenario fails for 2+ consecutive rounds despite fix attempts
- Fixer reports that the code logic is correct but the scenario expectation seems wrong
- Fixing scenario A breaks scenario B (conflicting expectations)

The principle: try to fix automatically first. Escalate to the user only when there's evidence the problem isn't in the code.

### Dispatch Fixer Subagent

Read `references/fixer-prompt.md` and dispatch a subagent with **write access**. Provide:

- All failed scenarios classified as implementation bugs, with expected vs. actual results
- The full `FIX_HISTORY` — all previous rounds' fixes and what was tried. This prevents the Fixer from repeating failed approaches.
- The corresponding scenario descriptions from `bdd-scenarios.md`

The Fixer must:
1. Fix the code
2. Run unit tests — tests must pass before the fix is accepted
3. Record: what was fixed, files changed, tests run
4. Append fix details to `artifacts/current/temp/fix-history.json`

**The Fixer does NOT commit.** All git operations are deferred to the host session after the BDD loop completes.

### Surface Design Issues

If any scenarios were classified as Level 3 design issues:
1. Present them with analysis: what the scenario expects, what the code does, why they conflict
2. Wait for user judgment: adjust design / adjust scenario / accept current behavior
3. If the verification plan changes: re-verify placeholders in `executable-verification.md`

---

## Docker Sandbox Mode: Automated Verification

### Prerequisites (Docker-specific)

- Docker installed and running
- `~/.claude/.credentials.json` exists. On macOS, OAuth tokens are stored in Keychain and must be exported to a file for Docker access:
  ```bash
  security find-generic-password -s "Claude Code-credentials" -w > ~/.claude/.credentials.json
  chmod 600 ~/.claude/.credentials.json
  ```
  The Keychain service name is `"Claude Code-credentials"` (capital C, space, hyphen). If the token rotates (e.g., after re-auth), re-run this export.
- `~/.claude.json` exists (Claude Code state file — created automatically by any Claude Code session)

### Stage 1: Run Automated Loop in Docker

1. Run the launcher script:
   ```bash
   bash ~/.claude/skills/bdd-e2e-loop/scripts/bdd-sandbox.sh <project-dir> [--max-rounds 5] [--browser-use]
   ```

2. The script auto-detects and configures:
   - **Python**: version from `pyproject.toml` `requires-python`, package manager from lock files (`uv.lock` → uv, `poetry.lock` → poetry, `Pipfile.lock` → pipenv, `requirements.txt` → pip)
   - **Node**: version from `.nvmrc` / `.node-version` / `package.json` `engines.node`, package manager from lock files (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm)
   - Generates an ephemeral Dockerfile with a **non-root user** (required — Claude Code refuses `--dangerously-skip-permissions` as root)
   - Mounts `~/.claude/` and `~/.claude.json` to the non-root user's home directory
   - Runs `claude -p --dangerously-skip-permissions --output-format stream-json --verbose` for real-time progress monitoring
   - Streams scenario progress to terminal while Docker runs in background
   - Writes results to `artifacts/current/temp/auto-stage-report.json`
   - Preserves stream log at `artifacts/current/temp/docker-stream.jsonl` for debugging
   - Cleans up Docker image and generated Dockerfile on exit

3. If `artifacts/current/executable-verification.md` already exists (from a previous Standard Mode run or manual preparation), the Docker Claude reuses it instead of re-resolving POST-CODING placeholders.

4. **Monitor the sandbox while it runs.** The script runs Docker in the background and streams progress to terminal, but the orchestrating agent (you) must also actively monitor via the stream log. Run the launcher script itself in the background (`run_in_background`), then periodically check progress:

   **How to monitor:**
   - The stream log is at `artifacts/current/temp/docker-stream.jsonl` (newline-delimited JSON, one event per line).
   - Check which scenario is currently running:
     ```bash
     grep '"name":"Bash"' artifacts/current/temp/docker-stream.jsonl | grep -o '"command":"# [SJ]-[^\\]*"' | tail -3
     ```
   - Check total progress (line count grows as scenarios execute):
     ```bash
     wc -l artifacts/current/temp/docker-stream.jsonl
     ```
   - Check if Docker is still running:
     ```bash
     docker ps --filter ancestor=bdd-sandbox --format '{{.Status}}'
     ```
   - Check if the final report has been written:
     ```bash
     ls -la artifacts/current/temp/auto-stage-report.json 2>/dev/null
     ```

   **Monitoring cadence:** Check every 2–5 minutes. Report the current scenario group (Discovery / CSV / Scorer / Runner / Result / Braintrust / Journey) to the user so they know progress is being made. Do not poll in a tight loop — the sandbox may run for 30+ minutes for large scenario sets.

   **If the container exits without producing `auto-stage-report.json`:** Read the tail of the stream log to diagnose. Common causes: context window exhaustion (too many scenarios), authentication failure, missing dependencies. Report the findings to the user.

### Stage 2: Process Results on Host

1. Read `artifacts/current/temp/auto-stage-report.json` (schema: `references/auto-stage-report-schema.md`)

2. Based on `status`:

   **`ALL_AUTO_PASS`** → Proceed to Manual Verification Phase

   **`DESIGN_ISSUES`**:
   - Present each design issue from `design_issues[]` where `user_decision` is null
   - Show: scenario ID, title, conflict analysis, consecutive failure count
   - Wait for user judgment: adjust design / adjust scenario / accept current behavior
   - If design changes affect the verification plan:
     1. Update `artifacts/current/verification-plan.md` and/or `bdd-scenarios.md`
     2. Re-run Stage 1: `bash bdd-sandbox.sh <project-dir> --max-rounds 5`
     3. Read updated report
   - If all remaining issues are accepted → proceed to Manual Verification Phase

   **`MAX_ROUNDS_HIT`**:
   - Present remaining failures from scenarios where `final_status` is FAIL/ERROR
   - Show the fix history from `fix_history[]` so the user can see what was already tried
   - Ask user: continue fixing manually? Adjust scenarios? Accept current state?

3. For regressions (from `regressions[]`): highlight to the user — these indicate fix instability

---

## Manual Verification Phase

Enter this phase only when all automated scenarios pass (from either mode). Only **Manual Behavior Test** scenarios are tested in this loop — these assist automated verification where technical limitations prevent the Coding Agent from testing directly (e.g., physical devices, high-concurrency environments).

**User Acceptance Test** scenarios are NOT part of this loop. They are listed in the final report as pending items for the user to verify at PR review time. Acceptance testing is a product-level check that happens at delivery, not during the fix cycle.

### Present Manual Behavior Test Checklist

1. Read `assets/manual-verification.html` template
2. Extract **only Manual Behavior Test** scenarios from `executable-verification.md` (Standard Mode) or from the `scenarios` object in `auto-stage-report.json` where `type` is `Manual Behavior Test` (Docker Sandbox Mode)
3. Construct scenario JSON array with fields: `id`, `title`, `type` ("technical"), `steps` (array), `expected`
   - **Command formatting**: When a step includes a terminal command the user must run, wrap it in a `<pre>` tag (rendered as a dark code block in the HTML). Use `<code>` for short inline references (file paths, variable names). Never embed long commands as plain text in a step — always use `<pre>`. For multi-line commands, include line breaks inside the `<pre>` block.
   - **Output-only print**: When the step involves running a Python script, print only a concise summary (e.g., status, key fields, lengths) — never `print()` the full result object, which may dump thousands of lines.
4. Replace `__SCENARIOS_PLACEHOLDER__` with the JSON and `__ROUND_PLACEHOLDER__` with the round number
5. Write to `artifacts/current/temp/manual-verification-round-{N}.html`
6. Open in browser: `open <path>`
7. Tell the user: "Manual verification (Technical) is ready in your browser. Test each scenario, mark pass/fail. For failures, describe the issue and paste screenshots with Cmd+V. Click Submit when done."

### Process Manual Results

When the user reports completion:
1. Locate the exported JSON (Downloads folder or user-specified path)
2. Copy to `artifacts/current/temp/manual-results-round-{N}.json`
3. Read results — Claude can see base64-encoded screenshot images in the JSON

If all Manual Behavior Tests pass → Final Report.

If any Manual Behavior Test fails:
1. Dispatch Fixer with failure descriptions and screenshots from the JSON
2. Fixer fixes → runs unit tests → records fixes in fix-history.json
3. Re-run ALL automated verification with a **separate round limit of 3**:
   - **Standard Mode**: Run Steps 1-5 locally with MAX_ROUNDS = 3
   - **Docker Sandbox Mode**: `bash bdd-sandbox.sh <project-dir> --max-rounds 3`
4. If automated passes → present Manual Behavior Test checklist again to user
5. If automated fails after 3 rounds → stop, report, prompt user

---

## Final Report

Write `artifacts/current/bdd-verification-report.md` following `references/report-template.md`.

The report has two parts:
1. **測試紀錄與修復過程** — Scenario progression matrix (only scenarios that ever failed), per-round fix details with root cause and approach, design issue decisions
2. **最終狀態** — Final pass/fail for each scenario (only those that ever failed), manual test results, pending UAT items, summary statistics

Data sources:
- **Standard Mode**: Aggregate from `artifacts/current/temp/bdd-verification-round-{N}.md` files and `artifacts/current/temp/fix-history.json`
- **Docker Sandbox Mode**: Read from `artifacts/current/temp/auto-stage-report.json` which already contains structured per-round data
- **Manual results**: From `manual-results-round-{N}.json`

Temp files in `artifacts/current/temp/` remain for reference but the report is the permanent record.

## Key Principles

1. **Targeted-first, then full regression.** After fixes, first verify only the previously-failed scenarios. Only run the full suite once targeted scenarios all pass. This avoids wasting rounds on full-suite runs when fixes haven't landed yet, while still catching regressions via the Phase 2 full suite check.

2. **Default to implementation bug, escalate with evidence.** Try fixing automatically before asking the user. Only surface design issues after consecutive failures on the same scenario.

3. **Fixer gets full fix history.** All previous rounds' fix descriptions prevent repeating failed approaches. If round 2's fix for S-auth-05 didn't work, the round 3 Fixer needs to know what was tried. Fix history is tracked in `artifacts/current/temp/fix-history.json`, not in git commits.

4. **Unit tests gate fix acceptance.** The Fixer cannot proceed if tests fail. This prevents cascading breakage that makes later rounds harder to debug.

5. **No git operations.** The BDD loop never runs git commands (no commit, no init, no add). All fix tracking is file-based. The host session commits changes after the loop completes. This avoids destructive git operations in Docker containers and keeps the loop isolated from version control concerns.

6. **Manual Behavior Tests in the loop, User Acceptance Tests at delivery.** Manual Behavior Test scenarios (assisting where automation has technical limitations) are part of the verification loop — they must pass for E2E completeness. User Acceptance Test scenarios are listed in the report as pending items for PR review, not tested in this loop.

7. **Hard limits prevent infinite loops.** 5 rounds for the main automated loop, 3 rounds for post-manual re-verification. When limits hit, stop and report — the user needs to intervene.

8. **Placeholders re-verified after changes.** When user decisions modify the design or plan, re-check `executable-verification.md` for stale placeholders.

9. **Docker sandbox for autonomous execution.** When the user wants zero-prompt automated verification, use Docker Sandbox Mode. The container isolates filesystem access to the mounted project directory only. The manual phase always runs on the host where the browser is available.

## Reference Files

- `references/verifier-prompt.md` — Verifier subagent dispatch template (Standard Mode Step 1)
- `references/fixer-prompt.md` — Fixer subagent dispatch template (Standard Mode Step 3)
- `references/stage1-prompt.md` — Stage 1 automated verification prompt (Docker Sandbox Mode)
- `references/auto-stage-report-schema.md` — JSON interface between Stage 1 and Stage 2
- `references/report-template.md` — Final report template
- `scripts/bdd-sandbox.sh` — Docker sandbox launcher script
- `assets/manual-verification.html` — Interactive HTML template for manual testing
