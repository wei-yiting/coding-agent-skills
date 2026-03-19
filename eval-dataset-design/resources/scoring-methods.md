# Scoring Methods: A Deep Dive

## Table of Contents

1. [Binary Checklist](#binary-checklist)
2. [Likert Scale](#likert-scale)
3. [Open-Ended Rubric](#open-ended-rubric)
4. [Comparison Matrix](#comparison-matrix)
5. [Migration Path](#migration-path)

---

## Binary Checklist

**How it works**: Each quality dimension is decomposed into one or more yes/no questions. The evaluator (human or LLM) answers each question independently. Score = passed / total.

**Example checkpoint**: "Does the response cite at least one data source?" → YES or NO

### Why this works well

The key insight from CheckEval (arXiv:2403.18771) is that binary questions dramatically improve inter-evaluator agreement — by 0.45 compared to Likert scales. This happens because:

1. **Reduced cognitive load**: Answering "did it cite a source?" is cognitively simpler than deciding if citation quality is a 3 or a 4 on a 5-point scale.

2. **Composability**: Individual binary scores combine naturally into aggregate metrics. You can report "87% of responses cited sources" — which is immediately interpretable — rather than "average citation score was 3.2 out of 5" — which requires calibration context.

3. **LLM-as-judge compatibility**: LLMs are more reliable at binary classification than ordinal ranking. A focused prompt asking one yes/no question produces more consistent results than asking an LLM to rate something on a scale.

4. **Reproducibility**: Binary answers are easier to verify and audit. Disagreements are obvious (YES vs NO), while Likert disagreements (3 vs 4) are ambiguous.

### Design principles

- **One concept per checkpoint**: "Does the response use specific numbers AND cite sources?" is two questions masquerading as one. Split them.
- **Observable, not inferred**: "Does the response contain a numerical value?" is observable. "Did the model understand the question?" is inferred. Prefer observable.
- **Positive framing when possible**: "Does the response cite data sources?" rather than "Does the response fail to cite sources?" Positive framing reduces double-negative confusion for LLM judges.
- **Specify applicable checkpoints per question**: Not all checkpoints apply to all questions. A simple lookup question shouldn't be penalized for "uses multiple sources."

### Checkpoint grouping

Organize checkpoints into groups that correspond to different quality dimensions:

```
[Correctness]  C1: action_taken, C2: correct_action, C3: correct_parameters, C4: factual_grounding
[Faithfulness] F1: no_fabrication, F2: question_addressed
[Quality]      Q1: source_citation, Q2: specificity, Q3: structure, Q4: completeness, ...
```

This grouping enables reporting at multiple granularities: overall score, group score, individual checkpoint score.

---

## Likert Scale

**How it works**: Each quality dimension is rated on a numeric scale (typically 1-5 or 1-7). Anchors describe what each point means.

**Example**: "Rate the response's use of specific data (1 = entirely vague, 3 = some specific numbers, 5 = consistently precise with sourced data)"

### When Likert is appropriate

- **Exploratory evaluation**: When you're still discovering what quality looks like and need the granularity to distinguish "decent" from "good."
- **Comparative ranking**: When the goal is to rank multiple systems relative to each other rather than measure absolute quality.
- **Research contexts**: When publishing results where Likert is the expected methodology.

### Known limitations

- **Anchor drift**: Evaluators interpret anchors differently. One person's "3" is another's "4."
- **Central tendency bias**: Evaluators cluster around the middle of the scale, reducing discriminating power.
- **Scale compression**: Over time, evaluators use a narrower range of the scale.
- **Harder to automate**: LLM judges show more variance when asked to produce ordinal ratings than binary classifications.

### Mitigation strategies

If you must use Likert:
- Provide detailed, example-based anchors for each point
- Use 4-point scales (no neutral middle) to force discrimination
- Calibrate evaluators with a shared reference set before real evaluation
- Report both mean and distribution, not just mean

---

## Open-Ended Rubric

**How it works**: Evaluators write free-form assessments guided by rubric criteria. No numeric score — just qualitative feedback.

### When to use

- **Discovery phase**: You don't yet know what quality dimensions matter for your system.
- **Complex, novel tasks**: Where quality is hard to decompose into discrete checkpoints.
- **Debugging**: When you need to understand *why* something is bad, not just *that* it's bad.

### Limitations

- Not suitable for tracking or comparison (no numeric signal)
- Extremely expensive at scale (requires skilled human evaluators)
- Cannot be automated reliably

### Practical advice

Use open-ended evaluation as a precursor to binary checklist design. Run open-ended evaluation on 20-30 responses, identify recurring themes in the feedback, then crystallize those themes into binary checkpoints.

---

## Comparison Matrix

| Dimension | Binary Checklist | Likert Scale | Open-Ended Rubric |
|-----------|-----------------|--------------|-------------------|
| Consistency | High (0.45 improvement) | Medium | Low |
| Granularity | Individual checkpoints | Dimension-level | Free-form |
| Automation | Easy (LLM-as-judge) | Possible but noisy | Not feasible |
| Scale | Hundreds of questions | Tens of questions | Tens of questions |
| Cross-version tracking | Excellent | Possible | Not suitable |
| Setup effort | Medium (design checkpoints) | Low (choose scale) | Low (write guidelines) |
| Insight depth | Wide but shallow | Medium | Deep but narrow |

---

## Migration Path

A common evolution:

1. **Start with open-ended rubric** on a small sample to discover quality dimensions
2. **Crystallize into binary checkpoints** based on recurring themes
3. **Use Likert only** for dimensions that truly resist binary decomposition (rare)
4. **Expand binary checklist** as you discover new quality dimensions over time

This progression lets you start quickly and build rigor incrementally.
