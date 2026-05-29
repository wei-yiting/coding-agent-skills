---
name: generate-briefing
description: >-
  Create the initial briefing document by aggregating implementation.md and
  BDD artifacts (bdd-scenarios.md + verification-plan.md) into a concise
  review document for human reviewers. Use this skill whenever:
  both implementation.md and BDD artifacts exist and briefing.md does not,
  user says "create briefing" / "generate briefing" / "write briefing" /
  "briefing document",
  or the user explicitly requests a briefing after completing planning and
  BDD workflows.
  Do NOT use for syncing existing briefings after changes — use
  apply-briefing-update instead.
---

# Generate Briefing

The briefing is an **aggregation layer** — it reads two independently produced artifact sets and merges them into a single, concise review document. It does not generate new content; it reorganizes and presents existing information from the reviewer's perspective.

**Announce at start:** "I'm using the generate-briefing skill to generate the briefing."

## Source Artifacts

| Artifact | Produced by | What it provides |
|----------|-------------|------------------|
| `artifacts/current/implementation.md` | `implementation-planning` | Goal, tasks, file plan, test strategy, constraints, risks |
| `artifacts/current/bdd-scenarios.md` | `behavior-validation-plan` | BDD scenarios (illustrative + journey) |
| `artifacts/current/verification-plan.md` | `behavior-validation-plan` | Verification methods (automated, manual, UAT) |
| `artifacts/current/design.md` *(optional)* | `design-brainstorming` | Original design decisions — sub-agent compares against impl for Design Delta |

## Key Mindset

The briefing does NOT summarize or re-explain the implementation plan. It answers a different set of questions:

| Plan asks | Briefing asks |
|-----------|---------------|
| "What do I build next?" | "What's changing and what's the impact?" |
| "How do I implement this?" | "How do we verify this works?" |
| "What test do I write?" | "Will this break existing things?" |

## Prerequisites

**Both** of the following must exist before generating a briefing:

1. `artifacts/current/implementation.md`
2. `artifacts/current/bdd-scenarios.md` AND `artifacts/current/verification-plan.md`

If any file is missing, tell the user what's missing and which skill produces it:

- Missing `implementation.md` → run `implementation-planning`
- Missing `bdd-scenarios.md` or `verification-plan.md` → run `behavior-validation-plan`

Ask the user how they want to proceed — do NOT generate a partial briefing by default. The whole point of the briefing is to aggregate both perspectives.

## Workflow

### Step 1: Load the format guide

Read this skill's `references/briefing-structure.md`. This defines the 5+2 section structure. Don't improvise sections.

### Step 2: Check prerequisites

Verify all three source files exist. If any are missing, report what's missing and stop.

### Step 3: Read source artifacts and dispatch design comparison

Read all three required files:
- `artifacts/current/implementation.md`
- `artifacts/current/bdd-scenarios.md`
- `artifacts/current/verification-plan.md`

If `artifacts/current/design.md` exists, dispatch a sub-agent using this skill's `agents/design-delta-reviewer.md` as the prompt. The sub-agent reads both `design.md` and `implementation.md` independently — do NOT load `design.md` into the main context. Run the sub-agent in the background while proceeding to Step 4.

### Step 4: Generate the briefing

Follow the structure from `references/briefing-structure.md`. For each section, the structure guide specifies exactly which source artifact to pull from and how to present it.

If a design-delta sub-agent was dispatched, incorporate its result into Section 1 (Design Delta) before finalizing. If it returned `NO_DELTAS`, include a one-line confirmation. If it returned `DELTAS_FOUND`, group and format the findings per `briefing-structure.md` Section 1.

### Step 5: Save the briefing

Save to `artifacts/current/briefing.md`. If an old file exists, archive it first to `artifacts/archive/{YYYY-MM-DD-HH-MM}-{task-name}/briefing.md`.

### Step 6: Present to the user

```
Briefing 已建立：artifacts/current/briefing.md

請在 VS Code 中檢閱（建議安裝 Mermaid Preview extension）。
- 核准 → 回覆 "approved"，本次 session 結束，請開新 session 執行 implementation。
- 有回饋 → 我會同步更新 briefing 和 plan。
```

## Common Mistakes

- **Copying plan verbatim** — Transform for the reviewer's perspective. A task's execution checklist is not what the reviewer needs to see.
- **Shallow Test Safety Net** — "有 unit tests" or "有 snapshot tests" is not a meaningful description. Describe the behaviors being protected (e.g., "request dispatch、auth guard、rate limiting 皆有 integration tests 覆蓋") so the reviewer can judge whether coverage is sufficient.
