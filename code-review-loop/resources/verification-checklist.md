# Final Verification Checklist

Run this checklist in Step 4 of the loop. The orchestrator (you) executes these checks
directly — do not delegate verification to a subagent. You need to see the results
firsthand to make the pass/fail decision.

**Graceful degradation with proactive proposal:** Not all projects define BDD scenarios
or E2E verification steps in `implementation.md`. The minimum required level is Code Level
(tests + lint). However, for a complete code change, BDD or E2E verification should exist.

If BDD or E2E verification steps are missing:

1. **Warn the user** — explain that no BDD/E2E verification was found and why this matters
2. **Propose test cases** — observe the codebase for obvious behaviors or end-to-end flows
   that should be tested, and propose specific test cases to the user
3. **Proceed only after user confirmation** — discuss the proposed test cases with the user
   before running them

Every item that exists must pass. Any failure triggers a new fix round, subject to the
`VERIFICATION_FAILURES` counter (initialized in Step 0). Each time verification fails
and loops back to fixer, increment this counter. If it reaches `MAX_VERIFICATION_FAILURES`
(default: 2), stop the loop and escalate to the user instead of re-entering the fix cycle.
This counter is separate from `ROUND` — verification loops do not consume review rounds.

---

## Level 1: Code Level

These are automated checks. Run each command and record the result.

### Unit Tests

```bash
# Run the project's test suite (adapt command to project)
# Common: pytest, npm test, cargo test, go test ./...
{test_command}
```

- Record: `{pass_count}/{total_count}` tests passing
- **Fail condition**: Any test failure that wasn't pre-existing before the implementation

### Integration Tests

```bash
# If the project has integration tests separate from unit tests
{integration_test_command}
```

- Record: `{pass_count}/{total_count}`
- **Fail condition**: Any new failure

### Lint

```bash
# Run the project's linter
# Common: eslint, ruff, clippy, golangci-lint
{lint_command}
```

- Record: `{error_count}` errors, `{warning_count}` warnings
- **Fail condition**: Any lint error introduced by the implementation or review fixes
- Pre-existing lint errors don't count — only new ones

### Type Check

```bash
# Run the type checker
# Common: tsc --noEmit, mypy, pyright
{typecheck_command}
```

- Record: pass or fail
- **Fail condition**: Any type error introduced by the changes

---

## Level 2: Behavior Level (BDD)

BDD scenario source priority:

1. `artifacts/current/bdd-validation.md` (produced by the `bdd-test-planning` skill) — authoritative, cross-validates with the implementation plan.
2. BDD scenarios in `implementation.md` — fallback if `bdd-validation.md` does not exist.
3. **Self-derived** — if neither source exists, warn the user that no behavioral verification is available, then derive scenarios from the codebase yourself. Propose them to the user, proceed after confirmation, and record all proposed and executed scenarios in the report (see report template's "Behavioral Validation" section).

For each scenario:

1. Read the scenario description from `implementation.md`
2. Execute the described steps (may involve running scripts, making API calls, etc.)
3. Verify the expected outcome matches actual behavior

```
Scenario: {scenario_name}
  Given: {precondition}
  When: {action}
  Then: {expected_outcome}
  Result: {PASS / FAIL — actual_outcome}
```

- **Fail condition**: Expected outcome does not match actual outcome

---

## Level 3: Observable Level (E2E)

E2E verification step source priority:

1. Observable Verification section of `artifacts/current/bdd-validation.md`.
2. E2E verification steps in `implementation.md`.
3. **Self-derived** — if neither source exists, warn the user, derive verification steps from the codebase, propose them, and proceed after confirmation. Record in the report.

For each verification step:

1. Read the verification instruction from `implementation.md`
2. Execute it (curl command, browser check, MCP call, script execution)
3. Record the actual result

```
Verification: {description}
  Command: {what to run}
  Expected: {what should happen}
  Actual: {what actually happened}
  Result: {PASS / FAIL}
```

- **Fail condition**: Actual result doesn't match expected result

---

## Handling Failures

If any check fails:

1. **Classify the failure:**
   - Caused by the implementation → needs fixing
   - Caused by a review fix → needs fixing
   - Pre-existing (existed before implementation) → document but don't fix

2. **Package failures as issues** using the reviewer's format:

```
### [Blocking] V-{ROUND}.{N}: Verification failure — {title}
- **File:** `{path}` (if identifiable)
- **Problem:** {test/check} failed with: {error message}
- **Expected:** {expected behavior}
- **Actual:** {actual behavior}
```

3. **Increment `VERIFICATION_FAILURES += 1`**

4. **Check limit**: if `VERIFICATION_FAILURES >= MAX_VERIFICATION_FAILURES`, stop and
   escalate to the user with the remaining failing items. Do not re-enter the fix cycle.

5. **Dispatch to fixer** (Step 3) with these verification-sourced issues

6. **After fixer completes**, return to Step 1 (reviewer) for a confirmation round,
   then re-run this verification checklist

---

## Pre-Existing Issues

If you discover failures that existed before the implementation started:

- Document them separately in the improvement report
- Do NOT attempt to fix them (out of scope)
- Format: "Note: {n} pre-existing {test/lint} failures unrelated to this implementation"
