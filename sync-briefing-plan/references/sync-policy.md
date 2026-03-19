# Briefing ↔ Implementation Plan Sync Policy

The briefing and the implementation plan are **two views of the same work**. They stay in sync because when they disagree, the reviewer sees one story while the agent executes another — that's how misaligned work ships.

---

## Source of Truth Hierarchy

When documents disagree, resolve conflicts using this hierarchy:

1. **Code** — Ultimate truth. It's what actually runs.
2. **Plan** — Describes intended behavior and execution steps.
3. **Briefing** — Derived view of the plan for human consumption.

If code diverges from both documents, both update to match the code — not the other way around.

---

## Does This Change Need Sync?

Not every change requires sync. The key question: **does this change affect what a reviewer would need to know?**

1. **Affects a design decision?** → Sync both. Reviewer needs to re-approve.
2. **Adds, removes, or modifies task scope?** → Sync both. Different work = different review.
3. **Alters risk profile or blast radius?** → Update Risk Assessment in both.
4. **Affects test strategy (new tests, changed tests)?** → Update Test Impact Matrix in briefing + test section in plan.
5. **Purely cosmetic (typo, formatting, variable rename)?** → No sync needed.

---

## How to Sync

### Step-by-Step Process

1. **Identify the source of change** — Which artifact was modified? (Briefing / Plan / Code)

2. **Diff the change** — Understand exactly what changed:
   - Briefing changed → Which sections? What content moved, added, or removed?
   - Plan changed → Which tasks? What decisions, scope, or approach shifted?
   - Code changed → What diverged from the plan? Why?

3. **Map the impact** — Determine which sections in the OTHER document are affected:

   | Briefing Section         | Corresponding Plan Content                            |
   | ------------------------ | ----------------------------------------------------- |
   | Design Overview          | Architectural approach, technology choices, data flow |
   | File Impact Map          | Task file targets, new/modified/deleted files         |
   | Task Breakdown           | Task list, task scope, task order                     |
   | Test Impact Matrix       | Test files, guardrail tests, adjusted tests           |
   | Environment / Config     | Environment variables, dependencies                   |
   | Risk Assessment          | Risk analysis, blast radius                           |
   | Decisions & Verification | Design decisions, verification steps                  |

4. **Present a sync summary** to the user BEFORE applying changes:

   ```
   Sync Summary:

   Direction: {Briefing→Plan / Plan→Briefing / Code→Both}

   Source changes:
   - {list what changed}

   Target updates needed:
   - {list affected sections with what will change in each}

   Proceed with sync?
   ```

   Presenting before acting matters because document changes are hard to review after the fact. The user may disagree with the sync direction or want to handle certain sections differently.

5. **Apply changes** after user confirmation — update only affected sections. Unnecessary rewrites introduce noise and make it harder to verify what actually changed.

6. **Add update marker:**

   ```markdown
   > Updated: [date] — [what changed and why]
   ```

### Sync Direction Rules

| Source of Change                 | Sync Direction         |
| -------------------------------- | ---------------------- |
| Briefing updated (user feedback) | Briefing → Plan        |
| Plan updated (agent refinement)  | Plan → Briefing        |
| Code diverged from plan          | Code → Plan → Briefing |
| Code review changed design/scope | Code → Plan → Briefing |

If it's unclear what changed or who changed it — ask the user before proceeding.

---

## Sync by Scenario

### User feedback on briefing

User comments on briefing content (e.g., "this design decision should be X instead of Y", "add an edge case for Z").

1. Apply changes to briefing.
2. Identify which plan sections are affected (design decisions, task scope, test cases).
3. Propagate those changes to the implementation plan.
4. Run sync checklist.

### User feedback on plan

User comments on plan content (e.g., "task 3 should also handle error case", "change the approach for step 5").

1. Apply changes to plan.
2. Identify which briefing sections reference the changed content.
3. Update those briefing sections.
4. Run sync checklist.

### Plan updated by agent

Plan is modified by the agent (e.g., new task added, task reordered, scope refined after exploration).

1. Diff plan changes.
2. Update briefing to reflect new/changed/removed tasks, decisions, or scope.
3. Run sync checklist.

### Code diverges during implementation

Agent discovers the implementation must differ from the plan (e.g., API works differently than expected, dependency forces a different pattern).

1. Update plan to reflect what was actually implemented and why.
2. Update briefing to match (Design Overview diagrams, Task Breakdown, Risk Assessment).
3. Add update marker to both documents.
4. Run sync checklist.

### Code changes after code review

Code review feedback that results in design or scope changes follows the same flow as "Code diverges during implementation." Cosmetic changes (rename, formatting) don't need sync.

1. Apply code changes.
2. If changes affect design/scope/risk → update both plan and briefing.
3. If cosmetic/minor → no sync needed.
4. Run sync checklist.

---

## Sync Checklist

After every sync operation, all 8 items must pass:

| # | Check                                       | How to Verify                                                                                          |
|---|---------------------------------------------|--------------------------------------------------------------------------------------------------------|
| 1 | Design Overview matches plan's approach     | Compare briefing diagrams against plan's architectural description                                     |
| 2 | Task Breakdown matches plan's task list     | Every plan task has a briefing entry; every briefing entry maps to a plan task. No orphans.             |
| 3 | Design Decisions are identical              | Same choices, same rationale in both documents                                                         |
| 4 | File Impact Map matches plan's file targets | Every file in plan tasks appears in briefing's File Impact Map with correct action (create/modify/delete) |
| 5 | Test Impact Matrix reflects test strategy   | Guardrail and adjusted tests match; new TDD tests (Section 4) not duplicated here                      |
| 6 | Risk Assessment covers current scope        | No stale risks from previous plan version; no new risks missing                                        |
| 7 | Verification steps are still valid          | E2E scenarios in Section 8 still make sense given any changes                                          |
| 8 | Environment / Config is current             | Env vars and dependencies match what plan and code actually require                                    |

### When a Check Fails

1. Identify the discrepancy.
2. Determine which document is correct (check code if unclear).
3. Update the incorrect document.
4. Re-run the **full** checklist — changes can cascade. Fixing one discrepancy may reveal another.

Preserve any user-added annotations in both documents during updates.
