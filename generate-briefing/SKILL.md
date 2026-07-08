---
name: generate-briefing
description: >-
  Create the initial artifacts/current/briefing.md by aggregating implementation.md and BDD
  artifacts (bdd-scenarios.md + verification-plan.md) into a concise review document for human
  reviewers. Use when those source artifacts exist but briefing.md does not, or when the user
  asks for a briefing after planning completes. For syncing an existing briefing after edits,
  use apply-briefing-update instead.
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

Read this skill's `references/briefing-structure.md`. It defines the structure: **Section 0 (Review Focus) + 5 required + 2 conditional sections + a closing `## Learning Notes`**. The body (Section 0–7) targets **1–2 screens**; `## Learning Notes` is excluded from that budget. Don't improvise sections.

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

Three sections need explicit attention:
- **Section 2 (Overview)** — if `design.md` has a `## Slice Roadmap` and this plan covers one `## Slice N` group, name the slice in the paragraph (which slice, its roadmap position, its estimated size). No roadmap → unchanged.
- **Section 0 (Review Focus)** — the reviewer's map of the 3–5 items genuinely needing human judgment (deviations from conventions, irreversible changes, decisions planning flagged as uncertain). Everything else is implicitly agent-gated. Keep it to 3–5 items, each pointing to where to look.
- **`## Learning Notes`** (closing section) — aggregate the decision rationale from `design.md` and the trade-offs from `impl` into three sub-parts: engineering strategies applied, trade-offs considered, and key takeaways. This is an educational layer, excluded from the length budget; don't invent rationale that isn't in the sources.

If a design-delta sub-agent was dispatched, incorporate its result into Section 1 (Design Delta) before finalizing. If it returned `NO_DELTAS`, include a one-line confirmation. If it returned `DELTAS_FOUND`, group and format the findings per `briefing-structure.md` Section 1.

### Step 5: Save the briefing

Save to `artifacts/current/briefing.md`. If an old file exists, archive it first to `artifacts/archive/{YYYY-MM-DD-HH-MM}-{task-name}/briefing.md`.

### Step 6: Present to the user

```
Briefing 已建立：artifacts/current/briefing.md

先看 Section 0（Review Focus）——列出真正需要你親自判斷的 3–5 件事，其餘為 agent 已把關的 routine。結尾的 Learning Notes 是教育層，可選讀。

請在 VS Code 中檢閱（建議安裝 Mermaid Preview extension）。也可以用 `htmlify` 產生帶 Learning Panel 的可留言 HTML 版本。
- 核准 → 回覆 "approved"，本次 session 結束，請開新 session 執行 implementation。
- 有回饋 → 我會同步更新 briefing 和 plan。
```

## Common Mistakes

- **Copying plan verbatim** — Transform for the reviewer's perspective. A task's execution checklist is not what the reviewer needs to see.
- **Shallow Test Safety Net** — "有 unit tests" or "有 snapshot tests" is not a meaningful description. Describe the behaviors being protected (e.g., "request dispatch、auth guard、rate limiting 皆有 integration tests 覆蓋") so the reviewer can judge whether coverage is sufficient.
