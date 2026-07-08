---
name: behavior-validation-plan
description: >-
  Generate behavior test scenarios and verification plans from design documents using Three
  Amigos multi-perspective discovery — illustrative per-rule scenarios plus end-to-end journey
  scenarios, each with concrete verification steps. Use after design-brainstorming produces a
  design.md, or whenever the user wants acceptance-test scenarios, an E2E test/QA plan, or
  verification criteria before coding.
---

# Behavior Test Scenario Generation

At the start, let the user know you're using this skill and what to expect — the process involves multi-perspective discovery and may surface questions that need the user's judgment before output is ready.

## Overview

Generate two artifacts from a design document through a Three Amigos discovery process:

1. **Behavior Test Scenarios** (`artifacts/current/bdd-scenarios.md`) — What to verify: illustrative scenarios testing individual rules, plus journey scenarios testing complete E2E flows
2. **Verification Plan** (`artifacts/current/verification-plan.md`) — How to verify: concrete steps for automated and manual testing of each scenario

Three specialized agents (Product Owner, Developer, QA Tester) discover scenarios through structured challenge rounds — PO seeds concrete examples, Dev challenges them from a technical perspective, QA applies destructive testing techniques, then PO judges business value. This sequential challenge dynamic produces genuine dialectic and catches gaps that any single viewpoint or parallel-discovery approach would miss.

## Prerequisites

- `artifacts/current/design.md` exists (from design-brainstorming)
- The brainstorming session context is available (same conversation or summarized)
- User has reviewed and approved the design

**If design.md does not exist:** Tell the user this skill requires a design document as input. Suggest running design-brainstorming first. If the user has a design in another form (Notion page, verbal description, PR spec), help them consolidate it into `artifacts/current/design.md` before proceeding. Never generate behavior test scenarios without a design document — scenarios derived from nothing look plausible but are baseless.

## Isolation Principle

This skill derives scenarios from design.md, the current session's conversation history (brainstorming decisions, rejected alternatives, edge cases the user raised), and any specs or requirements the user has shared. Never read `artifacts/current/implementation.md`, implementation artifacts, or the codebase. Scenarios aligned to the design — not the implementation — catch cases where the implementation diverges from what was designed. Reading implementation artifacts would align your scenarios with the code instead of the design, hiding exactly the gaps verification is meant to surface.

## Process

```
design.md + session context
         │
         ▼
Phase 1: Example Seeding (PO-led)
  PO extracts Rules, proposes concrete examples per Rule
         │
         ▼
Phase 2: Challenge Rounds (multi-round)
  Round 1: Dev challenges PO → QA challenges PO + Dev
  Round 2: Dev ↔ QA cross-talk
  Round 3: PO judges → Dev/QA can contest
  → surface questions to user → resolve
  → repeat if criteria not met (max 3 cycles)
         │
         ▼
Phase 2.5: Assumption Check
  Did examples reveal hidden assumptions in design.md?
  → Yes: surface to user
  → No: continue
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

### Phase 1: Example Seeding (PO-led)

This skill requires Agent Teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). If not enabled, tell the user to enable it before proceeding — the Three Amigos discovery depends on structured inter-agent challenge rounds that cannot be replicated without it.

Create an Agent Team. Read the prompt templates from `references/` for each role:

- `references/po-prompt.md` → Product Owner teammate
- `references/dev-prompt.md` → Developer teammate
- `references/qa-prompt.md` → QA Tester teammate

Provide each teammate with:

- The full content of `artifacts/current/design.md`
- A summary of key discussion points from the brainstorming session — decisions made, alternatives rejected, constraints discovered, edge cases the user specifically mentioned

**If design.md exceeds ~300 lines:** Create a design summary preserving all Features and Rules, then feed each teammate the summary plus the full text of one Feature at a time. Process Features sequentially.

**If a teammate fails mid-session:** Immediately tell the user which teammate failed and ask how they want to proceed. Do not silently continue with fewer than three perspectives.

**Start with PO only.** Send design.md to PO and ask it to extract Rules and produce Example Seeds. Dev and QA remain idle during this phase — they will receive PO's output as input for their challenge rounds.

PO produces, for each Rule:
- The Rule statement (business rule or acceptance criterion from the design)
- 2-3 concrete examples illustrating the behavior (not full Given/When/Then yet — simple "input → expected outcome" pairs with real data values, like a truth table)
- At least one happy path and one alternative path example
- Any questions about ambiguities discovered while creating examples

### Phase 2: Challenge Rounds

The value of Three Amigos comes from the conversation dynamic — each agent responding to and challenging the previous agent's output, and then cross-challenging each other. This phase uses structured rounds to force genuine dialectic, with cross-talk to let challenges trigger further challenges.

#### Round 1 — Structured Entry

Each agent gets a clear starting point. Run these steps sequentially:

**Step 1 → Dev Technical Challenge:**

Send PO's Example Seeds to Dev with this instruction:
> "Below are PO's concrete examples for each Rule. Your job is NOT to agree or supplement — it is to challenge. For each example, respond using the Challenge Format defined in your prompt. Every challenge must include a concrete counter-example, not just an abstract concern."

**Step 2 → QA Destructive Challenge:**

Send PO's original examples + Dev's challenges to QA with this instruction:
> "Below are PO's examples and Dev's technical challenges. Your job is to find what both of them missed. Apply systematic testing techniques to the combined example set. Every challenge must include a concrete counter-example. You may also build on Dev's challenges — if Dev's challenge triggers a related boundary concern, add it."

#### Round 2 — Cross-Talk

Dev and QA respond to each other's challenges. Run these in parallel:

**Dev → responds to QA's challenges:**
> "Below are QA's challenges from Round 1. For each one, assess technical feasibility and add follow-up challenges if QA's scenarios triggered new technical concerns. Use the Challenge Format for any new challenges."

**QA → responds to Dev's challenges from a testing perspective:**
> "Below are Dev's challenges from Round 1 and any new challenges Dev raised in response to yours. For each one, are there additional boundary conditions or failure modes that Dev's technical perspective revealed? Use the Challenge Format for any new challenges."

If Round 2 produces no new challenges (both agents only confirm existing ones), move to Round 3. If new challenges emerge, they feed into Round 3.

#### Round 3 — Judgment + Contest

**Step 1 → PO Value Judgment:**

Send all accumulated examples and challenges to PO with this instruction:
> "Below are all examples and challenges from Rounds 1-2. For each one, make a value judgment: Include, Demote to unit test, Needs user input, or Reject. Justify each judgment."

PO judges every challenge:
- **Include**: real users would encounter this, it's behavior-level, worth E2E verification
- **Demote to unit test**: technically valid but not user-visible behavior
- **Needs user input**: design doesn't specify this, user must decide
- **Reject**: not realistic, wouldn't happen in practice

**Step 2 → Dev/QA Contest (if applicable):**

Send PO's judgments to Dev and QA:
> "Below are PO's value judgments. If you disagree with any specific judgment, contest it with a concrete reason — explain why a real user WOULD encounter this scenario, or why demoting it to unit test would miss a behavior-level gap. Only contest judgments you genuinely disagree with."

If Dev or QA contests a judgment, PO must reconsider with the new argument. If PO still disagrees after seeing the contest, escalate the disputed scenario to the user.

#### Surface Questions to User

- Collect all "needs user input" items from all rounds
- Surface them to the user immediately, grouped by Rule
- Wait for the user's judgment before proceeding
- Feed answers back to the team

#### Additional Rounds (if needed)

After Round 3, check the completion criteria below. If not met, run another Round 2 → Round 3 cycle (max 3 total cycles). In subsequent cycles, only process the gaps identified by the criteria check — don't re-debate already-resolved scenarios.

#### Challenge Round Completion Criteria

All must be met before moving to Phase 2.5:

1. Every Rule has received at least 1 Dev challenge and 1 QA challenge
2. No agent merely restated another agent's examples with different names — if you detect this, send the offending response back with explicit instruction to challenge using a different concern type
3. At least 1 challenge across all Rules revealed a behavior not explicitly defined in design.md
4. PO has made a value judgment on every Dev and QA challenge, and all contests are resolved
5. No unresolved "needs user input" items remain

**If debate loops without converging** after 3 exchanges on the same point: surface the disputed scenario to the user for judgment. Do not let teammates cycle indefinitely.

### Phase 2.5: Assumption Check

Before moving to formulation, send all three agents this question:
> "Review all the examples and challenges so far. Did any concrete example reveal a hidden assumption in design.md — a case where the design implies behavior X but the example shows X might not hold, or where the design is silent about an important case? If yes, describe the assumption and the example that exposed it."

Collect responses from all three agents. If any agent surfaces a challenged assumption:
- Present it to the user with the concrete example that exposed it
- Ask the user whether the design assumption should be updated or the scenario should be adjusted
- Do not proceed to Phase 3 until the user has resolved all challenged assumptions

If no assumptions are challenged, proceed to Phase 3.

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

1. Archive any existing `artifacts/current/bdd-scenarios.md` or `artifacts/current/verification-plan.md`
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

