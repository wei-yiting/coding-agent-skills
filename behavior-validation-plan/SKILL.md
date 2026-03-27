---
name: behavior-validation-plan
description: Generate behavior test scenarios and verification plans from design documents using Three Amigos multi-perspective discovery. Produces illustrative scenarios (per-rule behavior tests) and journey scenarios (end-to-end flow tests) with concrete verification steps. Use this skill after design-brainstorming produces a design.md, when the user wants to create acceptance test scenarios, write behavior test scenarios, plan E2E verification, generate test cases from a design, prepare verification criteria before coding, create a test plan, build a QA plan, figure out what to test, or verify a design. Also trigger on phrases like "BDD", "behavior test", "acceptance tests", "E2E test plan", "test plan", "QA plan", "what should I test", "how to verify this design", "scenario generation", "behavior validation", "驗收測試", "測試情境", "驗證計畫", "寫測試案例", "測試計畫", or "行為驅動".
---

# Behavior Test Scenario Generation

At the start, let the user know you're using this skill and what to expect — the process involves multi-perspective discovery and may surface questions that need the user's judgment before output is ready.

## Overview

Generate two artifacts from a design document through a Three Amigos discovery process:

1. **Behavior Test Scenarios** (`.artifacts/current/bdd-scenarios.md`) — What to verify: illustrative scenarios testing individual rules, plus journey scenarios testing complete E2E flows
2. **Verification Plan** (`.artifacts/current/verification-plan.md`) — How to verify: concrete steps for automated and manual testing of each scenario

Three specialized agents (Product Owner, Developer, QA Tester) independently discover scenarios from different perspectives, debate and challenge each other's findings, then converge into a comprehensive scenario set. This multi-perspective approach catches gaps that any single viewpoint would miss.

## Prerequisites

- `.artifacts/current/design.md` exists (from design-brainstorming)
- The brainstorming session context is available (same conversation or summarized)
- User has reviewed and approved the design

**If design.md does not exist:** Tell the user this skill requires a design document as input. Suggest running design-brainstorming first. If the user has a design in another form (Notion page, verbal description, PR spec), help them consolidate it into `.artifacts/current/design.md` before proceeding. Never generate behavior test scenarios without a design document — scenarios derived from nothing look plausible but are baseless.

## Isolation Principle

This skill derives scenarios from design.md, the current session's conversation history (brainstorming decisions, rejected alternatives, edge cases the user raised), and any specs or requirements the user has shared. Never read `.artifacts/current/implementation.md`, implementation artifacts, or the codebase. Scenarios aligned to the design — not the implementation — catch cases where the implementation diverges from what was designed. Reading implementation artifacts would align your scenarios with the code instead of the design, hiding exactly the gaps verification is meant to surface.

## Process

```
design.md + session context
         │
         ▼
Phase 1: Three Amigos Discovery
  PO + Dev + QA discover scenarios independently
  then challenge each other's findings
         │
         ▼
Phase 2: Diverge-Converge
  Diverge → surface questions to user → resolve → converge
         │
         ▼
Phase 3: Formulation
  Structure scenarios: Rules → Illustrative + Journey
         │
         ▼
Phase 4: Verification Planning
  Dev + QA plan automation; PO + QA plan UAT
         │
         ▼
Phase 5: Output
  bdd-scenarios.md + verification-plan.md
```

### Phase 1: Three Amigos Discovery

The discovery uses three specialized perspectives to maximize scenario coverage. Each perspective has a distinct focus and a way of challenging the others — this cross-examination is what produces thorough coverage.

This skill requires Agent Teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). If not enabled, tell the user to enable it before proceeding — the Three Amigos discovery depends on inter-agent debate that cannot be replicated without it.

Create an Agent Team. Read the prompt templates from `references/` for each role:

- `references/po-prompt.md` → Product Owner teammate
- `references/dev-prompt.md` → Developer teammate
- `references/qa-prompt.md` → QA Tester teammate

Provide each teammate with:

- The full content of `.artifacts/current/design.md`
- A summary of key discussion points from the brainstorming session — decisions made, alternatives rejected, constraints discovered, edge cases the user specifically mentioned

**If design.md exceeds ~300 lines:** Don't rely on teammates processing it in full — large documents get truncated or lose detail. Instead, create a design summary preserving all Features and Rules, then feed each teammate the summary plus the full text of one Feature at a time. Process Features sequentially or distribute them across teammates.

**If a teammate fails mid-session:** Immediately tell the user which teammate failed and ask how they want to proceed — restart that teammate, assign a different approach, or adjust scope. Do not silently continue with fewer than three perspectives, because incomplete coverage defeats the purpose of Three Amigos discovery.

**If debate loops without converging** after 3 exchanges on the same point: surface the disputed scenario to the user for judgment. Do not let teammates cycle indefinitely.

### Phase 2: Diverge-Converge

Follow a single diverge-converge cycle, mirroring the real Three Amigos workshop format.

**Diverge:**

- Each teammate independently discovers scenarios from design.md
- They message each other to challenge findings
- Disagreements resolve through concrete examples, not abstract debate — when two perspectives conflict, put a specific scenario on the table and see if it holds

**Surface questions to user:**

- When a question cannot be resolved among the three perspectives, surface it to the user immediately
- Wait for the user's judgment
- Feed the answer back to the team to continue converging
- Do not defer questions — all questions must be resolved before producing output

**Converge:**

- Scenarios supported by multiple perspectives → high confidence, include
- Scenarios from a single perspective with a concrete example → include (unique viewpoint value)
- Scenarios from a single perspective without a concrete example → discuss with user before including
- Unresolvable disagreement → if three perspectives can't agree and the user can't decide, the scenario doesn't go in. Don't ship uncertainty.
- Blind spot check: scan design.md for features or decisions with no corresponding scenarios

The final output contains only converged, resolved scenarios. No open questions remain.

### Phase 3: Formulation

Structure the converged scenarios into the output format defined in `references/scenarios-template.md`.

**If the design describes a refactor (not a new feature):** The goal shifts from "verify new behavior" to "verify behavior is preserved." Treat "existing behavior must not change" as the primary Rule, and write scenarios that assert current behavior still holds after the refactor. If the design has no user-facing behavioral changes, tell the user this skill is optimized for new features and suggest using test-driven-development for pure regression testing of refactors.

For each Feature in the design:

1. **Extract Rules** from design constraints, decisions, and requirements. A Rule is a business rule or acceptance criterion that governs behavior — it explains why the scenarios beneath it exist. Example: "Orders over $100 get free shipping" is a Rule; the scenarios under it test the boundary ($99, $100, $101).

2. **Organize Illustrative Scenarios** (`S-` prefix) under their Rules:
   - Each scenario tests exactly one Rule
   - Each scenario's Given step establishes its own preconditions — no scenario depends on another having run first
   - 3-5 steps per scenario, declarative style (describe what happens, not how buttons are clicked)

3. **Write Journey Scenarios** (`J-` prefix) for complete E2E flows:
   - Every Feature must have at least one Journey scenario — they are not optional
   - Use high-level declarative steps covering the full user flow
   - Journey scenarios prove the pieces work together end-to-end, which is the core purpose of this skill

**Quality gate:** Before finalizing, verify each scenario passes the BRIEF heuristic — **B**usiness language, **R**eal data, **I**ntention-revealing title, **E**ssential details only, **F**ocused on one Rule. Most scenarios should be 5 lines or fewer. Read `references/scenario-example.md` for a complete design → scenarios transformation to calibrate quality and granularity.

### Phase 4: Verification Planning

With scenarios finalized, plan how to verify each one. All teammates stay alive throughout — use task assignment, not lifecycle management, to control who works on what. PO idles during automation planning but contributes to UAT.

**Task assignment by verification type:**

- **Deterministic** (curl, script, log grep, DB query) → Dev leads, because it requires knowledge of entry points and tooling
- **Browser Automation** (Browser-Use CLI, screenshot comparison) → Dev + QA collaborate; Dev knows feasibility, QA knows what to check
- **Manual Behavior Test** (assists automated verification where technical limitations prevent automation) → QA + Dev; QA identifies gaps, Dev confirms technical constraints
- **User Acceptance Test** → PO + QA; PO defines "what done looks like" from the user's perspective, QA structures the checklist

Manual verification splits into two categories because they serve different purposes:

- **Manual Behavior Test**: Things the Coding Agent technically cannot test (needs physical device, high-concurrency environment, etc.). These assist and complete the E2E behavior verification.
- **User Acceptance Test**: The user's own acceptance testing — confirming the Coding Agent's work meets requirements. This is a PO-perspective validation, performed at PR review time.

**Choosing the verification method — match where the behavior lives:**

- **Behavior is in backend logic** (state persistence, pipeline stage ordering, async task lifecycle, rate limiting, error handling flows) → **Deterministic** (curl/script). Chain state between steps: output from step N feeds step N+1. The final assertion proves the behavioral outcome, not just an API response code.
- **Behavior is in the UI** (streaming rendering, progress indicators, interactive controls, error display, visual state transitions) → **Browser Automation** (Browser-Use CLI). These behaviors only exist in the frontend — curl cannot observe them.
- **Journey scenarios** get **both**: a deterministic API chain (proves the pipeline works) and a browser flow (proves the UI renders it correctly). These test different failure modes of the same behavior.

**Behavior test vs unit test boundary:** A scenario belongs in behavior testing if it has a behavior trigger, state flow across steps, and an observable outcome. "SSE endpoint returns correct headers" is a unit test (single call, technical contract). "User retries after error and sees a new streamed response" is a behavior test (state flow, behavior trigger, observable outcome).

**Behavior test vs agent evaluation boundary:** Scenarios driven by LLM decisions (which tool to call, response quality, groundedness) belong in agent evaluation, not here. Behavior testing verifies the structural pipeline — stages execute in order, state persists, UI renders correctly — regardless of what the LLM decides.

For each scenario, determine:

1. **Verification method** — where the behavior lives (see above)
2. **Concrete steps** — specific commands, URLs, payloads from the design. Chain state between steps.
3. **Expected results** — the observable behavioral outcome
4. **Placeholders** — only for information that genuinely requires post-coding codebase inspection. Mark with `[POST-CODING: {what to look up}]`

Write commands as specifically as possible using design information. The post-coding verification phase should primarily execute these steps, not design them.

Follow the template in `references/verification-plan-template.md`. Read `references/verification-example.md` before writing entries to calibrate behavioral depth.

### Phase 5: Output

**Full generation (no existing scenarios):**

1. Archive any existing `.artifacts/current/bdd-scenarios.md` or `.artifacts/current/verification-plan.md`
2. Write both files following their respective templates exactly
3. Verify scenario IDs are consistent between both files — every scenario in bdd-scenarios.md must have a corresponding entry in verification-plan.md

**Incremental update (existing scenarios + design change):**
If bdd-scenarios.md already exists and the user wants to update after a design change:

1. Read the existing bdd-scenarios.md
2. Ask the user which Features changed, or diff design.md to identify the scope
3. Re-run discovery only for the changed Features
4. Preserve unchanged Features' scenarios and their IDs intact — the user may have manually tuned them
5. Update verification-plan.md to match: add/modify entries for changed scenarios, keep the rest

**If the user wants to stop early:** Save whatever scenarios have been converged so far into bdd-scenarios.md (clearly marking which Features are complete and which are partial). Don't discard work already done — partial coverage is better than none, and the incremental update flow can pick up where you left off.

