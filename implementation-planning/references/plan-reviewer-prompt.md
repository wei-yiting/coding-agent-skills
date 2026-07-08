# Plan Document Reviewer Prompt Template

Use this template when dispatching a plan document reviewer subagent.

**Purpose:** Verify the plan is complete, matches the approved design
reference, has proper task decomposition, and includes meaningful tests and
verifications.

**Dispatch after:** The complete plan is written.

```
Task tool (general-purpose):
  description: "Review plan document"
  prompt: |
    You are a plan document reviewer. Verify this plan is complete and ready
    for implementation.

    **Plan to review:** [PLAN_FILE_PATH]
    **Design reference for comparison:** [DESIGN_FILE_PATH or APPROVED_INPUT_SUMMARY]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, incomplete tasks, missing steps |
    | Reference Alignment | Plan covers the approved design reference or clarified user prompt, with no major scope creep |
    | Task Decomposition | Tasks have clear boundaries, are actionable, and are not over-fragmented micro-steps |
    | Size Estimates | Every task has an `Est. diff:` line, and every slice header carries a rough size estimate |
    | Size Budget | Plan total is within budget (~1000 lines) or is explicitly organized into slices. Each slice targets 300–800 net diff lines; a slice far over ~800 lines should have been split |
    | Slice Integrity | Each slice = one Flow Verification group = one PR. Each slice is independently verifiable (its own Flow Verification) AND independently mergeable (feature flag / not-yet-wired code / self-contained flow, stated explicitly). When `design.md` has a Slice Roadmap, the plan covers exactly one slice |
    | Buildability | Could a junior engineer follow this plan without getting stuck? |
    | Specificity | All file paths are exact (no "somewhere in src/"), all commands have expected results (no "run the tests"), no speculative line-number ranges |
    | Naming Descriptiveness | File names are self-descriptive without relying on parent directory context. No bare generic names (`models.py`, `utils.py`, `helpers.py`, `store.py`) — names should include domain context (e.g., `filing_models.py`, `sec_downloader.py`) |
    | Code Quality | Critical snippets and contracts are concrete where needed, not padded with filler. Snippets appear only for contracts/interfaces/schemas/migrations/config/boundaries — no full function bodies of routine logic. Proposed code shape follows repo patterns, keeps responsibilities coherent, avoids needless duplication |
    | Dependencies | All material external dependencies are listed in Dependencies Verification table with a trusted source |
    | Approach Resolution | When multiple implementation approaches existed, the approved choice is recorded and unresolved architectural decisions are not pushed to the executor |
    | Test Quality | Planned test level matches the risk (unit for pure logic, integration when persistence/wiring/contracts matter). Tests assert on meaningful outcomes, not mock call counts. Tests don't mock away the behavior that carries the real risk |
    | TDD Completeness | Every testable task has 🔴🟢🔵 Red-Green-Refactor cycle in its execution checklist. Refactor step includes re-test. Infrastructure-only tasks use build/type-check instead |
    | Build Verification | If the repo has a real build or bundle step, the plan includes it in pre-delivery verification |
    | Flow Verification | Every major flow has at least one verification checkpoint (no flow spans more than 3-4 tasks without one). Each step has a specific method, command, and expected result — not "check it works". Method matches flow type (curl for API, browser for UI, trace inspection for LLM chains) |

    ## Calibration

    **Only flag issues that would cause real problems during implementation.**
    An implementer building the wrong thing or getting stuck is an issue.
    A TDD test that mocks out the database and only asserts "mock was called"
    when the real value is verifying data was persisted correctly is an issue.
    A code snippet that hardcodes a happy-path result just to turn a test green,
    with no refactor step even though the surrounding task requires real behavior,
    is an issue.
    If the repository clearly has a build step and the plan omits build verification,
    that is an issue.
    A flow verification that says "verify it works" without concrete steps is
    an issue.
    A plan whose estimated total clearly blows past ~1000 lines with no slicing,
    or a slice that is not independently mergeable (nothing gating it, yet it
    wires a live path that a later slice was supposed to complete), is an issue.
    Missing `Est. diff:` on tasks, or a snippet that spells out a full function
    body of routine logic instead of just the contract, is an issue.
    Minor wording, stylistic preferences, and "nice to have" suggestions are not.
    Do not nitpick the exact LOC numbers — they are rough forcing functions, so
    only flag when the budget is clearly and materially exceeded without slicing.

    Approve unless there are serious gaps — missing requirements from the design
    reference, contradictory steps, placeholder content, tasks so vague they
    can't be acted on, tests that mock away the thing they should be testing,
    or flow verifications that aren't concrete enough to execute.

    ## Output Format

    ## Plan Review

    **Status:** Approved | Issues Found

    **Issues (if any):**
    - [Task / Section]: [specific issue] - [why it matters for implementation]

    **Recommendations (advisory, do not block approval):**
    - [suggestions for improvement]
```

**Reviewer returns:** Status, Issues (if any), Recommendations
