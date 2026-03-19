---
name: create-briefing
description: >-
  Create the initial briefing document as a companion to a new implementation plan.
  The briefing is a different view of the same work — architecture, impact, and reasoning
  at a glance for human reviewers. Use this skill whenever:
  an implementation plan was just generated (by any planning workflow),
  user says "create briefing" / "generate briefing" / "write briefing" / "briefing document",
  or .artifacts/current/implementation.md exists but briefing.md does not.
  Also trigger automatically after any plan creation workflow completes, even if the user
  doesn't explicitly ask for a briefing.
  Do NOT use for syncing existing briefings after changes — use sync-briefing-plan instead.
---

# Create Briefing

Plans are optimized for agent execution — step-by-step, verbose, every command spelled out. Humans need something different: a view that shows architecture, impact, and reasoning at a glance. That's what the briefing provides.

## Key Mindset

The briefing and the plan describe the same work. They diverge in _how_ they present it:

| Aspect       | Plan                           | Briefing                               |
| ------------ | ------------------------------ | -------------------------------------- |
| Audience     | Agent (executor)               | Human (reviewer)                       |
| Structure    | Sequential tasks with commands | Architecture with diagrams             |
| Detail level | Every command, every file edit | High-level design + critical code only |
| Purpose      | "Do exactly this"              | "Here's what changes and why"          |

If you catch yourself copying plan text into the briefing, stop — you're writing a summary, not a briefing. Rethink the information from the reviewer's perspective: what would they need to approve this work?

### Diagrams are non-negotiable

Every briefing needs at least one Mermaid diagram. This isn't a formatting preference — diagrams force you to actually understand the architecture. If you can't draw the component relationships or data flow, you haven't understood the plan well enough to brief someone on it.

### Code only for critical changes

Include code snippets only when the code _is_ the design decision — an unusual pattern, a critical interface, a security-sensitive implementation. Routine changes (add import, call function, update config) are described in words. Humans scan briefings; code blocks slow them down unless they carry architectural weight.

### Language convention

Write prose in Traditional Chinese (zh-TW). Technical terms stay in English — file paths, function names, CLI commands, code snippets, Mermaid node labels. This mirrors how bilingual engineering teams naturally communicate.

> **Example:**
> "新增 streaming endpoint，回傳符合 protocol 要求的 SSE chunks 和 headers。"

## Workflow

### Step 1: Load the format guide

Read this skill's `references/briefing-structure.md`. This defines the 8-section structure every briefing follows. Don't improvise sections or skip any — the structure exists because each section answers a distinct reviewer question.

### Step 2: Read the implementation plan

Read `.artifacts/current/implementation.md`. If it doesn't exist, tell the user an implementation plan must be created first (e.g., via the `implementation-planning` skill).

### Step 3: Extract architectural information

From the plan, extract the information the reviewer needs — not everything in the plan, but everything a reviewer would ask about:

- Task list with associated files → Task Breakdown + File Impact Map
- File dependency relationships → Design Overview diagrams
- Design decisions and rationale → Decisions section
- Test strategy (new + existing) → TDD entries + Test Impact Matrix
- Risk factors and blast radius → Risk Assessment
- Observable verification steps → E2E verification

Think about what questions the reviewer would ask. The briefing should answer those questions before they're asked.

### Step 4: Generate the briefing

Follow the 8-section structure from `references/briefing-structure.md` exactly. Each section has a "Reviewer question" that defines its purpose — if your content doesn't answer that question, it doesn't belong there.

Pay special attention to:

- **Section 2 (Design Overview)**: Pick the diagram type that matches the plan's nature. A migration needs before/after flows; a new feature needs component architecture. The format guide has a selection table.
- **Section 4 (Task Breakdown)**: Each task gets TDD test descriptions in plain language (no code). After all tasks, write the unified BDD section covering holistic system behaviors. Then add the Observable Verification table with concrete E2E steps.
- **Section 8 (Decisions & Verification)**: This is the reviewer's action plan. Give them concrete steps — not "check it works" but "open this URL, do this action, expect this result."

### Step 5: Save the briefing

Save to `.artifacts/current/briefing.md`.

### Step 6: Verify sync

Read `sync-briefing-plan` skill's `references/sync-policy.md` and run the 8-point sync checklist. A brand-new briefing can still be out of sync with the plan if you missed tasks, misrepresented decisions, or got file impact wrong.

### Step 7: Present to the user

```
Briefing 已建立：.artifacts/current/briefing.md

請在 VS Code 中檢閱（建議安裝 Mermaid Preview extension）。
- 核准 → 回覆 "approved"，本次 session 結束，請開新 session 執行 implementation。
- 有回饋 → 我會同步更新 briefing 和 plan。
```

## Output Location

- Briefing: `.artifacts/current/briefing.md`
- If `.artifacts/current/briefing.md` already exists, archive it first to `.artifacts/archive/{YYYY-MM-DD-HH-MM}-{task-name}/briefing.md` before writing the new one.

## Common Mistakes

- **Wall of text** — More than 5 lines of prose without a diagram or table means you need a visual. Reviewers skim.
- **Copying plan verbatim** — If the briefing reads like the plan, one document is redundant. Rethink from the reviewer's perspective.
- **Missing Section 8** — A briefing without verification steps is incomplete. The reviewer has no way to confirm the work is done.
- **Generic risks** — "Something might break" tells the reviewer nothing actionable. Name the file, the pattern, the failure mode.
