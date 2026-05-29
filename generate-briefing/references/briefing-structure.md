# Briefing Structure Guide

Reference this document when **creating a new briefing**. It defines each section's purpose, source, format, and content requirements.

Generate the briefing with **5 required sections + 2 conditional sections**, in order. Each section pulls from specific source artifacts — the briefing is an aggregation layer, not a new analysis.

**Language:** Write prose in Traditional Chinese (zh-TW). Technical terminology stays in English — file paths, function names, CLI commands, code snippets, and Mermaid diagram node labels.

**Sources:**
- `impl` = `artifacts/current/implementation.md`
- `bdd` = `artifacts/current/bdd-scenarios.md`
- `vp` = `artifacts/current/verification-plan.md`
- `design` = `artifacts/current/design.md`

---

## Section 1: Design Delta（conditional — requires design.md）

**Reviewer question**: _"Did implementation planning surface anything the design missed? Do I need to revisit the design before reviewing the rest?"_

**Source**: Sub-agent output from `agents/design-delta-reviewer.md` (compares `impl` against `design`)

This section comes first because deltas may invalidate downstream decisions. The reviewer should resolve these before proceeding to the rest of the briefing.

**Only include when** `design.md` exists. Without a design baseline, there's nothing to compare — skip and start the briefing from Section 2.

**When sub-agent returns `DELTAS_FOUND`**: paste the sub-agent output directly — each finding uses an `####` header for its title, with Design 原文 / 實際情況 / 影響 / Resolution as top-level bullets underneath. Group findings under `###` subheadings by Resolution category:

1. `### 需補充 design` (blockers — listed first if any)
2. `### 需確認` (reviewer judgment needed)
3. `### 已解決` (informational)

Omit any subheading that has no entries.

If any finding is categorized as「需補充 design」, add a prominent callout at the top of the section:

> ⚠️ 以下有 N 項發現需要回到 design 階段補充，建議先處理再繼續檢閱。

**When sub-agent returns `NO_DELTAS`**: include the section with a one-line confirmation:

> 實作規劃未發現與 design 不一致的項目，可直接檢閱後續內容。

---

## Section 2: Overview

**Reviewer question**: _"What is this change, how big is it, and what should I worry about?"_

**Source**: `impl` (Goal + task count + constraints)

One paragraph. Three things: what this change does, how many tasks, and the single biggest risk. No bullet points, no sub-headers — just a paragraph.

Example:
> 本次新增 streaming chat endpoint，共拆為 4 個 task。最大風險是 SSE event format 與前端 parser 的契約需要精確對齊，parser 容錯不足可能導致 partial response 被丟棄。

---

## Section 3: File Impact

**Reviewer question**: _"What files are changing, and how do they relate to each other?"_

**Source**: `impl` (File Plan)

### (a) Folder Tree

Always include. Show the file tree with annotations for new/modified/deleted files. Use IDE-style tree format.

- **New files**: annotate with `(new — short purpose)` so the reviewer understands what each file does at a glance.
- **Modified/deleted files**: annotate with `(modified)` or `(deleted)`.
- **Unchanged files**: omit entirely — only show files that are part of the change.

```
src/
├── api/
│   ├── routes.ts              (modified)
│   └── streaming.ts           (new — SSE endpoint handler)
├── services/
│   ├── chat.ts                (modified)
│   └── sse-encoder.ts         (new — event serialization)
└── types/
    └── events.ts              (new — StreamEvent type defs)
```

### (b) Dependency Flow (conditional)

**Only include when** the File Plan contains enough dependency or data-flow information to produce a meaningful diagram. If the plan only lists files and purposes without clear inter-file relationships, skip this part — do not guess at dependencies.

When included, use a Mermaid `graph` with these conventions:

- **Nodes**: Color-code by change type — green (`style ... fill:#90EE90`) for new, blue (`fill:#87CEEB`) for modified, red (`fill:#FFB6C1`) for deleted. Unchanged dependency nodes use default styling (no color).
- **Unchanged dependencies**: Include unchanged files that new/modified files depend on — the reviewer needs the full dependency chain, not just changed nodes.
- **Edge labels**: Annotate arrows with a concise reason for the dependency. One to three words — enough to answer "why does A depend on B?" without being vague. Use specifics when a single word is ambiguous (e.g., `loads config` over just `loads`; but `imports` alone is fine when context is obvious).
- **Legend**: Add a `subgraph Legend` at the bottom of the diagram so the color-coding is self-explanatory.

Example:

```mermaid
graph TD
    Runner -->|loads config| Config
    Runner -->|calls CSV parse| Loader
    Runner -->|resolves scorers| Registry
    LangScorer -->|imports CJK utils| Helpers

    style Runner fill:#90EE90
    style Config fill:#90EE90
    style Loader fill:#90EE90
    style Registry fill:#90EE90
    style LangScorer fill:#90EE90
    style Helpers fill:#87CEEB

    subgraph Legend
        N[New] --- M[Modified] --- U[Unchanged]
        style N fill:#90EE90
        style M fill:#87CEEB
        style U fill:#f5f5f5
    end
```

---

## Section 4: Task 清單

**Reviewer question**: _"What work is being done, and why?"_

**Source**: `impl` (each task's summary)

A table. One row per task. No implementation details, no TDD test cases, no architecture.

| Task | 做什麼 | 為什麼 |
|------|--------|--------|
| 1 | 建立 SSE encoder utility | 統一 streaming event 的序列化格式 |
| 2 | 新增 /api/chat/stream endpoint | 前端需要 streaming response 介面 |
| 3 | 修改 ChatService 支援 streaming output | 原本只支援 batch response |
| 4 | 定義 StreamEvent type definitions | 確保前後端 event 契約一致 |

"做什麼" is one sentence describing the deliverable. "為什麼" is one sentence explaining the motivation. Extract from each task's What & Why in the implementation plan.

---

## Section 5: Behavior Verification

**Reviewer question**: _"What behaviors are being tested, and how do we verify them?"_

**Source**: `bdd` (scenarios) + `vp` (verification methods) + `impl` (task-to-scenario mapping)

Split into three subsections: **5.1 During Implementation** (by Task), **5.2 Post-Implementation** (deferred), **5.3 User Acceptance Test** (reviewer responsibility).

### Summary line

Start the section with a one-line summary counting total scenarios and journeys across all features:

```markdown
> 共 N 個 illustrative scenarios（S-*）+ M 個 journey scenarios（J-*），涵蓋 K 個 features。
```

### 5.1 During Implementation（按 Task 組織）

Group scenarios by the **Task** that verifies them (from `impl` task → BDD scenario mapping). Each Task is an `####` heading showing the Task name and its TC IDs. Scenarios within each Task use collapsible callouts.

Every scenario body must include a `Source verification:` line linking to the specific TC that verifies it. If a scenario has additional post-impl depth, note it with `Additional depth:`.

```markdown
#### Task 2 — Ingest Atomicity（`TC-int-ingest-idempotent-01`, `TC-int-ingest-atomicity-01`）

> [!example]- **S-ing-04** — 重複 ingest 相同 filing 不會產生 duplicate points（UUID5 deterministic ID）
>
> - Ingest NVDA 兩次，Qdrant point count 不變
> - Source verification: integration `TC-int-ingest-idempotent-01`
```

### 5.2 Post-Implementation Deferred Verifications

Scenarios that require real external services (real API calls, real corpus, real Langfuse/Braintrust) and cannot be tested with mocks during TDD. Group by verification mechanism (e.g., "Real corpus + Qdrant", "Journey scenarios").

If a scenario was partially covered during-implementation and has post-impl supplementary verification, mark it with `(post-impl 補強)` after the scenario ID.

```markdown
> [!example]- **S-ing-01** (post-impl 補強) — Class B 和 Pathological 的 real filing heading degradation
>
> - Class B：部分 chunk 有 h3 深度，部分只到 Item level
> - Pathological：header_path = `"<ticker> / <year>"`，item = `"_unknown"`
```

### 5.3 User Acceptance Test（PR Review 時執行）

Pull out User Acceptance Test scenarios into this separate subsection. This tells the reviewer which scenarios are **their responsibility** during PR review.

```markdown
**J-eval-01 — acceptance** 🖐️<br>
Braintrust dashboard 的 scorer columns 數值合理。<br>
→ Reviewer 在 PR Review 時檢閱 Braintrust dashboard
```

### Collapsible scenario format

Each scenario uses **Obsidian callout syntax** with the `-` suffix (collapsed by default) so reviewers can scan titles without being overwhelmed by details. The callout title contains the scenario ID and a **complete behavior statement**.

**Callout types by scenario category**:
- Illustrative scenarios (S-*): `> [!example]-`
- Journey scenarios (J-*): `> [!abstract]-`

**Manual scenarios**: If the verification method is Manual Behavior Test, append 🖐️ to the callout title. This lets reviewers instantly spot which scenarios require manual effort when scanning the collapsed list.

**Important**: Leave a blank line (`>`) between the title line and the bullet list content for markdown to render correctly inside the callout.

### Scenario title: complete behavior statement

The callout title must be a **complete behavior statement** a reviewer can understand without expanding. Describe what happens and what the outcome is — not just a noun phrase.

Bad: `完整 scenario 目錄被發現並執行`（缺少結果）
Good: `包含 dataset.csv 和 eval_spec.yaml 的 scenario 目錄被自動發現，執行後產出 result CSV`

### Scenario body: concrete examples

Core behavior scenarios show the full input → setup → expected output chain. Edge case scenarios focus on the specific trigger condition and expected error/recovery behavior. Every scenario must include `Source verification:` linking to its TC.

### Rules for this section

- **Do not rewrite behaviors** — transform the format (Given/When/Then → narrative), not the content.
- **Do not add or remove scenarios** — the briefing reflects exactly what bdd-scenarios.md defines.
- **Do not omit verification methods** — every scenario must show how it's verified.
- **Keep scenario IDs** — they provide traceability back to the source artifacts.
- **Group during-implementation by Task, not by Feature** — the reviewer needs to know when each scenario is verified relative to the implementation timeline.

---

## Section 6: Test Safety Net

**Reviewer question**: _"Will this change break existing things?"_

**Source**: `impl` (test strategy sections across tasks)

Do NOT list test file names — describe coverage semantically. Split into three sub-sections based on the test's role. Omit any sub-section that has no entries.

### Guardrail（不需改的既有測試）

Narrative description. List the impact areas and briefly describe which behaviors are still protected by existing tests. No table needed — a few bullet points or a short paragraph is sufficient.

Example:
> - **Chat API routing** — request dispatch、auth guard、rate limiting 皆有 integration tests 覆蓋，不受本次改動影響。
> - **Frontend message parser** — text rendering、markdown parsing、code block highlighting 有 snapshot tests 及 interaction tests 保護。

### 需調整的既有測試

Table format. Show what's currently covered and why it needs adjustment.

| 影響區域 | 目前覆蓋 | 調整原因 |
|----------|---------|----------|
| ChatService batch mode | single request → response, error handling | Interface 從 sync 改成 stream，assertions 需對應新的 response format |

### 新增測試

High-level description of what the new tests will cover. If it's just a few areas, use bullet points instead of a table.

Example:
> - SSE encoder：event serialization format、chunk boundary handling
> - StreamEvent types：type guard validation、edge cases for malformed events

---

## Section 7: Environment / Config 變更（conditional）

**Reviewer question**: _"Are there new environment variables, dependencies, or deployment changes?"_

**Source**: `impl` (dependencies verification table, constraints, env-related task content)

**Only include this section when** there are actual environment, dependency, or config changes. If the change is purely code, this section does not appear.

When included:
- New/changed environment variables (before → after)
- New dependencies with version and purpose
- CI/CD or deployment impact

---

## Anti-Patterns

- **Generating new analysis** — If it's not in the source artifacts, it doesn't belong in the briefing. The briefing is a lens, not a source.
- **Wall of text** — More than 5 lines of prose without a visual break. Add a table, list, or diagram.
- **Including per-task TDD tests** — Individual test cases stay in the plan. The briefing shows BDD scenarios and test safety net.
- **Forcing conditional sections** — Section 7 appears only when there's real content. Empty sections with "無" or "N/A" are noise. Section 1 (Design Delta) is the exception: when design.md exists, always include it (even a "no deltas" confirmation has value).
- **Rewriting BDD scenarios** — The narrative transforms the format, not the content. Don't add, remove, or modify the behaviors defined in bdd-scenarios.md.
- **Mixing User Acceptance Test with other scenarios** — User Acceptance Test scenarios must be in their own subsection so the reviewer knows which ones are their responsibility during PR review.
