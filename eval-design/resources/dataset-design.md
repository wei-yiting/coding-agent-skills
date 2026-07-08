# Dataset Design

How to build and grow the eval dataset: task quality bars, categories, scoring-method
choice, generation strategies, and the Braintrust row schema.

## Table of Contents

1. [Task quality bar](#1-task-quality-bar)
2. [Composition & balance](#2-composition--balance)
3. [Categories & tags](#3-categories--tags)
4. [Scoring method: binary checklist by default](#4-scoring-method-binary-checklist-by-default)
5. [Rubric dimensions](#5-rubric-dimensions)
6. [Generation strategies](#6-generation-strategies)
7. [Braintrust row schema](#7-braintrust-row-schema)
8. [Maintenance](#8-maintenance)

---

## 1. Task quality bar

Every task must clear these gates before entering the dataset:

- **Two-expert test**: two domain experts, working independently, would reach the same
  pass/fail verdict. If they'd argue, the task is ambiguous — rewrite or drop it.
- **Expert-passable**: a domain expert could complete the task themselves. If not, the task
  is testing something other than competence.
- **Reference solution**: a known-good output that provably passes all graders. This is how
  you know the task is solvable and the graders are consistent with each other.
  Heuristic: with frontier models, **a 0% pass rate across many trials is most often a
  broken task, not an incapable agent** — missing files, contradictory specs, impossible
  constraints.
- **Unambiguous spec**: the task states what's checked. Contradictions between task text and
  grader (e.g., task says "reach threshold X", grader requires "exceed X") silently punish
  instruction-following models.

Start with **20–50 tasks** sourced from real failures (Phase 2 taxonomy), existing manual
pre-release checks, bug trackers, and support queues. Do not wait for hundreds — early on,
changes have large effect sizes and small samples detect them; grow the suite as effect
sizes shrink.

## 2. Composition & balance

- **Positive AND negative cases** per behavior. If you test "agent searches the web when
  needed", include queries where searching is wrong ("who founded Apple?"). One-sided sets
  create one-sided optimization — the agent learns to always do the thing.
- **Typical / edge / adversarial** mix, matching production traffic distribution. A dataset
  whose distribution diverges from production is the "biased design" anti-pattern: great
  scores, unhappy users. Edge dimensions worth deliberate coverage:
  - Input variability: other languages, formats (JSON/CSV/Markdown), typos, minimal context.
  - Contextual complexity: multiple intents in one request, long conversations,
    ambiguous tool results, multi-tool sequences.
  - Personalization/abuse: jailbreak attempts, user-prompt-vs-system-prompt conflicts —
    define explicitly what you support and what you block.
- **Difficulty spread** via tags (see below), e.g. 30% simple / 50% medium / 20% hard.

## 3. Categories & tags

Categories align with the agent's *actual capabilities* (usually 1:1 with the failure
taxonomy + core task types), not abstract taxonomies.

- Mutually exclusive; a task belongs to exactly one category.
- **7–12 categories** — enough for meaningful breakdowns, not so many each bucket is tiny.
  Flag any category with < 5 tasks.
- Cross-cutting concerns (difficulty, multi-step, adversarial) are **tags**, not categories.
- Semantic IDs: `{PREFIX}-{CATEGORY}-{SEQ}` (e.g. `QA-RETRIEVAL-001`) make results filterable
  without joins.

## 4. Scoring method: binary checklist by default

Decompose "is this response good?" into specific yes/no checkpoints; score = passed/total.

Why binary wins (CheckEval, arXiv:2403.18771 — +0.45 inter-evaluator agreement vs Likert):
- Each micro-judgment ("does it cite a source?") is cognitively simple for humans and LLMs.
- Results compose ("87% cited sources") and are auditable (YES/NO disagreements are visible;
  3-vs-4 disagreements are not).
- Maps directly onto scorers: each checkpoint = one scorer returning 0/1.

Checkpoint design rules:
- One concept per checkpoint (split compound questions).
- Observable, not inferred ("contains a numeric value" not "understood the question").
- Positive framing (avoid double negatives that confuse judges).
- Per-task applicability: not every checkpoint applies to every task — record
  `applicable_checkpoints` in row metadata so simple lookups aren't punished for
  "uses multiple sources".

Likert (1–5) is acceptable only for exploratory comparison or research reporting; it suffers
anchor drift, central-tendency bias, and noisier LLM judging. If forced: 4-point scale (no
neutral), example-based anchors, report distributions not just means.

Open-ended rubric review is a *discovery* tool: run it on 20–30 responses to find what
matters, then crystallize findings into binary checkpoints. Don't track with it.

## 5. Rubric dimensions

Three orthogonal groups keep improvements attributable:

- **Correctness** — right action/tool, right arguments, factual grounding, error handling.
- **Faithfulness** — no fabrication beyond sources; the question actually answered.
- **Quality** — attribution, specificity, structure, completeness, calibrated confidence,
  reasoning flow, language.

Select dimensions per system (DEER's 7-dimension hierarchy is a useful menu: accuracy,
relevance, completeness, clarity, harmlessness, depth, creativity). For agents, Correctness
and Completeness usually dominate.

## 6. Generation strategies

| Approach | Control | Diversity | Scale | Use for |
|---|---|---|---|---|
| Manual authoring | Highest | Lowest | ≤30 | Anchor set, gold standards |
| LLM prompt-driven | High | Medium | 30–100+ | Primary generation (70–80%) |
| Framework-based (RAGAS TestsetGenerator / DeepEval Synthesizer) | Lower | Highest | Unlimited | Diversity expansion (20–30%), RAG-style systems |
| Structured synthetic + perturbations | High | High | Unlimited | Edge-case expansion |

- **Always hand-author a small anchor set** (10–15 tasks) you deeply understand — it
  sanity-checks the scoring pipeline and calibrates judges.
- **LLM prompt-driven generation** — the prompt must include: exact tool signatures and
  system capabilities; the output schema; diversity rules (entity variety, difficulty
  distribution, phrasing variety); anti-patterns to avoid (questions the system can't
  answer, ambiguous, templated); 2–3 few-shot examples at different difficulties.
  Generate a small batch (5/category) first, review, then scale.
- **Structured synthetic expansion**: define dimensions (channel, intent, persona),
  generate tuples across combinations, then apply perturbations (irrelevant info, typos,
  contradictions) to raise difficulty.
- **Merge pipeline** when combining sources: schema validation → dedup (embedding
  similarity > 0.95 or heavy substring overlap; same intent + different entity is fine,
  keep both) → semantic ID assignment → distribution check → human spot-check 10–20%.

## 7. Braintrust row schema

Braintrust rows are `input` / `expected` / `metadata`. Put rubric bookkeeping in metadata:

```json
{
  "input": { "question": "..." },
  "expected": { "answer": "...", "must_call_tools": ["search"], "reference_notes": "..." },
  "metadata": {
    "id": "QA-RETRIEVAL-001",
    "category": "retrieval",
    "tags": { "difficulty": "medium", "multi_step": true, "adversarial": false },
    "applicable_checkpoints": ["C1", "C2", "F1", "Q1"],
    "source": "production|manual|llm_generated|framework",
    "origin_trace": "langfuse:<trace_id>",
    "version_added": "2026-07"
  }
}
```

`expected` should carry whatever the graders need (reference answer, required tool calls,
key facts) — scorers receive it verbatim. Keep `metadata.source`/`origin_trace` so you can
later measure which sourcing channels produce discriminating tasks.

## 8. Maintenance

- **Grow**: every new production failure mode (Phase 7 harvest) adds cases.
- **Retire/fix**: tasks that are ambiguous, broken, or score identically across every
  version (non-discriminating) — mature benchmarks ship dozens of task fixes
  (τ2-bench: 75+ corrections of wrong expected actions and impossible constraints).
- **Graduate**: near-saturation capability tasks move to the regression suite; add harder
  capability tasks in their place.
- **Version**: rely on Braintrust dataset versioning; experiments record the dataset
  version they ran against, keeping old experiments reproducible. Record `version_added`
  per row for cohort analysis.
