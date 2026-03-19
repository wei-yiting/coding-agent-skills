---
name: sync-briefing-plan
description: >-
  Sync the briefing and implementation plan after changes to either document or the code.
  These two documents are different views of the same work — when one changes, the other
  must be checked and updated. Use this skill whenever:
  user gives feedback that modifies the briefing or plan,
  codebase changes during or after implementation diverge from the plan,
  the implementation plan is updated by the agent (new tasks, scope changes, refined approach),
  or code review results in design or scope changes.
  This skill should be proactively invoked by the agent itself after modifying either
  .artifacts/current/briefing.md or .artifacts/current/implementation.md — don't wait
  for the user to ask.
  Also trigger when user says "sync plan", "update briefing", "update plan", "plan changed",
  "briefing changed", "refresh briefing", "同步", "更新概述", or "docs out of date".
  Do NOT use for initial briefing creation — use create-briefing instead.
---

# Sync Briefing ↔ Implementation Plan

The briefing and the plan are two views of the same work. When they disagree, the reviewer sees one story and the agent executes another — that's how misaligned work ships. Keeping them in sync isn't busywork; it's the mechanism that keeps human oversight real.

## Workflow

### Step 1: Determine sync direction

| What Changed                     | Direction              |
| -------------------------------- | ---------------------- |
| User modified the briefing       | Briefing → Plan        |
| User modified the plan           | Plan → Briefing        |
| Agent refined the plan           | Plan → Briefing        |
| Code diverged from plan          | Code → Plan → Briefing |
| Code review changed design/scope | Code → Plan → Briefing |

If it's unclear what changed or who changed it — ask the user before proceeding. Guessing the wrong direction propagates errors.

### Step 2: Read both documents

Read `.artifacts/current/briefing.md` and `.artifacts/current/implementation.md`. You need both in context to identify discrepancies accurately.

### Step 3: Diff and map impact

Identify what changed and which sections in the target document are affected. Read this skill's `references/sync-policy.md` for the impact mapping table that connects briefing sections to plan content, sync direction rules, scenario procedures, and the full sync protocol.

### Step 4: Present sync summary BEFORE making changes

Changes to documents are easy to make but hard to review after the fact. The user needs to see and approve the sync plan before you touch anything.

```
Sync Summary:

Direction: {Briefing→Plan / Plan→Briefing / Code→Both}

Source changes:
- {list what changed}

Target sections to update:
- {list affected sections with what will change in each}

Proceed with sync?
```

Do not skip this step, even for "obvious" syncs. The user may disagree with your impact assessment, want to handle certain sections differently, or realize the change implies something you didn't consider.

### Step 5: Apply changes

After user confirmation, update only the affected sections. Don't rewrite sections that haven't changed — unnecessary rewrites introduce noise and make it harder for the user to verify what actually changed.

Preserve any user-added annotations in both documents.

Add an update marker:

```markdown
> Updated: [date] — [what changed and why]
```

### Step 6: Run sync checklist

Read this skill's `references/sync-policy.md` and run the 8-point sync checklist. Every item must pass.

If any check fails: identify the discrepancy → determine the correct version (check code if unclear) → fix → re-run the full checklist. Changes can cascade — fixing one discrepancy may reveal another.

### Step 7: Confirm

```
Sync complete.

Updated: {implementation.md / briefing.md / both}
Changes:
- {list specific changes made}

Sync checklist: 8/8 passed.
```

## Key Principles

- **Confirmation before action** — Document changes are high-trust operations. Never modify files without showing the user what will change and getting approval. This isn't ceremony; it prevents silent error propagation.
- **Surgical updates** — Touch only what changed. Full rewrites obscure what's new and make review harder.
- **Diagrams track changes too** — When file relationships change, the File Impact Map and Design Overview must be updated. Diagrams go stale just like text, but stale diagrams are harder to spot.
- **Code always wins** — If code, plan, and briefing all disagree, code is correct. Update outward from there.
