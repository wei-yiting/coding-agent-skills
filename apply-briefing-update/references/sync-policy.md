# Briefing → Source Artifacts Sync Policy

The briefing is the human review surface for the entire development plan. Changes always flow **outward** from the briefing to the source artifacts. There is no reverse direction.

---

## Source Artifacts

| Artifact | Path | Format Reference |
|----------|------|------------------|
| Implementation Plan | `artifacts/current/implementation.md` | `implementation-planning/references/plan-template.md` |
| BDD Scenarios | `artifacts/current/bdd-scenarios.md` | `behavior-validation-plan/references/scenarios-template.md` |
| Verification Plan | `artifacts/current/verification-plan.md` | `behavior-validation-plan/references/verification-plan-template.md` |

---

## Impact Mapping

When a briefing section changes, these are the affected targets:

| Briefing Section | Target | What to update |
|-----------------|--------|---------------|
| Section 1 (摘要) | `implementation.md` | Goal, constraints, or risk description |
| Section 2 (File Impact) | `implementation.md` | File Plan (create/update/delete operations, file structure) |
| Section 3 (Task 清單) | `implementation.md` | Task scope, ordering, or rationale |
| Section 4 (BDD Scenarios) — behavior change | `bdd-scenarios.md` | Scenario descriptions in Given/When/Then format |
| Section 4 (BDD Scenarios) — verification change | `verification-plan.md` | Verification method, commands, or expected results |
| Section 4 (BDD Scenarios) — both | Both BDD files | Update both following `behavior-validation-plan` guidelines |
| Section 5 (Test Safety Net) | `implementation.md` | Test strategy sections across affected tasks |
| Section 6 (Design 未覆蓋的新發現) | `implementation.md` | Constraints or approach decisions |
| Section 7 (Environment / Config) | `implementation.md` | Dependencies, env vars, CI/CD configuration |

### Section 4 special handling

Section 4 merges two source files into narrative format. When the user edits a scenario in the briefing, you need to reverse-transform the change:

1. **Behavior description changed** (the sentence after the scenario ID):
   - Maps back to `bdd-scenarios.md` → update the Given/When/Then for that scenario ID
   - Read `behavior-validation-plan/SKILL.md` for guidelines on incremental scenario updates

2. **Verification method changed** (the line after `→`):
   - Maps back to `verification-plan.md` → update the verification steps for that scenario ID

3. **New scenario added by user**:
   - Add to both `bdd-scenarios.md` (behavior) and `verification-plan.md` (verification)
   - Follow the format conventions in each file's template

4. **Scenario removed by user**:
   - Remove from both `bdd-scenarios.md` and `verification-plan.md`

5. **Scenario moved between categories** (e.g., from Automated to Manual Behavior Test):
   - Update `verification-plan.md` only — the behavior in `bdd-scenarios.md` doesn't change

---

## Does This Change Need Sync?

Not every briefing edit requires propagation. The key question: **does this edit change what the coding agent will execute or validate?**

| Change Type | Needs Sync? |
|-------------|-------------|
| Task scope, ordering, or rationale changed | Yes → `implementation.md` |
| BDD scenario behavior or verification changed | Yes → BDD files |
| File plan changed (add/remove/move files) | Yes → `implementation.md` |
| Test strategy changed | Yes → `implementation.md` |
| Environment/config changed | Yes → `implementation.md` |
| Purely cosmetic (typo, formatting in briefing) | No |
| Reordering briefing content without changing meaning | No |

---

## Scenarios

### User edits task scope (Sections 1-3)

User changes what a task does, adds/removes tasks, or modifies the overall goal.

1. Read `implementation-planning/references/plan-template.md` for format.
2. Read `artifacts/current/implementation.md`.
3. Update affected task sections, file plan, and goal as needed.
4. Run sync checklist.

### User edits BDD scenarios (Section 4)

User changes a scenario's behavior, verification method, or adds/removes scenarios.

1. Read `behavior-validation-plan/SKILL.md` for incremental update guidelines.
2. Read `artifacts/current/bdd-scenarios.md` and/or `artifacts/current/verification-plan.md`.
3. Apply changes following the Section 4 special handling rules above.
4. Run sync checklist.

### User edits test safety net (Section 5)

User modifies the assessment of existing test coverage or risk.

1. Read `artifacts/current/implementation.md`.
2. Update the test strategy sections in affected tasks.
3. Run sync checklist.

### User edits conditional sections (Sections 6-7)

User adds, modifies, or removes discoveries or environment changes.

1. Read `artifacts/current/implementation.md`.
2. Update constraints, approach decisions, or dependency/env sections.
3. Run sync checklist.

---

## Sync Checklist

After every update, all applicable items must pass. Skip items for conditional sections that don't exist.

| # | Check | How to Verify |
|---|-------|---------------|
| 1 | 摘要 matches implementation goal + task count + risk | Compare briefing paragraph against plan header |
| 2 | File Impact matches plan's file plan | Every file in plan appears in briefing tree with correct annotation |
| 3 | Task 清單 matches plan's task list | Every plan task has a briefing row; every briefing row maps to a plan task |
| 4 | BDD scenarios match source artifacts | Every scenario ID in briefing exists in `bdd-scenarios.md`; verification methods match `verification-plan.md` |
| 5 | Test Safety Net reflects plan's test strategy | Guardrail, adjust, and new test descriptions align with plan's test sections |
| 6 | Design 未覆蓋的新發現 still accurate (if present) | Discoveries match plan's constraints and approach decisions |
| 7 | Environment / Config still accurate (if present) | Env vars and dependencies match plan's dependency table |

### When a Check Fails

1. Identify the discrepancy.
2. The briefing is the source of truth for user intent — update the source artifact to match.
3. Re-run the **full** checklist. Changes can cascade.

Preserve any user-added annotations in all documents during updates.
