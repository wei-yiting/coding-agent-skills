---
name: code-review-loop
description: >-
  Run a comprehensive post-implementation review/fix loop for a completed
  changeset or PR. Uses isolated reviewer and fixer subagents, checks pragmatism,
  documentation gaps, and external library usage against official docs via
  Context7, then runs final verification and writes a Code Review Improvement
  Report. Use only when the user explicitly requests a broad review such as
  "run code review loop", "review this PR", or "quality gate check". Do not
  use for single-file, quick, or mid-implementation reviews.
---

# Code Review Loop

A multi-round orchestrated review-fix cycle that achieves zero-issue code quality through
**epistemic isolation** — the reviewer and fixer are separate subagents that never share
session context, preventing the bias that occurs when the same agent reviews its own work.

## Why Epistemic Isolation Matters

When the same session that wrote code also reviews it, the agent has full memory of its
reasoning and intentions. This creates blind spots — it "knows what it meant" and glosses
over ambiguity, missing documentation, unclear naming, or subtle logic errors. A fresh
reviewer, seeing the code for the first time, catches what the author cannot.

This skill promotes isolation at two levels:

1. **Session isolation (recommended)**: Ideally, the orchestrator (you) runs in a fresh
   session. If not, ask the user and warn about potential bias — but do not hard-block.
   The human makes the final call.
2. **Subagent isolation (enforced)**: The reviewer and fixer are separate Task dispatches.
   The reviewer never sees the fixer's context, and vice versa. This level is always enforced.

## Relationship to Other Review Skills

| Skill                                | When                            | Scope                             |
| ------------------------------------ | ------------------------------- | --------------------------------- |
| `superpowers/requesting-code-review` | During implementation, per-task | Single task, quick feedback       |
| **This skill** (`code-review-loop`)  | After ALL tasks complete        | Holistic, multi-round, exhaustive |

They are complementary. Per-task reviews catch issues early; this loop catches cross-cutting
concerns, documentation gaps, and library misuse that only become visible when viewing the
full changeset.

## Prerequisites

Before triggering this skill, confirm:

1. **Check for implementation plan** — look for `.artifacts/current/implementation.md`.
   - **If it exists**: confirm all task checkboxes are checked before proceeding.
   - **If it doesn't exist**: warn the user that no implementation plan was found. This is
     acceptable — the skill can also be used for reviewing external PRs, code from other
     workflows, or any changeset the user wants reviewed. If the user confirms they want
     to proceed, continue.
2. **User has validated direction** — The user reviewed the diff and confirmed the approach
   is correct. This loop improves quality, not direction. However, if you notice something
   about the overall direction that seems unreasonable or impragmatic, pause the review and
   raise the concern with the user. Do not blindly assume all directional decisions are
   correct — maintain a critical, objective perspective.
3. **Fresh session check (strong recommendation)** — For best results, run this loop in
   a session that did NOT write the code. Ask the user directly:

   > "Did you write or edit code in this session? For the most objective review,
   > the loop should run in a fresh session."

   If the user confirms this is the coding session, suggest they open a new session with:
   `Read .artifacts/current/implementation.md and start code-review-loop`

   If the user chooses to proceed anyway, continue — the human makes the final call.

## Subagent Profiles

This skill uses two subagents:

- **`code-reviewer`** — Read-only. Can read files, run queries (bash, MCP), but
  cannot write or edit. This prevents scope creep — the reviewer observes and reports,
  never "helpfully" fixes things itself.
- **`code-fixer`** — Has full write/edit/bash/MCP access. Fixes issues and runs tests.

## Output Files

If `.artifacts/current/` already contains review or fix files (`code-review-round-*.md`, `code-fix-round-*.md`, `code-review-improvement-report.md`) from a previous run, archive them first to `.artifacts/archive/{YYYY-MM-DD-HH-MM}-{task-name}/` before starting the new loop.

All artifacts go under `.artifacts/current/`:

```
.artifacts/current/
├── code-review-round-1.md
├── code-fix-round-1.md
├── code-review-round-2.md
├── code-fix-round-2.md
├── ...
└── code-review-improvement-report.md
```

Round and fix files are append-only — never delete or overwrite previous rounds. They form
the audit trail of what was found, what was fixed, and what was declined.

---

## The Loop

### Step 0: Initialize

```
ROUND = 1
MAX_ROUNDS = 5
VERIFICATION_FAILURES = 0
MAX_VERIFICATION_FAILURES = 2
```

1. **If `.artifacts/current/implementation.md` exists**, read it to extract:
   - List of changed files
   - Plan summary (task descriptions)
   - BDD scenarios and verification steps
2. **If no implementation plan exists**, determine the review scope from git:
   - Use `git diff` to identify changed files
   - If the scope is still unclear, ask the user to specify which commits or files to review
   - If the user cannot or will not clarify scope, **STOP**. Inform the user:
     > "Cannot proceed without review scope. Please provide one of:
     >
     > 1. `.artifacts/current/implementation.md`
     > 2. Specific commits or files to review
     > 3. A description of what this changeset does"
     >    Do not proceed to Step 1.
3. Determine git SHAs:
   - `BASE_SHA` = commit before implementation started (from plan or git log)
   - `HEAD_SHA` = current `git HEAD`

### Step 1: Dispatch Reviewer

Read the full prompt template from `resources/reviewer-prompt.md`.

Fill in the template variables:

- `{ROUND}` — current round number
- `{changed_files}` — list of files from Step 0 (from implementation plan or git diff)
- `{BASE_SHA}`, `{HEAD_SHA}` — git SHAs
- `{plan_summary}` — from implementation.md if available. If no implementation plan
  exists and the user hasn't explained the purpose of this code change, **ask the user**
  what this changeset is about before proceeding. The reviewer needs context to give
  meaningful feedback.
- `{previous_round_section}` — empty string if ROUND == 1. If ROUND > 1, the orchestrator
  builds this by reading `code-review-round-{ROUND-1}.md` and `code-fix-round-{ROUND-1}.md`,
  then filling in the template from the "Previous Round Section Templates" section of
  `resources/reviewer-prompt.md`.
- `{previous_round_status_section}` — empty string if ROUND == 1. If ROUND > 1, the
  orchestrator builds this table by:
  1. Reading all issue IDs from `code-review-round-{ROUND-1}.md`
  2. Reading the fixer's report from `code-fix-round-{ROUND-1}.md` to see which issues
     were Fixed vs Not Fixed
  3. Constructing a status table with one row per issue (Fixed / Still Open / Partially
     Fixed), using the template from `resources/reviewer-prompt.md`

Delegate to the **`code-reviewer`** subagent with the filled template as its prompt.

Write the reviewer's output to `.artifacts/current/code-review-round-{ROUND}.md`.

### Step 2: Evaluate Results

Parse the reviewer's output for issue counts by severity.

**Decision tree:**

```
ROUND >= MAX_ROUNDS (5)?
  → STOP. Tell user: "Reached {MAX_ROUNDS} rounds with unresolved issues.
    Please review manually." Attach remaining issues.

Has Blocking or Major issues?
  → Continue to Step 3.

Only Minor issues?
  → Ask user: "{n} minor issues found. Fix them, or skip to final verification?"
    - Fix → Step 3
    - Skip → Step 4

Zero issues?
  → Step 4 (Final Verification)
```

### Step 3: Dispatch Fixer

Before dispatching, the orchestrator classifies each issue from the reviewer's output:

- **Code-fixable** (naming, logic error, missing test, deprecated API, missing docs,
  commented-out code, missing README) → include in fixer dispatch.
- **Architectural** (wrong module boundary, fundamental design flaw, data flow redesign,
  "this module should not exist") → escalate to user:
  > "Issue {ID} requires a design-level decision beyond fixer scope.
  > Options: (a) provide direction for fixer to follow, (b) defer to backlog, (c) dismiss."
  > Wait for user response. Only include user-directed architectural items in the dispatch.

Read the full prompt template from `resources/fixer-prompt.md`.

Fill in template variables:

- `{issues_content}` — the Issues section from `code-review-round-{ROUND}.md`
- `{round}` — current round number

Delegate to the **`code-fixer`** subagent with the filled template as its prompt.

After fixer completes:

- Write the fixer's output to `.artifacts/current/code-fix-round-{ROUND}.md`
- Increment `ROUND += 1`
- Return to **Step 1** (reviewer confirms fixes and does fresh review)

### Step 4: Final Verification

Run the verification levels yourself (the orchestrator). Read `resources/verification-checklist.md`
for the full checklist structure and all verification levels (Code, BDD, E2E).

**Any failure** →

1. Increment `VERIFICATION_FAILURES += 1`
2. If `VERIFICATION_FAILURES >= MAX_VERIFICATION_FAILURES` (2):
   → **STOP.** Tell user: "Verification failed {N} times on persistent items.
   Manual intervention required." Attach the remaining failing items.
3. Otherwise: package failed items as an issue list → Step 3 (fixer) → Step 1
   (reviewer confirms). The verification failure becomes a new review round.

Verification failures consume `VERIFICATION_FAILURES`, not `ROUND`. This prevents
verification loops from exhausting the review budget — they are separate concerns.

**All pass** → Step 5.

### Step 5: Write Improvement Report

Read the template from `resources/report-template.md`.

Fill in all sections with data collected across rounds:

- Round-by-round summary
- Critical fixes table
- Library usage corrections (Context7)
- Documentation improvements
- Unaddressed suggestions
- Final verification results
- Complete changed files manifest

Write to `.artifacts/current/code-review-improvement-report.md`.

### Step 6: Notify User

Present a concise summary:

```
Code Review Loop complete.

{ROUND} round(s) | {total} issues found and fixed
  Blocking: {n} | Major: {n} | Minor: {n}
  Library corrections: {n} | Documentation fixes: {n}
  All verification passed ✓

Report: .artifacts/current/code-review-improvement-report.md
Round details: .artifacts/current/code-review-round-{1..N}.md
Fix details: .artifacts/current/code-fix-round-{1..N}.md

Please do your own final verification.
After confirming, say "done" to archive all artifacts.
```

---

## Rules

1. **Fresh session (recommended, not enforced)** — Running in a fresh session produces
   better reviews because the orchestrator has no memory of implementation decisions.
   Ask the user whether this is a fresh session. If not, suggest opening a new one but
   continue if they choose to proceed — the human makes the final call.

2. **Separate subagents** — Reviewer and fixer are dispatched via Task tool as independent
   sessions. They never share context. Each dispatch is a clean slate.

3. **Reviewer is read-only** — The reviewer can read files and run queries (bash, MCP) but
   cannot write or edit. This is enforced by tool configuration. If read-only isn't
   enforceable, instruct the reviewer explicitly: "You are read-only. Do not modify files."

4. **Context7 verification** — Round 1: the reviewer queries Context7 for every external
   library used in the changes. Subsequent rounds: only re-query libraries whose usage
   was changed or newly introduced by the fixer. This catches deprecated APIs, reinvented
   wheels, and non-idiomatic usage without wasting queries on unchanged code.

5. **Review Standards** — The reviewer enforces pragmatic code standards embedded in
   `resources/reviewer-prompt.md`: YAGNI, readability, comments, documentation, zero
   tolerance for code cruft, and Context7-verified library usage.

6. **Max 5 rounds** — If issues persist after 5 rounds, stop and hand off to the user.
   Infinite loops waste time; the human needs to intervene.

7. **Verification is a hard gate** — No issue can be marked "resolved" without passing
   verification. The fixer says it's fixed; the reviewer confirms; verification proves it.

8. **Preserve all records** — Never delete or overwrite round files or fix files. They
   form the audit trail. The improvement report references them.

9. **Improvement Report** — Every completed loop produces a summary report. For clean
   reviews (zero issues), keep it brief — a summary table and verification results are
   sufficient. Only include detailed sections (Library Corrections, Documentation
   Improvements, etc.) when there's actual content for them.

## Resource Files Reference

| File                                  | Purpose                           | When to Read        |
| ------------------------------------- | --------------------------------- | ------------------- |
| `resources/reviewer-prompt.md`        | Reviewer subagent prompt template | Step 1 (each round) |
| `resources/fixer-prompt.md`           | Fixer subagent prompt template    | Step 3 (each round) |
| `resources/report-template.md`        | Improvement report structure      | Step 5              |
| `resources/verification-checklist.md` | Final verification checklist      | Step 4              |
