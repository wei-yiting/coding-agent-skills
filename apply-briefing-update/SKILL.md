---
name: apply-briefing-update
description: >-
  Apply the user's edits to artifacts/current/briefing.md back to the source artifacts
  (implementation.md, bdd-scenarios.md, verification-plan.md). The briefing is the sole human
  review surface; direction is always briefing → sources. Use whenever the user edits or
  comments on the briefing, or gives plan feedback to sync. Do NOT use for initial briefing
  creation (use generate-briefing) or when the user edits source artifacts directly.
---

# Apply Briefing Update

The briefing is the human's review surface for the entire development plan. When the user edits the briefing, those changes must propagate back to the source artifacts so the coding agent executes the updated intent.

**Direction is always: Briefing → Source Artifacts.** There is no reverse flow.

**The briefing is exception-based.** Section 0 (Review Focus) and Section 5's sampled scenarios are still real review surfaces — user edits there sync back to source artifacts as usual (a changed Review Focus item maps to the relevant `impl` constraint/risk; a changed sampled scenario maps to `bdd-scenarios.md`). The **`## Learning Notes`** section is different: it is an **educational layer only**. User edits inside `## Learning Notes` must **NOT** propagate to any plan or BDD artifact — skip that section entirely when mapping changes.

## Target Artifacts

| Briefing Section | Target Artifact | Format Reference |
|-----------------|-----------------|------------------|
| Section 0 (Review Focus) | `implementation.md` (risk / constraint items) | `implementation-planning/references/plan-template.md` |
| Section 1 (Design Delta, conditional) | `implementation.md` (approach decisions deviating from design.md) | `implementation-planning/references/plan-template.md` |
| Section 2 (Overview) | `implementation.md` | `implementation-planning/references/plan-template.md` |
| Section 3 (File Impact) | `implementation.md` | `implementation-planning/references/plan-template.md` |
| Section 4 (Task 清單) | `implementation.md` | `implementation-planning/references/plan-template.md` |
| Section 5 (Behavior Verification) | `bdd-scenarios.md` + `verification-plan.md` | `behavior-validation-plan` SKILL.md |
| Section 6 (Test Safety Net) | `implementation.md` | `implementation-planning/references/plan-template.md` |
| Section 7 (Environment / Config, conditional) | `implementation.md` | `implementation-planning/references/plan-template.md` |
| `## Learning Notes` | — never synced (educational layer) | — |

## Workflow

### Step 1: Read the briefing and identify changes

Read `artifacts/current/briefing.md`. Identify which sections the user modified — through direct edits, inline comments, or verbal feedback in the conversation.

### Step 2: Map changes to target artifacts

Use the Target Artifacts table above to determine which source files need updating. Read this skill's `references/sync-policy.md` for the detailed impact mapping and scenario procedures.

### Step 3: Load format references (on demand)

Only read the references needed for the specific changes:

- **If sections 0-4 or 6-7 changed** → read `implementation-planning/references/plan-template.md`, then read `artifacts/current/implementation.md`
- **If section 5 changed** → read `behavior-validation-plan/SKILL.md` for incremental update guidelines, then read `artifacts/current/bdd-scenarios.md` and/or `artifacts/current/verification-plan.md`

Do not load all references upfront — only load what the change requires.

### Step 4: Present update summary and BLOCK until confirmed

```
Apply Briefing Update:

Briefing 修改：
- {list what the user changed, by section}

要更新的 source artifacts：
- {artifact} — {what will change}

確認套用？
```

**This is a blocking gate.** Do not skip this step, and do not proceed to ANY other work until this gate is resolved:
- **Confirm** → proceed to Step 5.
- **Decline** → ask for the reason, then skip Step 5. Gate resolved.
- **Adjust** — the user wants to change how the update is applied (e.g., different diff, scope tweak, naming). This is related discussion — continue refining the update summary with the user until reaching a conclusion, then re-present the revised summary for confirmation.
- **Unrelated response** — the user gives instructions, questions, or tasks that are not about this update. Do NOT process them. Re-surface the confirmation question and explain that this gate must be resolved first (confirm, decline, or adjust).

Only after the gate is resolved (confirm or decline) can you proceed to other user requests.

### Step 5: Apply changes

After user confirmation, update only the affected sections in each target artifact. Follow the format conventions of each target file.

Key rules:
- **Surgical updates** — touch only what changed. Don't rewrite unaffected sections.
- **Preserve structure** — each target has its own format (plan uses plan-template structure, BDD uses Given/When/Then). Transform the briefing's narrative back into the target's native format.
- **Section 5 → BDD**: When the user changes a scenario's behavior description, update `bdd-scenarios.md` in Given/When/Then format. When they change a verification method, update `verification-plan.md`. Use the incremental update approach from `behavior-validation-plan`.

### Step 6: Run sync checklist

Read this skill's `references/sync-policy.md` and run the 8-point sync checklist. Every item must pass.

If any check fails: identify the discrepancy → fix → re-run the full checklist. Changes can cascade.

### Step 7: Confirm

```
Update 完成。

已更新：{list of files changed}
變更內容：
- {list specific changes per file}

Sync checklist: 8/8 passed.
```

## Key Principles

- **Confirmation before action** — Document changes are high-trust operations. Never modify files without showing the user what will change and getting approval.
- **Surgical updates** — Touch only what changed. Full rewrites obscure what's new and make review harder.
- **On-demand reference loading** — Only read the format references needed for the specific change. Don't load everything upfront.
- **Briefing is the source** — The user's edit to the briefing is the intent. Transform it into the appropriate format for each target artifact, but don't alter the intent.
