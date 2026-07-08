---
name: code-review-loop
description: >-
  Run a comprehensive post-implementation review/fix loop for a completed changeset or PR:
  isolated reviewer and fixer subagents, two review axes (code quality/standards and spec
  conformance against the implementation plan or issue), pragmatism and documentation-gap
  checks, external library usage verified against official docs via Context7, final
  verification, and a written Code Review Improvement Report. Use only when the user explicitly requests a broad review or
  quality gate; not for single-file, quick, or mid-implementation reviews.
---

# Code Review Loop

A multi-round orchestrated review-fix cycle that achieves zero-issue code quality through
**epistemic isolation** — the reviewer and fixer are separate subagents that never share
session context, preventing the bias that occurs when the same agent reviews its own work.

The review runs along **two axes**, each owned by its own reviewer:

- **Quality/Standards** — is the code well built? (pragmatism, readability, smell
  baseline, documentation, library usage)
- **Spec conformance** — is it the *right* code? (checked against the originating spec:
  nothing missing, no scope creep, nothing misimplemented)

A change can pass one axis and fail the other — code that follows every standard but
implements the wrong thing, or code that does exactly what the issue asked while breaking
conventions. The axes are reviewed and reported separately so a severe finding on one
never masks or reranks the other.

## Output Language Convention

- **Reviewer and fixer subagents** produce output in English. Their round files (`review-round-*.md`, `fix-round-*.md`) are intermediate artifacts consumed by the orchestrator — no translation needed.
- **Final report** (`code-review-improvement-report.md`) and **user-facing chat notifications** (Step 6) use Traditional Chinese (zh-TW) with English technical terms (file paths, function names, CLI commands, code snippets, issue IDs, severity labels).

## Why Epistemic Isolation Matters

When the same session that wrote code also reviews it, the agent has full memory of its
reasoning and intentions. This creates blind spots — it "knows what it meant" and glosses
over ambiguity, missing documentation, unclear naming, or subtle logic errors. A fresh
reviewer, seeing the code for the first time, catches what the author cannot.

This skill promotes isolation at three levels:

1. **Session isolation (recommended)**: Ideally, the orchestrator (you) runs in a fresh
   session. If not, ask the user and warn about potential bias — but do not hard-block.
   The human makes the final call.
2. **Subagent isolation (enforced)**: The reviewer and fixer are dispatched independently.
   The reviewer never sees the fixer's context, and vice versa. This level is always enforced.
3. **Model isolation (preferred)**: When Codex is available, the reviewer (Codex/GPT) and
   fixer (Claude) use different model providers. Different training distributions produce
   different blind spots, making the review more thorough than same-model isolation alone.

## Relationship to Other Review Skills

| Skill                               | When                            | Scope                             |
| ----------------------------------- | ------------------------------- | --------------------------------- |
| Per-task review (inside `subagent-driven-development`) | During implementation, per-task | Single task, quick feedback |
| **This skill** (`code-review-loop`) | After ALL tasks complete        | Holistic, multi-round, exhaustive |

They are complementary. Per-task reviews catch issues early; this loop catches cross-cutting
concerns, documentation gaps, and library misuse that only become visible when viewing the
full changeset.

## Prerequisites

Before triggering this skill, confirm:

1. **Check for implementation plan** — look for `artifacts/current/implementation.md`.
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
   `Read artifacts/current/implementation.md and start code-review-loop`

   If the user chooses to proceed anyway, continue — the human makes the final call.

## Subagent Profiles

This skill uses two subagents with different providers for **cross-model isolation**:

- **`code-reviewer`** — **Codex** (preferred) or Claude (fallback). Read-only.
  - **Codex mode:** Dispatched via `codex:rescue` (default read-only sandbox). Cannot
    write or edit files — enforced at sandbox level.
  - **Claude fallback:** Dispatched via Task tool with read-only instruction. Used when
    Codex is unavailable.
  - Cross-model review adds training distribution isolation on top of session isolation —
    different models have different blind spots.
- **`code-fixer`** — **Claude** subagent via Task tool. Has full write/edit/bash/MCP access.
  Fixes issues and runs tests.

## Output Files

If `artifacts/current/` already contains review loop artifacts (`code-review-loop/` directory, `code-review-improvement-report.md`) from a previous run, archive them first to `artifacts/archive/{YYYY-MM-DD-HH-MM}-{task-name}/` before starting the new loop.

All artifacts go under `artifacts/current/`:

```
artifacts/current/
├── code-review-loop/
│   ├── review-round-1.md
│   ├── fix-round-1.md
│   ├── review-round-2.md
│   ├── fix-round-2.md
│   └── ...
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
REVIEWER_PROVIDER = "codex" | "claude"
```

1. **Check Codex availability** — attempt to verify Codex is ready (e.g., check that the
   `codex:rescue` skill is available and Codex CLI is installed). Set `REVIEWER_PROVIDER`:
   - **Available** → `REVIEWER_PROVIDER = "codex"` (cross-model review)
   - **Unavailable** → `REVIEWER_PROVIDER = "claude"` (same-model fallback).
     Inform the user: "Codex 不可用，將使用 Claude 作為 reviewer（同 model review）。"
2. **If `artifacts/current/implementation.md` exists**, read it to extract:
   - List of changed files
   - Plan summary (task descriptions)
   - BDD scenarios and verification steps
3. **If no implementation plan exists**, determine the review scope from git:
   - Use `git diff` to identify changed files
   - If the scope is still unclear, ask the user to specify which commits or files to review
   - If the user cannot or will not clarify scope, **STOP**. Inform the user:
     > "Cannot proceed without review scope. Please provide one of:
     >
     > 1. `artifacts/current/implementation.md`
     > 2. Specific commits or files to review
     > 3. A description of what this changeset does"
     >    Do not proceed to Step 1.
4. Determine git SHAs:
   - `BASE_SHA` = commit before implementation started (from plan or git log)
   - `HEAD_SHA` = current `git HEAD`
5. **Determine the spec source** for the Spec axis (priority order, per
   `resources/spec-reviewer-prompt.md`): `implementation.md` (+ `bdd-scenarios.md` if
   present) → Linear issue description → user-supplied spec/description. If none exists,
   the Spec axis is skipped for the whole loop — note this in the final report.

### Step 1: Dispatch Reviewers

Read the full prompt template from `resources/reviewer-prompt.md`.

Fill in the template variables:

- `{ROUND}` — current round number
- `{changed_files}` — list of files from Step 0 (from implementation plan or git diff)
- `{BASE_SHA}`, `{HEAD_SHA}` — git SHAs
- `{model}` — the actual model that will run the review. The reviewer must not
  self-identify; the orchestrator resolves this value and substitutes it so the
  output accurately reflects what was used.
  - **Codex:** Read `~/.codex/config.toml` and grep `^model\s*=\s*"..."`. If the
    working directory has a trusted `.codex/config.toml` with a `model` override,
    prefer that. If the orchestrator explicitly dispatches with `--model <name>`
    (or `--model spark`, which maps to `gpt-5.3-codex-spark`), use that override
    instead. If nothing is resolvable, use `"codex (model unknown)"`.
  - **Claude:** Use the Claude model identifier of the subagent that will run
    the review (e.g., `claude-opus-4-7`, `claude-sonnet-4-6`). Fall back to
    `"claude (model unknown)"` only if the identifier is genuinely unavailable.
- `{date}` — today's date in ISO format (`YYYY-MM-DD`).
- `{plan_summary}` — from implementation.md if available. If no implementation plan
  exists and the user hasn't explained the purpose of this code change, **ask the user**
  what this changeset is about before proceeding. The reviewer needs context to give
  meaningful feedback.
- `{previous_round_section}` — empty string if ROUND == 1. If ROUND > 1, the orchestrator
  builds this by reading `code-review-loop/review-round-{ROUND-1}.md` and `code-review-loop/fix-round-{ROUND-1}.md`,
  then filling in the template from the "Previous Round Section Templates" section of
  `resources/reviewer-prompt.md`.
- `{previous_round_status_section}` — empty string if ROUND == 1. If ROUND > 1, the
  orchestrator builds this table by:
  1. Reading all issue IDs from `code-review-loop/review-round-{ROUND-1}.md`
  2. Reading the fixer's report from `code-review-loop/fix-round-{ROUND-1}.md` to see which issues
     were Fixed vs Not Fixed
  3. Constructing a status table with one row per issue (Fixed / Still Open / Partially
     Fixed), using the template from `resources/reviewer-prompt.md`
- `{library_verification_instructions}` — filled based on `REVIEWER_PROVIDER`. See
  "Library Verification Instructions Templates" in `resources/reviewer-prompt.md`.
  - **Codex:** Orchestrator pre-fetches Context7 data before dispatch. Scan changed files
    for external library imports, query Context7 for each (≤500 tokens per library, scoped
    to APIs actually used), and inject the results. Round 2+: only re-query libraries
    whose usage was modified by the fixer.
  - **Claude:** Insert direct Context7 query instructions (the reviewer queries Context7
    itself during review).

**Dispatch based on `REVIEWER_PROVIDER`:**

- **Codex** → invoke `codex:rescue` with the filled prompt. Do NOT pass `--write` (default
  read-only sandbox). The orchestrator captures Codex's output.
- **Claude** → dispatch via Task tool as a read-only subagent (same as fixer dispatch but
  without write/edit permissions).

**Spec reviewer (second axis, in parallel):** if a spec source exists, also dispatch the
Spec reviewer using `resources/spec-reviewer-prompt.md` — always a Claude read-only
subagent via Task tool, independent of `REVIEWER_PROVIDER`. The two reviewers run in
parallel and never see each other's output. Round 2+: dispatch only if the previous
round has SP- findings to confirm or still open (dispatch criteria in the template).

Write both outputs to `artifacts/current/code-review-loop/review-round-{ROUND}.md` —
the quality review first, then the Spec reviewer's output appended under its own
`# Spec Conformance Round {ROUND}` heading. Keep the sections verbatim; do not merge
findings across axes.

### Step 2: Evaluate Results

Parse the round file for issue counts by severity, across both axes — SP- findings
carry the same severity labels and enter the same buckets for loop-control purposes.
Counting is not reranking: findings stay attributed to their axis and are never
reordered against the other axis's.

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

- `{issues_content}` — the Issues section from `code-review-loop/review-round-{ROUND}.md`,
  plus the Spec Conformance Findings section (SP- items) if present
- `{round}` — current round number

Delegate to the **`code-fixer`** subagent with the filled template as its prompt.

After fixer completes:

- Write the fixer's output to `artifacts/current/code-review-loop/fix-round-{ROUND}.md`
- Increment `ROUND += 1`
- Return to **Step 1** (reviewer confirms fixes and does fresh review)

### Step 4: Final Verification

Run the verification levels yourself (the orchestrator). Read `resources/verification-checklist.md`
for the full checklist structure.

**BDD and E2E verification source** (priority order):
1. `artifacts/current/bdd-validation.md` — authoritative if it exists.
2. BDD/E2E steps in `implementation.md` — fallback.
3. **Self-derived** — if neither exists, warn the user, derive behavioral validations from the codebase, propose them, proceed after confirmation. Record all proposed and executed validations in the report's "Behavioral Validation" section.

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
- Spec Conformance outcomes (SP- findings per type, or why the axis was skipped)
- Reading Guide (suggested review order for the human: contracts/types → core logic → wiring → tests, with ⚠️ risk flags)
- Critical fixes table
- Library usage corrections (Context7)
- Documentation improvements
- Unaddressed suggestions
- Final verification results
- Complete changed files manifest
- Learning Notes (engineering strategies applied, trade-offs accepted, key takeaways — distilled from what the rounds surfaced)

Write to `artifacts/current/code-review-improvement-report.md`.

### Step 5.5: BDD Behavioral Verification

If `artifacts/current/bdd-scenarios.md` and `artifacts/current/verification-plan.md` both exist, invoke the `bdd-e2e-loop` skill to run full BDD verification against the reviewed code. Review fixes can introduce behavioral regressions — this step catches them before the user sees the final result.

If BDD verification finds failures, they are handled within the BDD E2E Loop's own fix cycle (separate from this skill's review rounds). Once BDD verification completes (pass or stop), proceed to Step 6.

If neither BDD file exists, skip this step.

### Step 6: Notify User

Present the **架構影響摘要** (from the report's first section) directly in chat:

```
Code Review Loop 完成。

{ROUND} 輪 | 共發現並修正 {total} 個 issues
  Blocking: {n} | Major: {n} | Minor: {n}
  Library 修正: {n} | 文件修正: {n}
  所有 verification 通過 ✓

## 你需要知道的變更

{architecture_impact_summary — 架構影響摘要的內容}

完整 report：artifacts/current/code-review-improvement-report.md
（想邊讀邊註解的話，可用 `htmlify` 轉成 HTML——Learning Notes 會呈現為浮動側欄。）

有任何不清楚的地方請隨時問我。
確認 OK 後說「發 PR」，我會建立 PR 並附上 report 摘要和 Manual Validation checklist。
```

Wait for the user to ask questions and confirm. After confirmation, create a PR with:

- Report 摘要 in PR description
- Manual Validation checklist (from `artifacts/current/bdd-validation.md` if available)
- Link to full report file

---

## Rules

1. **Fresh session (recommended, not enforced)** — Running in a fresh session produces
   better reviews because the orchestrator has no memory of implementation decisions.
   Ask the user whether this is a fresh session. If not, suggest opening a new one but
   continue if they choose to proceed — the human makes the final call.

2. **Cross-model isolation (preferred)** — Reviewer (Codex) and fixer (Claude) use different
   model providers. They never share context. When Codex is unavailable, both fall back to
   Claude subagents via Task tool — session isolation is still enforced.

3. **Reviewer is read-only** — Enforced at two levels:
   - **Codex mode:** `codex:rescue` default sandbox is `read-only` (system-enforced).
   - **Claude mode:** Task tool dispatch with explicit read-only instruction in the prompt.

4. **Context7 verification** — Library verification always uses Context7 data. The delivery
   method depends on `REVIEWER_PROVIDER`:
   - **Codex:** Orchestrator pre-fetches Context7 data and injects it into the reviewer prompt.
   - **Claude:** Reviewer queries Context7 directly during review.
   Round 1: all external libraries. Subsequent rounds: only libraries with changed usage.

5. **Review Standards** — The reviewer enforces pragmatic code standards embedded in
   `resources/reviewer-prompt.md`: YAGNI, readability, comments, documentation, zero
   tolerance for code cruft, the Fowler smell baseline (repo-documented standards
   override it; smells are always judgement calls), and Context7-verified library usage.

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

10. **Two axes, never merged** — Quality/Standards and Spec conformance are reviewed by
    separate subagents and reported side by side. Do not merge, rerank, or pick a single
    "worst issue" across axes — one axis's severe findings would mask the other's, and
    "well-built but wrong thing" is exactly the failure the Spec axis exists to catch.

## Resource Files Reference

| File                                  | Purpose                           | When to Read        |
| ------------------------------------- | --------------------------------- | ------------------- |
| `resources/reviewer-prompt.md`        | Quality reviewer prompt template  | Step 1 (each round) |
| `resources/spec-reviewer-prompt.md`   | Spec reviewer prompt template     | Step 1 (per dispatch criteria) |
| `resources/fixer-prompt.md`           | Fixer subagent prompt template    | Step 3 (each round) |
| `resources/report-template.md`        | Improvement report structure      | Step 5              |
| `resources/verification-checklist.md` | Final verification checklist      | Step 4              |
