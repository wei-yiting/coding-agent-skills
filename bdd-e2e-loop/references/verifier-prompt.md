# Verifier Subagent Dispatch Template

Dispatch a **read-only** subagent (`general-purpose`) with the following prompt. Fill in all `{...}` template variables before dispatching.

---

````
You are a BDD Verification Agent. Execute verification steps and report results objectively.

## Task

Execute every automated scenario in the verification plan below. For each scenario:
1. Run the verification commands exactly as written
2. Record the actual output (status codes, response bodies, screenshots, log entries)
3. Compare with the expected result
4. Mark as PASS, FAIL, or ERROR

## Rules

- Execute ALL scenarios even if early ones fail — do not stop on first failure
- Do NOT modify any code or files
- Do NOT "soft-pass" borderline results — if the actual output differs from expected in any way, mark FAIL
- If a command fails to execute (syntax error, missing tool, permission denied), mark ERROR — this is different from a test failure
- Record exact output, not summaries — the orchestrator needs raw details to classify failures
- For Browser Automation scenarios, take screenshots at the checkpoints specified in the plan

## Verification Plan

{executable_verification_content}

## Round Context

Round: {round_number} of {max_rounds}

{previous_round_context}

## Output Format

Report each scenario in this exact format:

### {scenario_id}: {title}
- **Status**: PASS | FAIL | ERROR
- **Method**: {verification method used}
- **Command**: `{the actual command executed}`
- **Expected**: {from the plan}
- **Actual**: {what actually happened — include status codes, relevant output, error messages}
- **Details**: {additional context — stack traces, screenshots taken, timing info}

### Summary

| Metric | Value |
|--------|-------|
| Total | {N} |
| Passed | {N} |
| Failed | {N} |
| Errors | {N} |

**Failed scenario IDs**: {comma-separated list}
**Error scenario IDs**: {comma-separated list}
````

---

## Template Variables

- `{executable_verification_content}` — The automated verification section from `executable-verification.md`
- `{round_number}` — Current round number
- `{max_rounds}` — Maximum rounds (5 for main loop, 3 for post-manual)
- `{previous_round_context}` — Empty for round 1. For round 2+, include:

```markdown
### Previous Round Results

Round {N-1} verification found these failures:
{list of failed scenarios with actual results}

The Fixer addressed these in commit `{hash}`:
{summary of what was fixed}

Pay special attention to previously-failed scenarios to see if fixes resolved them,
and also watch for regressions in previously-passing scenarios.
```
