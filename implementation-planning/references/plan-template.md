# Plan Template Reference

Use this exact template when writing `artifacts/current/implementation.md`.
Adapt section details to the specific task, but preserve the structure.

---

````markdown
# Implementation Plan: {task-name}

> Design Reference: {`[design.md](./design.md)` | `User prompt summary` | `Approved human/agent discussion summary`}
> Planning Context: {If no `design.md` exists, summarize the clarified goal, scope, constraints, and approved decisions that this plan uses as its design input}

**Goal:** {One sentence describing what this builds}

**Architecture / Key Decisions:** {2-3 sentences about the chosen approach, referencing approved constraints, trade-offs, or discussion outcomes}

**Tech Stack:** {Key technologies/libraries}

---

## Dependencies Verification

| Dependency | Version | Source | What Was Verified | Notes |
| ---------- | ------- | ------ | ----------------- | ----- |
| {lib}      | {ver}   | Context7 / official docs / official API reference | {method / API / constraint} | ... |

## Constraints

- {Technical limitations}
- {Files/logic that must not be touched}
- {Performance requirements}

---

## File Plan

| Operation | Path | Purpose |
| --------- | ---- | ------- |
| Create    | `path/to/new_file.ext` | {what will live here} |
| Update    | `path/to/existing_file.ext` | {module / behavior being changed} |
| Delete    | `path/to/obsolete_file.ext` | {why it can be removed} |

**Optional structure sketch** (include when it helps explain the overall change shape):

```text
path/
  to/
    new_file.ext
```

### Task 1: {Checkpoint Name}

**Files:**

- Create: `path/to/new_file.ext`
- Update: `path/to/existing_file.ext`
- Delete: `path/to/obsolete_file.ext` (if needed)
- Tests: `path/to/test_file.ext`

**What & Why:** {What this checkpoint changes and why it is grouped this way}

**Approach Decision** (include only when planning resolved a non-obvious choice):

| Option | Summary | Status   | Why      |
| ------ | ------- | -------- | -------- |
| A      | {desc}  | Selected | {reason} |
| B      | {desc}  | Rejected | {reason} |

**Implementation Notes:**

- {Key production changes in this task}
- {Important dependency, migration, or data-flow note}

**Critical Contract / Snippet** (include only when a type, schema, interface, migration, or architecture boundary needs to be explicit):

```{language}
{critical contract or code shape}
```

**Test Strategy:** {List the smallest meaningful tests / checks this task adds or updates, what each one proves, and why this scope is appropriate}

**Verification:**

| Scope | Command | Expected Result | Why |
| ----- | ------- | --------------- | --- |
| Targeted | `{repo-specific command}` | `{specific pass / output / state change}` | {what it proves} |
| Broader affected checks (if needed) | `{repo-specific command}` | `{specific pass / output / state change}` | {why it matters} |

**Execution Checklist** (tasks with testable code must follow the 🔴🟢🔵 Red-Green-Refactor cycle; infrastructure-only tasks use build/type-check verification instead):

- [ ] 🔴 Write test cases for this checkpoint
- [ ] 🔴 Run tests and confirm they **fail** (RED)
- [ ] 🟢 Implement the minimal production change that makes tests pass (GREEN)
- [ ] 🔵 Review implementation, refactor if needed
- [ ] 🔵 Run tests again and confirm they **still pass** after refactor
- [ ] Run broader affected checks if shared surfaces changed
- [ ] Commit the checkpoint when it is stable: `git commit -m "{type}({scope}): {description}"`

---

### Task 2: {Next Checkpoint}

{Same structure as Task 1}

---

### Flow Verification: {Flow Name}

> Tasks 1-2 complete the {describe flow} flow. All listed verifications must pass
> before the next checkpoint that depends on this flow.

| #   | Method                     | Step                                                                                                  | Expected Result                                           |
| --- | -------------------------- | ----------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| 1   | curl                       | `curl -X POST localhost:3000/api/endpoint -H "Content-Type: application/json" -d '{"input": "test"}'` | Status 200, body contains `result` field                  |
| 2   | Script / CLI               | `{repo-specific verification command}`                                                                | Assertions pass and output matches expectations           |
| 3   | trace                      | Check LangSmith/Langfuse for trace of above request                                                   | Trace shows: retriever → llm → tool_call in correct order |
| 4   | browser                    | Open localhost:3000, submit "test query"                                                              | Response renders within 3s, shows expected content        |
| 5   | MCP (Playwright/Puppeteer) | Use MCP to open the page, perform the flow, and capture a screenshot                                  | Screenshot and observed UI state match the expected flow  |
| 6   | Database / State Check     | {Read-only query or inspection step}                                                                  | Persisted state matches the expected side effect          |

- [ ] All flow verifications pass

---

### Task 3: {Next Checkpoint}

{Continue tasks as needed using the same structure}

---

### Flow Verification: {Next Flow Name}

> Tasks {N}-{M} complete the {describe flow} flow.

{Same table format as above}

---

## Pre-delivery Checklist

### Code Level (TDD)

- [ ] Targeted verification for each task passes
- [ ] Required unit / integration / end-to-end suites pass
- [ ] Lint passes (if applicable)
- [ ] Type check passes (if applicable)
- [ ] Build / bundle step succeeds (if applicable)

### Flow Level (Behavioral)

- [ ] All flow verification steps executed and passed
- [ ] Flow: {name} — PASS / FAIL
- [ ] Flow: {name} — PASS / FAIL

### Summary

- [ ] Both levels pass → ready for delivery
- [ ] Any failure is documented with cause and next action
````

---

## Template Usage Notes

- **Design Reference**: If there is no `design.md`, summarize the approved user prompt or discussion in `Planning Context` so the executor and reviewer can see the planning source.
- **Dependencies Verification**: Include only external dependencies that materially affect API usage, configuration, runtime behavior, or integration choices for this plan. If none apply, either omit the section when allowed by your workflow or state that no external verification was required.
- **File plan**: Use exact file paths and operation types, but do not invent speculative line-number ranges in a planning document.
- **File naming**: File names must be self-descriptive without relying on the parent package for context. A developer seeing the name in an IDE tab, search result, or git diff should immediately know what domain/function the file covers. Bad: `models.py`, `store.py`, `converter.py`, `downloader.py`. Good: `filing_models.py`, `filing_store.py`, `html_to_md_converter.py`, `sec_downloader.py`.
- **Critical snippets**: Include code only where a contract or architecture decision must be explicit. Do not pad the plan with filler examples.
- **Verification**: Every verification entry must include both the command and the expected result, not just what the command is intended to prove.
- **Commit messages**: Follow conventional commits format. Prefer one stable checkpoint per commit when practical, but do not force artificial commit boundaries.
- **Checkbox syntax**: Always use `- [ ]` for steps — downstream execution skills depend on this for progress tracking.
- **Execution checklist**: Keep only the checklist items that materially help the implementer. Do not force every task into identical micro-steps.
- **Optional sections**: Omit optional sections entirely when they do not apply; do not leave empty headings behind.
- **No placeholders**: The final plan must not contain `{...}`, TODOs, or unresolved questions.
