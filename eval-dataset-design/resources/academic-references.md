# Academic References & Production Examples

Research papers, benchmarks, and production systems that inform evaluation dataset design methodology. Organized by topic area with actionable takeaways.

## Table of Contents

1. [Scoring Methodology Research](#scoring-methodology-research)
2. [Rubric Design Research](#rubric-design-research)
3. [Benchmark Design Examples](#benchmark-design-examples)
4. [Production Evaluation Systems](#production-evaluation-systems)
5. [Tools & Frameworks](#tools--frameworks)

---

## Scoring Methodology Research

### CheckEval (arXiv:2403.18771)

**Key finding**: Binary checklist questions improve inter-evaluator agreement by 0.45 compared to Likert scales.

**Why it matters**: This is the strongest quantitative evidence for preferring binary checklists. The improvement isn't marginal — 0.45 is a substantial jump in agreement that translates directly to more reproducible evaluation results.

**Design implication**: When decomposing quality into checkpoints, frame each as a specific yes/no question rather than a scaled rating.

**URL**: https://arxiv.org/abs/2403.18771

### Check-Eval (arXiv:2407.14467)

**Key finding**: A comprehensive checklist-based text quality evaluation framework that outperforms holistic scoring for text generation tasks.

**Why it matters**: Validates the binary checklist approach across multiple text generation domains, not just Q&A. Shows that decomposition into granular checks is consistently better than asking for an overall quality judgment.

**Design implication**: Even for subjective quality dimensions (like "writing quality"), decomposition into specific binary checks works better than holistic assessment.

**URL**: https://arxiv.org/html/2407.14467v1

### AutoRubric (arXiv:2603.00077)

**Key finding**: Open-source Python framework for automated rubric-based LLM evaluation. Demonstrates that rubric generation itself can be partially automated.

**Why it matters**: Useful for bootstrapping initial rubric designs. The framework can suggest checkpoint candidates based on your task description, though human curation is still essential.

**Design implication**: Consider using automated rubric generation as a starting point, then curate and refine based on what matters for your specific system.

**URL**: https://arxiv.org/abs/2603.00077

---

## Rubric Design Research

### DEER Benchmark (ICML 2026, arXiv:2512.17776)

**Key finding**: Proposes 7 evaluation dimensions, 25 subdimensions, and 101 rubric items for comprehensive LLM evaluation.

**Why it matters**: Provides the most thorough dimension taxonomy available. Even if you don't adopt all 101 items, the hierarchy is an excellent starting point for identifying which quality aspects matter for your system.

**Dimension hierarchy** (top-level):
1. Accuracy
2. Relevance
3. Completeness
4. Clarity
5. Harmlessness
6. Depth
7. Creativity

**Design implication**: Use DEER's hierarchy as a menu — select the dimensions relevant to your use case rather than trying to cover everything. For agent systems, Accuracy and Completeness are usually highest priority.

**URL**: https://arxiv.org/html/2512.17776v3

### ResearchRubrics (Scale AI, arXiv:2511.07685)

**Key finding**: Deep Research Agent rubric benchmark demonstrating that rubric-based evaluation can measure complex multi-step agent behaviors.

**Why it matters**: Shows rubric-based evaluation works for agents, not just simple text generation. The rubric approach scales to multi-step workflows involving tool use, planning, and synthesis.

**URL**: https://arxiv.org/html/2511.07685v1

---

## Benchmark Design Examples

### SECQUE (Microsoft, arXiv:2504.04596)

**Design**: 565 expert-written questions across 4 categories, evaluated with LLM-based multi-judge system.

**Key design choices**:
- Category-based question organization (maps well to different capability areas)
- Multiple LLM judges for scoring reliability (reduces single-judge bias)
- Expert-written questions ensure alignment with real-world tasks

**Takeaway**: Using multiple LLM judges and averaging/voting improves scoring reliability. Consider using 2-3 judge calls per checkpoint if consistency is critical.

**URL**: https://arxiv.org/html/2504.04596v1

### FinanceBench (arXiv:2311.11944)

**Design**: 10,000+ QA triplets organized into 3 question types: lookup, numerical reasoning, and logical inference.

**Key design choices**:
- Explicit question type taxonomy
- Large scale enables statistical significance
- Ground truth answers for automated verification

**Takeaway**: A clear question type taxonomy (parallel to categories) helps ensure coverage and enables type-specific analysis. Even within a domain, different question types exercise fundamentally different capabilities.

**URL**: https://arxiv.org/abs/2311.11944

### FinTextQA (arXiv:2405.09980)

**Design**: 1,262 long-form QA pairs with source attribution.

**Takeaway**: Including source attribution in the ground truth enables automatic faithfulness checking — if the response cites the right source, it's more likely to be factually correct.

**URL**: https://arxiv.org/html/2405.09980v1

### FinTruthQA (arXiv:2406.12009)

**Design**: Financial information disclosure quality evaluation via interactive Q&A.

**Takeaway**: Interactive/conversational evaluation formats can capture aspects of quality that single-turn QA misses. Consider whether your eval should include multi-turn scenarios.

**URL**: https://arxiv.org/html/2406.12009v3

---

## Production Evaluation Systems

### Samaya AI Criteria-Eval

**Scale**: 3,000 queries, 8,000+ annotation hours in production.

**Key design choices**:
- Binary checklist approach at production scale
- Each criterion is a standalone yes/no question
- Human annotators trained on specific criteria
- Regular calibration sessions to maintain consistency

**Takeaway**: Binary checklists demonstrably work at production scale. The investment in annotator training and calibration is essential for maintaining quality as the dataset grows.

**URL**: https://samaya.ai/blog/criteria-eval

### Samaya RealityBench

**Key finding**: Agent evaluation requires testing both outputs AND tool usage patterns. A correct final answer achieved through wrong tool usage is a false positive.

**Takeaway**: For agent systems, evaluate the process (which tools were called, with what arguments) separately from the output. A correct answer from the wrong tool call masks a capability gap.

**URL**: https://samaya.ai/blog/evaluation-of-ai-agents-at-samaya

---

## Tools & Frameworks

### Field Guide to AI Rubric

**Design**: 7-criteria rubric for general LLM evaluation, designed as a practitioner-friendly starting point.

**Takeaway**: Useful for initial brainstorming of rubric dimensions. Less academic rigor than DEER but more immediately actionable.

**URL**: https://fieldguidetoai.com/resources/llm-evaluation-rubric

### Promptfoo LLM Rubric

**Design**: Configurable rubric-based scoring with CI/CD integration.

**Takeaway**: If you need evaluation in a CI/CD pipeline, Promptfoo provides a practical implementation pattern. Their rubric configuration format is a good reference for how to make rubrics machine-readable.

**URL**: https://www.promptfoo.dev/docs/configuration/expected-outputs/model-graded/

---

## How to Use These References

1. **Starting from scratch?** Read DEER for dimension ideas, CheckEval for scoring method justification, then Samaya for production patterns.

2. **Improving an existing eval?** Read SECQUE for multi-judge reliability improvements, FinanceBench for category/taxonomy inspiration.

3. **Building infrastructure?** Read the Framework Comparison resource for RAGAS vs DeepEval, then Promptfoo for CI/CD patterns.

4. **Justifying your approach to stakeholders?** CheckEval and Samaya provide the strongest evidence for binary checklist methodology.
