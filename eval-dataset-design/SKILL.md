---
name: eval-dataset-design
description: >-
  Research-backed methodology for designing evaluation datasets for LLM and AI agent systems:
  choosing scoring methods (binary checklist, Likert, rubric), question-generation pipelines,
  programmatic + LLM-as-judge scoring infrastructure, and cross-version quality tracking. Use
  for any eval-dataset, evaluation-rubric, or LLM-judge design work, even if the user doesn't
  say 'evaluation dataset' explicitly.
---

# Eval Dataset Design

A methodology guide for designing rubric-based evaluation datasets for LLM and AI agent systems. Grounded in academic research and production experience, this skill helps you make informed decisions about scoring, generation, and pipeline architecture — without prescribing a single rigid approach.

## Core Philosophy

Evaluation dataset design involves three interconnected decisions that compound on each other. Getting the scoring method right shapes everything downstream — the rubric dimensions, how questions are generated, and how the scoring pipeline is built. This skill walks through each decision in order, explaining the tradeoffs so you can adapt to your specific system.

## Decision Flow

Work through these in sequence. Each decision constrains the next:

```
1. Define Scope → Snapshot eval or cross-version tracking?
2. Choose Scoring Method → Binary checklist / Likert / open-ended?
3. Design Rubric Dimensions → What aspects of quality matter?
4. Define Question Categories → Aligned with agent capabilities
5. Select Generation Approach → Manual / LLM-prompt / framework / hybrid?
6. Build Scoring Pipeline → Programmatic + LLM-as-judge
7. Set Up Reporting → Breakdowns, trends, evidence
```

---

## 1. Define Evaluation Scope

Before designing anything, clarify what you're measuring and why.

**Snapshot evaluation** tests a single version of your system at a point in time. Good for launch readiness or regression testing. The dataset can be smaller and more focused.

**Cross-version tracking** measures how quality evolves as you add features, swap models, or change prompts. This is more demanding — the dataset needs to be stable across versions, and your scoring must be reproducible enough to detect real improvements vs. noise.

Cross-version tracking is more valuable in practice (you almost always want to know "did this change make things better?"), but it requires more upfront investment in scoring consistency. If you're just starting out, design for cross-version from the beginning — it's easier to simplify later than to retrofit.

## 2. Choose a Scoring Method

This is the highest-leverage decision. Read `resources/scoring-methods.md` for the full comparison, but here's the executive summary:

**Binary checklist (recommended for most cases)**
Each checkpoint is a specific yes/no question about the response. Score = checkpoints passed / total. Research shows binary questions improve inter-evaluator agreement by 0.45 over Likert scales (CheckEval, arXiv:2403.18771), and they're straightforward to automate with LLM-as-judge.

**Likert scale** (1-5 or 1-7 per dimension) gives finer granularity but lower consistency between evaluators. Harder to automate reliably.

**Open-ended rubric** (free-form evaluation with guidelines) is best for exploratory evaluation only — useful when you don't yet know what dimensions matter, but not for systematic tracking.

The binary checklist approach works well because it decomposes a subjective judgment ("is this response good?") into many objective micro-judgments ("does this response cite its source?"). Each individual judgment is easier for both humans and LLMs to make consistently.

## 3. Design Rubric Dimensions

Good rubrics cover three orthogonal groups. Keeping them separate prevents conflation and makes it clear which aspects of quality are improving or regressing:

**Correctness** — Did the system do the right thing?
- Action/tool invocation accuracy
- Argument/parameter correctness
- Factual grounding (claims supported by retrieved data)
- Error handling (graceful failure when things go wrong)

**Faithfulness** — Is the output honest?
- No fabricated claims beyond source material
- Question actually answered (relevance, not just surface similarity)

**Quality** — Is the output well-crafted?
- Source attribution
- Specificity (concrete numbers vs. vague descriptions)
- Structure and organization
- Completeness (all parts of the question addressed)
- Confidence calibration (appropriate certainty level)
- Temporal awareness (acknowledges data freshness)
- Reasoning quality (logical flow)
- Source diversity (integrates multiple sources)
- Language quality (professional, domain-appropriate)

Not every checkpoint applies to every question. Your dataset schema should specify which checkpoints are relevant per question, so scoring doesn't penalize questions for missing inapplicable criteria.

For deeper background on how these dimensions were derived, see `resources/academic-references.md` (especially DEER and Samaya Criteria-Eval).

## 4. Define Question Categories

Categories should align with your agent's actual capabilities — not with abstract taxonomies. Each category represents a distinct type of task your agent handles.

**Design principles:**
- Categories should be **mutually exclusive** (a question belongs to exactly one)
- Use **tags** for cross-cutting concerns (difficulty, complexity, multi-step reasoning) rather than making them categories
- Aim for **7-12 categories** — enough for meaningful breakdowns, not so many that each bucket is tiny
- Each category should have a clear connection to specific tools or capabilities

**ID naming convention**: Use semantic IDs like `{PREFIX}-{CATEGORY}-{SEQ}` (e.g., `QA-RETRIEVAL-001`). This makes it easy to filter and analyze results by category without parsing metadata.

## 5. Select a Generation Approach

How you create evaluation questions matters as much as what you measure. See `resources/generation-strategies.md` for detailed comparison. The short version:

| Approach | Control | Diversity | Scale | Domain Expertise Needed |
|----------|---------|-----------|-------|------------------------|
| Manual authoring | Highest | Lowest | ≤30 questions | Yes |
| LLM prompt-driven | High | Medium | 30-100+ | No (prompt engineering) |
| Framework-based (RAGAS/DeepEval) | Lower | Highest | Unlimited | No |
| Hybrid (LLM + framework) | High | High | 50-100+ | No |

**Hybrid is usually the best default.** Use LLM prompts as primary generation (70-80%) for control over categories and tool alignment, then framework-based generation (20-30%) for linguistic diversity. This requires a merge pipeline with deduplication, but the coverage improvement is worth it.

For framework details, see `resources/framework-comparison.md`.

## 6. Build the Scoring Pipeline

A good scoring pipeline has two tiers, each playing to its strengths:

**Tier 1: Programmatic checks** — Fast, deterministic, reproducible. Use these for anything you can verify directly: tool calls made, arguments passed, numerical accuracy (numbers in response match source data), error handling patterns. These run in milliseconds and never drift.

**Tier 2: LLM-as-judge** — For subjective or nuanced checkpoints that resist programmatic verification: faithfulness, reasoning quality, language quality, completeness. Key design principles:

- **One prompt per checkpoint.** A single giant prompt asking about 10 things at once produces worse results than 10 focused prompts. Each checkpoint gets its own judge call asking one specific yes/no question.
- **Lock the judge model and temperature.** Use temperature=0 and pin the model version. If the judge model changes between eval runs, you can't tell whether score changes reflect your system improving or the judge shifting.
- **Save judge logs.** Every judge call should be logged with the prompt, response, and parsed result. This makes debugging easy and enables spot-checking.
- **Spot-check 10-20% of judge results.** LLM judges are good but not perfect. Periodic human review catches systematic errors before they distort your metrics.

## 7. Set Up Reporting

**Report scores, not verdicts.** Present the numbers and let stakeholders interpret them. Setting pass/fail thresholds prematurely creates pressure to game the metric rather than improve the system.

**Useful breakdowns:**
- By category (which types of questions does the system struggle with?)
- By checkpoint group (correctness vs. faithfulness vs. quality)
- By difficulty tag
- By individual checkpoint (which specific quality dimensions are weak?)

**For cross-version tracking:**
- Score trends over time (line charts per checkpoint group)
- Delta reports (what changed between v(N) and v(N+1)?)
- Per-question diffs (which specific questions flipped pass/fail?)

**Save raw results as JSON.** Your reporting format will evolve, but if you have the raw data, you can always re-analyze.

## Dataset Schema

Every eval question should include:

```json
{
  "id": "PREFIX-CATEGORY-001",
  "question": "The actual question text",
  "category": "retrieval",
  "expected_behavior": {
    "tools": [{"name": "search_tool", "args": {"query": "..."}}],
    "notes": "Should retrieve and synthesize from multiple sources"
  },
  "applicable_checkpoints": ["C1", "C2", "F1", "Q1", "Q3", "Q7"],
  "tags": {
    "difficulty": "medium",
    "multi_step": true,
    "question_type": "analytical"
  },
  "metadata": {
    "generation_method": "llm_prompt",
    "version_added": "1.0"
  }
}
```

The `applicable_checkpoints` field is important — it specifies which checkpoints should be scored for this question. Not every checkpoint makes sense for every question (e.g., "uses multiple sources" doesn't apply to a simple lookup question).

## Resources

Detailed reference materials for deeper exploration:

- `resources/scoring-methods.md` — Full comparison of binary checklist vs. Likert vs. open-ended, with research backing
- `resources/generation-strategies.md` — Detailed guide to each generation approach with prompt design best practices
- `resources/framework-comparison.md` — RAGAS vs. DeepEval capabilities, integration patterns, and when to use which
- `resources/academic-references.md` — Paper summaries, production examples, and benchmark designs that informed this methodology
