# Stage 1 Prompt — Automated Verification (Docker)

This prompt is sent to the Docker Claude Code session via `claude -p`. Fill in all `{...}` template variables before dispatching.

The launcher script (`scripts/bdd-sandbox.sh`) reads this file, substitutes variables, and pipes it to `claude -p --dangerously-skip-permissions`.

---

````
You are running inside a Docker sandbox to execute BDD automated verification. Your task is to run the automated verification loop and produce a structured JSON report. Do NOT enter the manual verification phase.

## Context

- Working directory: /workspace (mounted from host project)
- Claude config: {container_home}/.claude
- Network:
  - For services you **start inside this container** (e.g. `pnpm run dev`), use `localhost`
  - For services running on the **host machine**, use `host.docker.internal`
- `browser-use` CLI is installed for Browser Automation scenarios
- Playwright + Chromium are installed for Node E2E tests (`pnpm run test:e2e`)

## Browser-Use CLI Reference

For Browser Automation scenarios, use the `browser-use` CLI (NOT Playwright test files). Key commands:

```
browser-use open <url>              # Navigate to URL (also navigates within existing session)
browser-use state                   # Get page state (URL, title, visible elements)
browser-use screenshot [path]       # Screenshot (base64 if no path)
browser-use eval "<js>"             # Execute JavaScript
browser-use get text <index>        # Get element text by index from state
browser-use wait text "<text>"      # Wait for text to appear
browser-use wait selector "<sel>"   # Wait for CSS selector
browser-use click <index|x y>      # Click element by index or coordinates
browser-use input <index> "<text>"  # Type text into an input element
browser-use python --file <path>    # Run Python script within the browser session
browser-use close                   # Close browser session (call ONCE at end)
```

### CRITICAL: Single-Session Strategy

browser-use uses a daemon architecture that **cannot reliably restart** in Docker. Once a session is closed, opening a new one often hangs due to stale daemon state files.

**Rule: Open the browser ONCE and keep the session alive for ALL Browser Automation scenarios.** Navigate between scenarios with `browser-use open <new-url>` (this navigates the existing tab, it does NOT require closing). Only call `browser-use close` once at the very end.

For complex multi-step scenarios, use `browser-use python --file`:

```python
# /tmp/verify_v2_01.py — runs inside the existing browser session
import time
browser.goto("http://localhost:5173/chat")
browser.wait_for_selector("[data-testid='empty-state']")
browser.screenshot("/tmp/v2-01-empty.png")
browser.fill("[data-testid='composer-textarea']", "Briefly explain NVIDIA Blackwell architecture")
browser.click("[data-testid='composer-send-btn']")
browser.wait_for_selector("[data-testid='message-list'][data-status='ready']", timeout=60000)
browser.screenshot("/tmp/v2-01-complete.png")
print("PASS: V2-01 completed")
```

Execute: `browser-use python --file /tmp/verify_v2_01.py`

If browser-use fails on first open, do a nuclear cleanup (must remove `state.json`):
```bash
pkill -9 -f chromium 2>/dev/null; pkill -9 -f "browser_use" 2>/dev/null
rm -rf ~/.browser-use/            # entire dir, not just sessions/
rm -rf /tmp/browser-use-* /tmp/.org.chromium.*
sleep 2
browser-use open <url>
```

## Docker Environment Best Practices

This container is resource-constrained compared to the host. Follow these rules to avoid wasting rounds on environment issues:

1. **Do NOT pipe long-running test commands through `tail` / `head` / `grep`.** Test suites run 2–5× slower in Docker than on the host. Piped commands may be auto-backgrounded before output flushes, producing empty results. Run the full command and let it complete:
   ```bash
   # BAD — may produce empty output
   npx vitest run 2>&1 | tail -80
   # GOOD
   npx vitest run 2>&1
   ```

2. **Vitest test timeout.** Default 5000ms is too short in Docker. Always use extended timeout:
   ```bash
   npx vitest run --test-timeout=30000
   ```

3. **Run Playwright E2E tests with `--workers=1`.** Multiple headless Chromium instances competing for limited Docker CPU/memory cause timeouts:
   ```bash
   npx playwright test --workers=1
   ```

4. **Do NOT manually start the dev server for Playwright E2E tests.** Playwright's `webServer` config in `playwright.config.ts` automatically starts the dev server. Just run `npx playwright test`.

5. **Execution order: Deterministic FIRST, then Browser Automation.** Playwright and browser-use share Chromium. browser-use's daemon can leave zombie chrome processes that break Playwright. Always run in this order:
   1. Vitest (unit/component/hook/integration)
   2. Playwright E2E (e2e-tier0)
   3. Browser Automation (browser-use) — LAST
   
   After browser-use finishes, do NOT re-run Playwright unless you first kill all chrome processes:
   ```bash
   pkill -9 -f chromium 2>/dev/null; sleep 2
   ```

6. **Vite proxy target for host backend.** The `VITE_API_TARGET` environment variable is pre-set to `http://host.docker.internal:8000`. If the project's `vite.config.ts` hardcodes `localhost` as the API proxy target, update it to:
   ```ts
   proxy: {
     '/api': {
       target: process.env.VITE_API_TARGET || 'http://localhost:8000',
       changeOrigin: true,
     }
   }
   ```
   For Deterministic scenarios using MSW, the proxy target is irrelevant — MSW intercepts requests before they reach the proxy.

7. **Do NOT waste tool calls exploring the project.** Skip `Agent` subagents for codebase exploration. Read the verification plan and BDD scenarios directly, then run tests. The project structure is already described in those artifacts.

## Step 0: Preparation

1. Install project dependencies: `{install_cmd}`
2. Check if `artifacts/current/executable-verification.md` already exists:
   - **If it exists**: Read it and use it directly as the verification plan. Skip placeholder resolution — the host session already resolved all `[POST-CODING: ...]` placeholders.
   - **If it does NOT exist**: Read `artifacts/current/{verification_plan_file}` and `artifacts/current/{bdd_scenarios_file}`, resolve all `[POST-CODING: ...]` placeholders by inspecting the codebase, and write the result to `artifacts/current/executable-verification.md`.
3. If a placeholder cannot be resolved (expected code structure doesn't exist), mark that scenario as ERROR in the report
4. Separate automated scenarios (Deterministic + Browser Automation) from manual scenarios (Manual Behavior Test + User Acceptance Test)
5. Create `artifacts/current/temp/` directory if it doesn't exist

## Automated Verification Loop

```
ROUND = 1
MAX_ROUNDS = {max_rounds}
FIX_HISTORY = []
TARGETED_SCENARIOS = []   # empty = run all (Round 1)
```

**CRITICAL: No git operations.** NEVER run `git init`, `git add`, `git commit`, `git status`, or any git command. The /workspace directory may be a git worktree with a .git pointer to a host path that does not exist inside this container. Any git operation risks destroying the host's git history. All fix tracking is file-based via `artifacts/current/temp/fix-history.json`.

### Round 1: Full Suite

Run ALL automated scenarios. For each scenario:
1. Execute the verification commands exactly as written in `executable-verification.md`
2. Record the actual output (status codes, response bodies, log entries)
3. Compare with expected result
4. Mark as PASS, FAIL, or ERROR

Save results to `artifacts/current/temp/bdd-verification-round-1.md`.

If all pass → exit with `ALL_AUTO_PASS`.

If failures exist → classify, fix (see Fix and Classify sections below), set `TARGETED_SCENARIOS` to failed IDs, `ROUND++`.

### Round N (N > 1): Two-Phase Verification

#### Phase 1 — Targeted Verification

Run **only `TARGETED_SCENARIOS`** — the scenarios that failed last round and were supposedly fixed.

Save results to `artifacts/current/temp/bdd-verification-round-{ROUND}.md`.

**If any targeted scenario still fails:**
1. Classify using the escalation ladder below
2. Level 3 (design issue / technical limitation) → record with `user_decision: null`, exit with `DESIGN_ISSUES`
3. Level 1-2 (implementation bug) → fix → `ROUND++` → repeat Phase 1
4. If `ROUND >= MAX_ROUNDS` → exit with `MAX_ROUNDS_HIT`

**If all targeted scenarios pass** → proceed to Phase 2.

#### Phase 2 — Regression Check

Run **ALL automated scenarios** (full suite).

**If new failures (regressions):**
→ Classify, fix → set `TARGETED_SCENARIOS` to regressed IDs → `ROUND++` → back to Phase 1

**If all pass** → exit with `ALL_AUTO_PASS`.

### Failure Classification

**Level 1 — Implementation bug (fix it):**
- Runtime error, stack trace, crash
- HTTP 5xx server error
- Wrong response format or missing fields vs. explicit design spec
- Feature produces no output or visibly broken output

**Level 2 — Ambiguous (default to implementation bug, try fixing):**
- Feature responds but result doesn't match expected
- Partially correct output
- Inconsistent behavior across runs

**Level 3 — Design issue (escalate, only with evidence):**
- Same scenario fails for 2+ consecutive rounds despite fix attempts
- Code logic is correct but scenario expectation seems wrong
- Fixing scenario A breaks scenario B (conflicting expectations)

### Fix Implementation Bugs

For all scenarios classified as Level 1-2:

1. Fix the code — minimal changes, fix the bug only, don't refactor
2. Run the project's unit tests — all tests must pass before the fix is accepted
3. Record: what was fixed (root cause + fix description), files changed
4. If you believe a scenario's expectation is wrong, record it as "Not Fixed" with reason
5. Append fix details to `artifacts/current/temp/fix-history.json` (create if doesn't exist, append to the array)

**Do NOT run any git commands.** Fix tracking is entirely file-based.

Important:
- Review FIX_HISTORY before fixing — do NOT repeat approaches that already failed in previous rounds
- If a scenario failed in a previous round and the previous fix didn't work, try a DIFFERENT approach

### Verification Rules

- Do NOT "soft-pass" borderline results — if actual differs from expected in any way, mark FAIL
- If a command fails to execute (syntax error, missing tool, permission denied), mark ERROR
- Record exact output, not summaries
- In Phase 2, if a previously-passing scenario now fails, flag it as REGRESS

## Cleanup (MANDATORY — execute before writing report)

Before writing the final report, you MUST clean up ALL temporary test fixtures created during verification:

1. **Test scenario directories**: Remove any directories created under the project's scenarios folder (e.g. `_test_*`, `bdd*`, `tcsv*`, `v1_quality`, `v2_quality`, etc.)
2. **Test helper modules**: Remove any temporary Python/JS files created for mock tasks or scorers (e.g. `_test_tasks.py`, `_test_scorer.py`)
3. **Test result CSVs**: Remove any result files generated by test scenarios (not the real scenario results)
4. **Verify cleanup**: Run `ls` on the scenarios directory and results directory to confirm only the original project files remain

Do NOT skip cleanup even if you are about to exit due to MAX_ROUNDS_HIT or errors.

## Output

When the loop completes (and after cleanup), write `artifacts/current/temp/auto-stage-report.json` following this exact structure:

```json
{
  "status": "<ALL_AUTO_PASS | DESIGN_ISSUES | MAX_ROUNDS_HIT>",
  "rounds_completed": <N>,
  "max_rounds": {max_rounds},
  "timestamp": "<ISO 8601>",

  "scenarios": {
    "<scenario-id>": {
      "title": "<scenario title>",
      "type": "<Deterministic | Browser Automation | Manual Behavior Test | User Acceptance Test>",
      "rounds": {
        "<round-number>": {
          "status": "<PASS | FAIL | ERROR | REGRESS>",
          "expected": "<expected result>",
          "actual": "<actual result>",
          "details": "<additional context or null>"
        }
      },
      "final_status": "<PASS | FAIL | ERROR | PENDING>",
      "first_pass_round": "<number or null>",
      "ever_failed": <true | false>
    }
  },

  "fix_history": [
    {
      "round": <N>,
      "fixes": [
        {
          "scenario_id": "<id>",
          "root_cause": "<why it was failing>",
          "fix_description": "<what was changed>",
          "files_changed": ["<file paths>"]
        }
      ],
      "not_fixed": [
        {
          "scenario_id": "<id>",
          "reason": "<why not fixed>"
        }
      ],
      "tests_run": [
        {
          "command": "<test command>",
          "result": "<PASS | FAIL>",
          "notes": "<details or null>"
        }
      ]
    }
  ],

  "design_issues": [
    {
      "scenario_id": "<id>",
      "title": "<scenario title>",
      "conflict": "<expected vs actual>",
      "consecutive_failures": <N>,
      "analysis": "<why this is a design issue>",
      "user_decision": null
    }
  ],

  "regressions": [
    {
      "scenario_id": "<id>",
      "regressed_in_round": <N>,
      "was_passing_since_round": <N>,
      "cause": "<what likely caused it>"
    }
  ]
}
```

Include ALL scenarios in the `scenarios` object — both automated (with round data) and manual/UAT (with `final_status: "PENDING"` and empty `rounds`).

After writing the JSON, also write a human-readable summary to stdout so the launcher script can display progress:

```
=== BDD Stage 1 Complete ===
Status: <status>
Rounds: <N> / {max_rounds}
Passed: <N> / <total automated>
Failed: <N>
Design Issues: <N>
Regressions: <N>
Report: artifacts/current/temp/auto-stage-report.json
```
````

---

## Template Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `{max_rounds}` | Default: 5. Set to 3 for post-manual re-verification runs. | Maximum verification rounds |
| `{container_home}` | From bdd-sandbox.sh, e.g. `/home/bdduser` | Non-root user's home directory in container |
| `{install_cmd}` | Auto-detected by bdd-sandbox.sh based on lock files | Dependency install command (e.g. `uv sync`, `cd frontend && pnpm install`) |
| `{verification_plan_file}` | Auto-detected filename (e.g. `verification_plan.md` or `verification_plan_s1_backend.md`) | Basename of verification plan artifact |
| `{bdd_scenarios_file}` | Auto-detected filename (e.g. `bdd_scenarios.md` or `bdd_scenarios_s1_backend.md`) | Basename of BDD scenarios artifact |
