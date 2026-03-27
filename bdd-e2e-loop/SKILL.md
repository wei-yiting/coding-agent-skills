---
name: bdd-e2e-loop
description: >-
  Execute BDD verification scenarios against implemented code in an automated
  loop. Runs the verification plan from behavior-validation-plan — executing
  curl commands, browser automation, and scripts — then dispatches a fixer for
  implementation bugs and surfaces design issues to the user. Handles manual
  verification via an interactive HTML checklist with screenshot support. Use
  this skill after coding is complete (subagent-driven-development finished) or
  after code-review-loop finishes its review cycle. Also trigger on phrases like
  "run BDD verification", "E2E verification loop", "execute test scenarios",
  "verify the implementation", "run the verification plan", "BDD loop",
  "run BDD", "跑 BDD", "執行驗證", "跑 E2E 測試", "驗證實作", "行為驗證",
  "跑驗證計畫", or "verification loop". This skill should also be triggered
  automatically by code-review-loop after its review cycle completes.
---

# BDD End-to-End Verification Loop

At the start, let the user know you're using this skill and what to expect — the process involves automated verification, potential fix rounds, and eventually manual testing.

## Overview

Execute the verification plan produced by behavior-validation-plan against the implemented code. This skill reads `bdd-scenarios.md` and `verification-plan.md`, resolves post-coding placeholders, runs all automated verifications, fixes failures in a loop, and presents manual verification to the user.

Two phases:
1. **Automated Verification Loop** (max 5 rounds) — Execute scenarios, classify failures, fix implementation bugs, surface design issues
2. **Manual Verification Phase** — After all automated scenarios pass, present manual tests via an interactive HTML checklist

## Prerequisites

- `.artifacts/current/bdd-scenarios.md` exists (from behavior-validation-plan)
- `.artifacts/current/verification-plan.md` exists (from behavior-validation-plan)
- Implementation is complete (from subagent-driven-development or after code-review-loop)

If either BDD file is missing, tell the user and suggest running behavior-validation-plan first. Do not attempt to derive scenarios on the fly — baseless scenarios give false confidence.

## Process

```
Step 0: Resolve placeholders
         │
         ▼
╔════════════════════════════════════╗
║  AUTOMATED LOOP (max 5 rounds)    ║
║  Verify ALL → Classify failures → ║
║  Fix impl bugs → Surface design   ║
║  issues → Repeat                  ║
╚════════════════════════════════════╝
         │ all automated pass
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

1. Read `.artifacts/current/verification-plan.md`
2. Resolve all `[POST-CODING: ...]` placeholders by inspecting the codebase — find the specific file paths, function names, CLI arguments, log patterns, or entry points described in each placeholder
3. If a placeholder cannot be resolved (expected code structure doesn't exist), flag it to the user immediately rather than guessing
4. Separate automated scenarios (Deterministic + Browser Automation) from manual scenarios (Manual Behavior Test + User Acceptance Test)
5. Create `.artifacts/current/temp/` directory if it doesn't exist
6. Write `.artifacts/current/executable-verification.md` — the verification plan with all placeholders resolved

### Automated Verification Loop

```
ROUND = 1
MAX_ROUNDS = 5
COMMIT_HISTORY = []   # [{round, hash, summary}]
```

#### Step 1: Dispatch Verifier Subagent

Read `references/verifier-prompt.md` and dispatch a **read-only** subagent with:
- The full automated section of `executable-verification.md`
- Round number and previous round context

The Verifier runs ALL automated scenarios every round. Fixing one issue can break others, so partial re-verification is unreliable. The Verifier returns a structured report: each scenario's pass/fail status with the actual result observed.

Save output to `.artifacts/current/temp/bdd-verification-round-{ROUND}.md`.

#### Step 2: Classify Failures

For each failed scenario, determine whether it's an implementation bug or a design issue using this escalation ladder:

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

The principle: try to fix automatically first. Escalate to the user only when there's evidence the problem isn't in the code. This keeps the user focused on decisions that genuinely need human judgment.

**Example:** Scenario S-auth-05 expects HTTP 429 on the 6th failed login. Round 1: Verifier sees HTTP 200 (rate limiting not implemented). This is Level 1 — clear implementation bug. Round 2 after fix: still HTTP 200 (fix didn't work). Same scenario, 2nd consecutive failure → escalate to Level 3. Ask user: "Rate limiting doesn't seem to be implemented. Is this a missing feature or was it descoped?"

#### Step 3: Dispatch Fixer Subagent

Read `references/fixer-prompt.md` and dispatch a subagent with **write access**. Provide:

- All failed scenarios classified as implementation bugs, with expected vs. actual results
- The full `COMMIT_HISTORY` — all previous rounds' git commit hashes and what was fixed in each. This prevents the Fixer from repeating failed approaches.
- The corresponding scenario descriptions from `bdd-scenarios.md`

The Fixer must:
1. Fix the code
2. Run unit tests — tests must pass before committing
3. Create one commit: `bdd-e2e-loop: round {ROUND} fixes`
4. Report: what was fixed, tests run, commit hash

Append `{round: ROUND, hash: <hash>, summary: <what was fixed>}` to `COMMIT_HISTORY`.

#### Step 4: Surface Design Issues

If any scenarios were classified as Level 3 design issues:
1. Present them with analysis: what the scenario expects, what the code does, why they conflict
2. Wait for user judgment: adjust design / adjust scenario / accept current behavior
3. If the verification plan changes: re-verify placeholders in `executable-verification.md`

#### Step 5: Decide Next Action

- All automated scenarios pass → proceed to Manual Verification Phase
- Failures remain and `ROUND < MAX_ROUNDS` → `ROUND += 1`, return to Step 1
- `ROUND >= MAX_ROUNDS` → stop, produce report with remaining failures, prompt user

### Manual Verification Phase

Enter this phase only when all automated scenarios pass. Only **Manual Behavior Test** scenarios are tested in this loop — these assist automated verification where technical limitations prevent the Coding Agent from testing directly (e.g., physical devices, high-concurrency environments).

**User Acceptance Test** scenarios are NOT part of this loop. They are listed in the final report as pending items for the user to verify at PR review time. Acceptance testing is a product-level check that happens at delivery, not during the fix cycle.

#### Present Manual Behavior Test Checklist

1. Read `assets/manual-verification.html` template
2. Extract **only Manual Behavior Test** scenarios from `executable-verification.md`
3. Construct scenario JSON array with fields: `id`, `title`, `type` ("technical"), `steps` (array), `expected`
4. Replace `__SCENARIOS_PLACEHOLDER__` with the JSON and `__ROUND_PLACEHOLDER__` with the round number
5. Write to `.artifacts/current/temp/manual-verification-round-{N}.html`
6. Open in browser: `open <path>`
7. Tell the user: "Manual verification (Technical) is ready in your browser. Test each scenario, mark pass/fail. For failures, describe the issue and paste screenshots with Cmd+V. Click Submit when done."

#### Process Manual Results

When the user reports completion:
1. Locate the exported JSON (Downloads folder or user-specified path)
2. Copy to `.artifacts/current/temp/manual-results-round-{N}.json`
3. Read results — Claude can see base64-encoded screenshot images in the JSON

If all Manual Behavior Tests pass → Final Report.

If any Manual Behavior Test fails:
1. Dispatch Fixer with failure descriptions and screenshots from the JSON
2. Fixer fixes → runs unit tests → commits
3. Re-run ALL automated verification with a **separate round limit of 3**
   - If automated passes → present Manual Behavior Test checklist again to user
   - If automated fails after 3 rounds → stop, report, prompt user

#### Final Report

Write `.artifacts/current/bdd-verification-report.md` following `references/report-template.md`:
- Integrate automated results (per-round summary)
- Integrate Manual Behavior Test results (from manual-results JSON)
- **List User Acceptance Test scenarios as pending** — include the full checklist with steps and acceptance questions, marked as "to be verified at PR review"
- List all fix commit hashes with summaries
- Record design issues surfaced and user decisions
- Final pass/fail statistics

Temp files in `.artifacts/current/temp/` remain for reference but the report is the permanent record.

## Key Principles

1. **Every round verifies ALL scenarios.** Fixing A can break B. Never skip scenarios to save time — partial verification creates false confidence.

2. **Default to implementation bug, escalate with evidence.** Try fixing automatically before asking the user. Only surface design issues after consecutive failures on the same scenario.

3. **Fixer gets full commit history.** All previous rounds' hashes and summaries prevent repeating failed approaches. If round 2's fix for S-auth-05 didn't work, the round 3 Fixer needs to know what was tried.

4. **Unit tests gate commits.** The Fixer cannot commit if tests fail. This prevents cascading breakage that makes later rounds harder to debug.

5. **Manual Behavior Tests in the loop, User Acceptance Tests at delivery.** Manual Behavior Test scenarios (assisting where automation has technical limitations) are part of the verification loop — they must pass for E2E completeness. User Acceptance Test scenarios are listed in the report as pending items for PR review, not tested in this loop.

6. **Hard limits prevent infinite loops.** 5 rounds for the main automated loop, 3 rounds for post-manual re-verification. When limits hit, stop and report — the user needs to intervene.

7. **Placeholders re-verified after changes.** When user decisions modify the design or plan, re-check `executable-verification.md` for stale placeholders.

## Reference Files

- `references/verifier-prompt.md` — Verifier subagent dispatch template (Step 1)
- `references/fixer-prompt.md` — Fixer subagent dispatch template (Step 3)
- `references/report-template.md` — Final report template
- `assets/manual-verification.html` — Interactive HTML template for manual testing
