---
name: bdd-e2e-loop
description: >-
  Execute the BDD verification plan from behavior-validation-plan against implemented code in an
  automated loop — runs curl/browser/script checks, dispatches a fixer for implementation bugs,
  surfaces design issues to the user, and handles manual verification via an interactive HTML
  checklist. Use after implementation completes (e.g., after subagent-driven-development or
  code-review-loop) or whenever the user asks to run BDD/E2E verification.
---

# BDD End-to-End Verification Loop

At the start, let the user know you're using this skill and what to expect — the process involves automated verification, potential fix rounds, and eventually manual testing.

## Overview

Execute the verification plan produced by behavior-validation-plan against the implemented code. This skill reads `bdd-scenarios.md` and `verification-plan.md`, resolves post-coding placeholders, runs all automated verifications, fixes failures in a loop, and presents manual verification to the user.

Three phases:
1. **Automated Verification Loop** (max 5 rounds) — Execute scenarios, classify failures, fix implementation bugs, surface design issues
2. **Manual Verification Phase** — After all automated scenarios pass, present manual tests via an interactive HTML checklist on the host
3. **Final Report** — Generate a comprehensive report with full test history and fix journey

## Prerequisites

- `artifacts/current/bdd-scenarios.md` exists (from behavior-validation-plan)
- `artifacts/current/verification-plan.md` exists (from behavior-validation-plan)
- Implementation is complete (from subagent-driven-development or after code-review-loop)

If either BDD file is missing, tell the user and suggest running behavior-validation-plan first. Do not attempt to derive scenarios on the fly — baseless scenarios give false confidence.

## Process

```
Step 0: Preparation
         │
         ▼
╔══════════════════════════════════╗
║  AUTOMATED LOOP                  ║
║  Subagent Verifier/Fixer         ║
╚══════════════════════════════════╝
         │
         ▼
╔════════════════════════════════════╗
║  MANUAL PHASE                     ║
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
2. Resolve all `[POST-CODING: ...]` placeholders by inspecting the codebase — find the specific file paths, function names, CLI arguments, log patterns, or entry points described in each placeholder
3. If a placeholder cannot be resolved (expected code structure doesn't exist), flag it to the user immediately rather than guessing
4. Separate automated scenarios (Deterministic + Browser Automation) from manual scenarios (Manual Behavior Test + User Acceptance Test)
5. Create `artifacts/current/temp/` directory if it doesn't exist
6. Write `artifacts/current/executable-verification.md` — the verification plan with all placeholders resolved
7. Proceed to the Automated Verification Loop

---

## Automated Verification Loop

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

## Manual Verification Phase

Enter this phase only when all automated scenarios pass. Only **Manual Behavior Test** scenarios are tested in this loop — these assist automated verification where technical limitations prevent the Coding Agent from testing directly (e.g., physical devices, high-concurrency environments).

**User Acceptance Test** scenarios are NOT part of this loop. They are listed in the final report as pending items for the user to verify at PR review time. Acceptance testing is a product-level check that happens at delivery, not during the fix cycle.

### Present Manual Behavior Test Checklist

1. Read `assets/manual-verification.html` template
2. Extract **only Manual Behavior Test** scenarios from `executable-verification.md`
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
3. Re-run ALL automated verification with a **separate round limit of 3** (MAX_ROUNDS = 3)
4. If automated passes → present Manual Behavior Test checklist again to user
5. If automated fails after 3 rounds → stop, report, prompt user

---

## Final Report

Write `artifacts/current/bdd-verification-report.md` following `references/report-template.md`.

The report has two parts:
1. **測試紀錄與修復過程** — Scenario progression matrix (only scenarios that ever failed), per-round fix details with root cause and approach, design issue decisions
2. **最終狀態** — Final pass/fail for each scenario (only those that ever failed), manual test results, pending UAT items, summary statistics

Data sources:
- **Automated rounds**: Aggregate from `artifacts/current/temp/bdd-verification-round-{N}.md` files and `artifacts/current/temp/fix-history.json`
- **Manual results**: From `manual-results-round-{N}.json`

Temp files in `artifacts/current/temp/` remain for reference but the report is the permanent record.

## Key Principles

1. **Targeted-first, then full regression.** After fixes, first verify only the previously-failed scenarios. Only run the full suite once targeted scenarios all pass. This avoids wasting rounds on full-suite runs when fixes haven't landed yet, while still catching regressions via the Phase 2 full suite check.

2. **Default to implementation bug, escalate with evidence.** Try fixing automatically before asking the user. Only surface design issues after consecutive failures on the same scenario.

3. **Fixer gets full fix history.** All previous rounds' fix descriptions prevent repeating failed approaches. If round 2's fix for S-auth-05 didn't work, the round 3 Fixer needs to know what was tried. Fix history is tracked in `artifacts/current/temp/fix-history.json`, not in git commits.

4. **Unit tests gate fix acceptance.** The Fixer cannot proceed if tests fail. This prevents cascading breakage that makes later rounds harder to debug.

5. **No git operations.** The BDD loop never runs git commands (no commit, no init, no add). All fix tracking is file-based. The host session commits changes after the loop completes. This keeps the loop isolated from version control concerns.

6. **Manual Behavior Tests in the loop, User Acceptance Tests at delivery.** Manual Behavior Test scenarios (assisting where automation has technical limitations) are part of the verification loop — they must pass for E2E completeness. User Acceptance Test scenarios are listed in the report as pending items for PR review, not tested in this loop.

7. **Hard limits prevent infinite loops.** 5 rounds for the main automated loop, 3 rounds for post-manual re-verification. When limits hit, stop and report — the user needs to intervene.

8. **Placeholders re-verified after changes.** When user decisions modify the design or plan, re-check `executable-verification.md` for stale placeholders.

## Reference Files

- `references/verifier-prompt.md` — Verifier subagent dispatch template
- `references/fixer-prompt.md` — Fixer subagent dispatch template
- `references/report-template.md` — Final report template
- `assets/manual-verification.html` — Interactive HTML template for manual testing
