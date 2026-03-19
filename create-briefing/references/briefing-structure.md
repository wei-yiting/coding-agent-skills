# Briefing Structure Guide

Reference this document when **creating a new briefing**. It defines each section's purpose, format, and content requirements.

Generate the briefing with these 8 sections in order. Each section exists because it answers a distinct reviewer question — don't merge or skip sections.

**Language:** Write prose in Traditional Chinese (zh-TW). Technical terminology stays in English — file paths, function names, CLI commands, code snippets, and Mermaid diagram node labels are all technical. This mirrors how bilingual engineering teams naturally communicate: Chinese sentences carrying English technical nouns.

---

## Section 1: Header

```markdown
# [Descriptive Title] Briefing

> Companion document to [`implementation.md`](./implementation.md) (implementation plan).
> Purpose: Architecture overview for human review and discussion.
```

The header establishes the relationship between briefing and plan. The reviewer should immediately know where to find execution details.

---

## Section 2: Design Overview

**Reviewer question**: _"What is this change doing architecturally, and why this approach?"_

Choose the visual format that best communicates the plan's architectural intent:

| Plan Nature                 | Recommended Format                                                                     |
| --------------------------- | -------------------------------------------------------------------------------------- |
| **Migration / Refactor**    | Before → After `sequenceDiagram` pair showing data flow changes                        |
| **New Feature**             | Architecture `graph` showing component design + `sequenceDiagram` for key interactions |
| **Frontend Feature**        | Wireframe / component tree diagram + page flow                                         |
| **Infrastructure / Config** | `graph TD` showing dependency topology + environment flow                              |
| **Bug Fix / Optimization**  | Root cause diagram + fix point annotation                                              |

**Guidelines:**

- **Diagrams first** — Every design overview needs at least one Mermaid diagram. Diagrams force you to understand the architecture; if you can't draw it, you haven't understood the plan well enough to brief a reviewer.
- **Pick the right diagram type** — `sequenceDiagram` for request flows, `graph` for component relationships, `flowchart` for decision logic, `classDiagram` for data models.
- **Design Decision table** — When multiple approaches were considered, include a table showing what was chosen and why. One line per decision keeps it scannable.

---

## Section 3: File Impact Map

**Reviewer question**: _"How big is this change and what does it touch?"_

- Use a `graph TD` diagram with subgraphs for each architectural layer
- Color-code: green (`style ... fill:#90EE90`) for new, blue (`fill:#87CEEB`) for modified, red (`fill:#FFB6C1`) for deleted
- Show dependency arrows between layers

This gives the reviewer an instant sense of change scope and blast radius — which files change, which layers are affected, and how changes propagate.

---

## Section 4: Task Breakdown

**Reviewer question**: _"What work is being done, in what order, and how do we know each piece works?"_

For each task from the plan:
- One-line summary with the _why_, not just the _what_
- Map to its plan section number for cross-reference
- For **architecturally critical** code changes — key interfaces, unusual patterns, security-sensitive implementations — include the relevant snippet. Routine changes (imports, config, boilerplate) are described in words. Multiple tasks may qualify; use judgment.
- Note key design decisions inline

Each task entry also includes:

- **Tests (TDD)**: Describe each test case in plain language — what scenario it covers and what it asserts. No code snippets; describe intent. Example: _"Test that CallbackHandler receives session_id from config metadata when provided"_.

### Integration Validation (BDD)

After listing all tasks, include a **unified** BDD section. This is not per-task — it covers holistic behaviors that become possible only after all tasks are complete. The distinction matters: TDD validates individual pieces work; BDD validates they work _together_.

Format each validation as:
- **Behavior**: A high-level capability (e.g., "Every API request produces a full trace in Langfuse with parent-child hierarchy").
- **How the agent validates**: Concrete integration-level checks — commands, assertions, or inspections that prove the behavior works across the system. These are integration checks, not unit-level assertions (those belong in TDD).

Example:
> **Behavior**: The system traces all LangChain activity under a single Langfuse trace per request.
> **Agent validates**: Run full test suite (`pytest backend/tests/ -v`), confirm all pass. Grep scan for residual `langsmith`/`RunTree`/`trace_step` references → zero results.

### Observable Verification (E2E)

After BDD, include an observable verification table — concrete actions a human or agent can perform to confirm the system works end-to-end:

| # | Method | Step | Expected Result | Tag |
|---|--------|------|-----------------|-----|
| 1 | curl | `curl -X POST /api/chat -d '{"message": "hello"}'` | Status 200, response body contains `reply` field | [E2E] |
| 2 | browser | Open /dashboard, submit query | Page renders results within 3 seconds | [E2E] |
| 3 | MCP | Use @browser to screenshot /settings page | Settings form displays with all fields | [E2E] |

---

## Section 5: Test Impact Matrix

**Reviewer question**: _"What's the test safety net for this change?"_

New tests are defined above in Section 4 (TDD). This section catalogs **existing** tests only:

1. **Guardrail tests (pass without changes)** — Existing tests related to this change that continue passing as-is. Describe what each verifies and why it serves as a guardrail.
2. **Tests requiring adjustment** — Existing tests that need modification after this change. Describe what the test currently verifies and why the change requires updating it.

Format as table: Test File | Test Name / Description | Category (Guardrail / Adjust) | Reason

---

## Section 6: Environment / Config Changes

**Reviewer question**: _"What do I need to set up or change in my environment?"_

- Before/After table for environment variables
- Note any new or removed dependencies
- Flag anything that affects deployment or CI/CD

---

## Section 7: Risk Assessment

**Reviewer question**: _"What could go wrong, and how bad would it be?"_

Vague risks waste the reviewer's time. Be specific enough that someone can act on each risk.

Focus on:

1. **Code Change Risks** — Name the file, the pattern, the failure mode. Example: _"Decorator stacking order in `financial.py` — if `@observe` wraps `@tool` instead of the reverse, LangChain won't register the tool."_
2. **Environmental Risks** — New env vars, dependency version conflicts, deployment considerations.
3. **Blast Radius** — Which parts of the codebase beyond direct edit targets could be affected (downstream consumers, shared utilities, import chains).

Format as table: Risk | Affected Area | Mitigation

---

## Section 8: Decisions & Verification

**Reviewer question**: _"What was decided, and how do I verify the result myself?"_

This section serves two purposes: documenting design choices and giving the reviewer a hands-on verification plan.

- **Decisions**: Numbered list of each design choice with one-line rationale.
- **Verification**: Human-executable E2E plan, organized by scenario. These steps are for the reviewer **after the agent finishes** — all TDD tests pass, all BDD validations confirmed. The human doesn't need to re-run unit tests.

  Organize by scenario:
  1. **Happy Path** — Walk through the primary usage flow end-to-end.
  2. **Edge Cases** — Missing, malformed, or unusual inputs.
  3. **Negative Cases** — Confirm removed/old behavior is truly gone.
  4. **Regression Scenarios** — Key existing features that should still work exactly as before.

  Each step is a concrete action — not "verify it works" but "open http://localhost:3000, type 'Analyze AAPL', click Send, wait for response, then check Langfuse dashboard for a new trace".

---

## Anti-Patterns

These patterns consistently produce low-quality briefings. They're listed here not as rules to memorize, but as symptoms to watch for — if you catch yourself doing any of these, step back and rethink.

- **Wall of text** — More than 5 lines of prose without a diagram or table. Reviewers skim; dense paragraphs get skipped. Add a visual.
- **Copying plan verbatim** — The briefing shows architecture; the plan shows steps. If they read the same, you wrote a summary, not a briefing. Rethink the information from the reviewer's perspective.
- **Code dumps** — Code blocks slow readers down. Include code only when the code _is_ the design decision — an unusual pattern, a critical interface, a security-sensitive implementation.
- **Missing Section 8** — A briefing without verification steps is incomplete. The reviewer has no way to confirm the work is done.
- **Generic risks** — "Something might break" tells the reviewer nothing actionable. Name the file, the pattern, the failure mode, the blast radius.
- **Stale diagrams** — When file relationships change, the File Impact Map and Design Overview must be updated. Diagrams go stale just like text, but stale diagrams are harder to spot.
