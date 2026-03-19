# Evaluation Dataset Generation Strategies

## Table of Contents

1. [Manual Authoring](#manual-authoring)
2. [LLM Prompt-Driven Generation](#llm-prompt-driven-generation)
3. [Framework-Based Generation](#framework-based-generation)
4. [Hybrid Approach](#hybrid-approach)
5. [Merge Pipeline](#merge-pipeline)
6. [Quality Assurance](#quality-assurance)

---

## Manual Authoring

**When to use**: Small gold-standard datasets (< 30 questions), calibration/validation subsets, or when domain experts are readily available.

**Strengths**: Highest precision, full control over difficulty and coverage, reliable ground truth.

**Limitations**: Doesn't scale, requires deep domain expertise, slow and expensive.

**Best practice**: Even if you use automated generation for the bulk of your dataset, consider manually authoring a small "anchor set" (10-15 questions) that you deeply understand. This anchor set serves as a sanity check for your scoring pipeline and helps calibrate LLM judges.

---

## LLM Prompt-Driven Generation

**When to use**: Medium to large datasets (30-100+ questions), agent systems with specific tool signatures, or when the operator lacks domain expertise.

**How it works**: Design category-specific prompts that instruct an LLM to generate structured evaluation questions. Each prompt targets one category and includes enough context about your system's capabilities to produce realistic, testable questions.

### Prompt Design Best Practices

**1. Include system capabilities explicitly**

Don't assume the LLM knows what your agent can do. Provide exact tool signatures, API capabilities, and data sources.

```
Your agent has these tools:
- search(query: str) -> list[Result]  # Searches knowledge base
- calculate(expression: str) -> float  # Evaluates math expressions
- lookup(entity: str, field: str) -> str  # Gets entity attributes
```

**2. Specify output schema**

Define the exact JSON structure you expect. This prevents format inconsistencies across generation runs.

```json
{
  "id": "PREFIX-CATEGORY-001",
  "question": "...",
  "category": "...",
  "expected_behavior": { "tools": [...], "notes": "..." },
  "applicable_checkpoints": ["C1", "C2", "Q1"],
  "tags": { "difficulty": "...", "multi_step": false }
}
```

**3. Enforce diversity rules**

Without explicit rules, LLMs tend to generate similar questions. Specify:
- Entity variety ("use 15+ different entities, not just the popular ones")
- Difficulty distribution ("30% simple, 50% medium, 20% hard")
- Question type mix ("include both quantitative and qualitative questions")
- Phrasing variety ("vary how questions are asked — direct, indirect, multi-part")

**4. List anti-patterns**

Tell the LLM what NOT to generate:
- Questions requiring capabilities your system doesn't have
- Ambiguous questions with multiple valid interpretations
- Questions that are too simple to exercise meaningful quality differences
- Questions that all follow the same template

**5. Provide few-shot examples**

Include 2-3 example questions that demonstrate the quality and variety you want. One simple, one medium, one hard.

### Category Prompt Template

```markdown
# [Category Name] Question Generation

## System Context
[Your agent's tools and capabilities]

## Category: [category_id]
**Goal**: [What type of questions this category covers]

**Coverage Areas**: [Specific topics within this category]

**Diversity Rules**: [Entity variety, difficulty distribution, question types]

**Anti-Patterns to Avoid**: [Common failure modes]

## Output Format
Generate [N] questions in JSON array format:
[schema]

## Examples
[2-3 examples at different difficulty levels]
```

---

## Framework-Based Generation

**When to use**: Diversity expansion, rapid prototyping, or RAG system evaluation.

**How it works**: Frameworks like RAGAS and DeepEval provide built-in question generators that create evaluation questions from documents or schemas.

**Strengths**: Fast, scalable, good linguistic diversity, built-in quality metrics.

**Limitations**: Generated questions may not align with your specific agent capabilities. Lower control over category distribution. Questions tend to be document-centric rather than task-centric.

See `resources/framework-comparison.md` for detailed RAGAS vs DeepEval comparison.

### When framework generation falls short

Framework generators work best for RAG-style systems where questions naturally derive from documents. For agent systems with specific tool signatures, the questions may not exercise the right tool combinations. In these cases, use framework generation for diversity expansion rather than as the primary source.

---

## Hybrid Approach

**When to use**: Production evaluation datasets where both precision and diversity matter.

**How it works**: Use LLM prompt-driven generation as primary (70-80%) for control over categories and tool alignment. Use framework-based generation (20-30%) for linguistic diversity. Merge with deduplication.

### Why this ratio

- **70-80% LLM prompt-driven**: These questions are tightly aligned with your agent's capabilities. Each category prompt produces questions that exercise specific tools and behaviors.
- **20-30% framework-based**: These questions add phrasing variety and edge cases that prompt engineers don't think of. Framework generators are trained on diverse question patterns and introduce natural language variation.

### Implementation workflow

```
1. Generate per-category subsets (LLM prompts)
   └── market_data_questions.json, retrieval_questions.json, ...

2. Generate diversity expansion (framework)
   └── framework_questions.json

3. Run merge pipeline
   └── Deduplicate, validate schema, check distribution

4. Human review (spot-check 10-20%)
   └── Remove bad questions, adjust categories

5. Finalize master dataset
   └── master_eval_dataset.json
```

---

## Merge Pipeline

When combining questions from multiple sources, you need a systematic merge process:

### 1. Schema validation

Every question must conform to your defined schema. Reject questions missing required fields.

### 2. Deduplication

Compare questions by text similarity. Exact matches are obvious, but also catch near-duplicates:
- Same question, different phrasing ("What's X's price?" vs "Tell me the price of X")
- Same intent, different entity ("What's AAPL's price?" vs "What's MSFT's price?" — these are fine, keep both)

A simple approach: check for substring overlap > 80% or use embedding similarity > 0.95.

### 3. ID generation

Assign semantic IDs after merge: `{PREFIX}-{CATEGORY}-{SEQ}` with zero-padded sequence numbers.

### 4. Distribution check

After merge, verify the category distribution is roughly balanced (or intentionally weighted if some categories are more important). Flag if any category has < 5 questions.

### 5. Checkpoint assignment

For framework-generated questions, the `applicable_checkpoints` field may need manual review. Framework generators don't know your specific checkpoint definitions.

---

## Quality Assurance

### Pre-generation

- Review and iterate on prompts before mass generation
- Generate a small batch (5 questions per category) first, review, then scale up

### Post-generation

- Spot-check 10-20% of generated questions for quality
- Verify questions are actually answerable by your system
- Check for unintentional bias (e.g., all questions about the same few entities)
- Run a trial scoring pass to identify questions that consistently score 0 or 14/14 (these may be too hard or too easy to be useful)

### Ongoing

- Track which questions consistently score the same across versions (they're not discriminating)
- Retire questions that become obsolete as your system evolves
- Add new questions for new capabilities
- Version your dataset (include `version` in metadata)
