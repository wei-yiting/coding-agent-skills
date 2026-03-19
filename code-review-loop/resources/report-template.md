# Code Review Improvement Report Template

Use this template in Step 5 to produce the final report.
Replace all `{variables}` with actual data collected across rounds.

**Keep it proportional:**
- **Clean reviews (0-2 issues):** Only include Summary, Final Verification Results,
  and All Changed Files.
- **Reviews with issues:** Keep all section headings. For sections that were reviewed but
  had no findings, write "None" under the heading — this confirms the area was checked.
  Only omit a section entirely if it was not applicable to this review.

---

```markdown
# Code Review Improvement Report

> **Task:** {task_name}
> **Date:** {date}
> **Rounds:** {total_rounds}
> **Reviewer model:** {reviewer_model}
> **Fixer model:** {fixer_model}

## Summary

| Metric                         | Value                                     |
| ------------------------------ | ----------------------------------------- |
| Total rounds                   | {N}                                       |
| Total issues found             | {total}                                   |
| Blocking                       | {blocking_count} (all resolved)           |
| Major                          | {major_count} (all resolved)              |
| Minor                          | {minor_fixed}/{minor_total}               |
| Suggestions                    | {suggestions_adopted}/{suggestions_total} |
| Library corrections (Context7) | {library_corrections}                     |
| Documentation gaps addressed   | {doc_fixes}                               |

## Round-by-Round Summary

### Round 1

- **Found:** {n} issues (Blocking: {n}, Major: {n}, Minor: {n}, Suggestion: {n})
- **Key findings:**
  1. {finding_1}
  2. {finding_2}

### Round 2

- **Previous fixes confirmed:** {confirmed}/{total_from_round_1}
- **New issues found:** {n}
- **Key findings:**
  1. {finding}

{repeat for each round}

## Critical Fixes

The most impactful changes made during the review loop:

| #   | Severity   | File     | Problem   | Fix   | Impact                                |
| --- | ---------- | -------- | --------- | ----- | ------------------------------------- |
| 1   | {severity} | `{file}` | {problem} | {fix} | {impact on correctness/security/perf} |

## Library Usage Corrections

Issues where the code deviated from official library documentation:

| #   | Library | Original Approach   | Correct Approach    | Context7 Source |
| --- | ------- | ------------------- | ------------------- | --------------- |
| 1   | {lib}   | {what the code did} | {what it should do} | {doc reference} |

## Documentation Improvements

Folders where README.md was added or improved:

| Folder   | What Was Added/Fixed                                                       |
| -------- | -------------------------------------------------------------------------- |
| `{path}` | {description — e.g., "Added README with Scope, Map, Extension Guidelines"} |

## Unaddressed Suggestions

Suggestions from the reviewer that were not implemented, with rationale:

| #   | Content      | Reason Not Addressed                                          |
| --- | ------------ | ------------------------------------------------------------- |
| 1   | {suggestion} | {reason — e.g., "Out of scope", "Requires design discussion"} |

## Final Verification Results

### Code Level

- [ ] Unit Tests: {pass}/{total}
- [ ] Integration Tests: {pass}/{total}
- [ ] Lint: {errors} errors, {warnings} warnings
- [ ] Type Check: {pass/fail}

### Behavior Level (BDD)

- [ ] {scenario_name}: {pass/fail}
- [ ] {scenario_name}: {pass/fail}

### Observable Level (E2E)

- [ ] {verification_description}: {actual_result}
- [ ] {verification_description}: {actual_result}

## All Changed Files

Complete manifest of every file touched during implementation and review fixes:

| File     | Implementation Change                | Review Fix                           |
| -------- | ------------------------------------ | ------------------------------------ |
| `{path}` | {what changed during implementation} | {what changed during review, or "—"} |
```
