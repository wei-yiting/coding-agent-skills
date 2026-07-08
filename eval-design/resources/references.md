# References

## Primary sources (this skill's methodology)

1. **Anthropic — Demystifying evals for AI agents** (engineering blog, 2025)
   https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
   The 0→1 process (start with 20–50 tasks from real failures), task quality bars
   (two-expert test, reference solutions), grader families, outcome-over-path, pass@k vs
   pass^k, capability→regression graduation, transcript reading, anti-patterns.

2. **OpenAI — Evaluation best practices** (+ graders guide, agent-evals guide, evaluation
   flywheel cookbook)
   https://developers.openai.com/api/docs/guides/evaluation-best-practices
   The 5-step lifecycle, Analyze→Measure→Improve flywheel, open/axial coding error
   analysis, judge calibration (20/40/40 split, TPR/TNR), grader mechanics, architecture-
   tier evaluation areas, edge-case dimensions. (Note: OpenAI's hosted Evals product is
   deprecated for late 2026 — the methodology stands; tooling here is Braintrust.)

3. **Google — Agent Quality whitepaper** (5-day intensive series, Day 4, Nov 2025)
   Four pillars (Effectiveness / Efficiency / Robustness / Safety & Alignment), Outside-In
   hierarchy (black box → glass box), evaluator spectrum (automated metrics → LLM-judge →
   agent-as-judge → HITL → user feedback), observability as the precondition for eval,
   Agent Quality Flywheel (production failures → permanent regression tests).

4. **Braintrust docs** — https://www.braintrust.dev/docs (Context7: `/websites/braintrust_dev`)
   `Eval()` / autoevals / datasets / trials / CLI / CI specifics in
   `braintrust-implementation.md`.

## Scoring methodology research

- **CheckEval** (arXiv:2403.18771) — binary checklist questions improve inter-evaluator
  agreement by 0.45 over Likert. The strongest quantitative case for binary decomposition.
- **Check-Eval** (arXiv:2407.14467) — checklist-based evaluation outperforms holistic
  scoring across text-generation domains, including subjective dimensions.
- **DEER** (arXiv:2512.17776, ICML 2026) — 7 dimensions / 25 subdimensions / 101 rubric
  items; use as a menu when selecting rubric dimensions.
- **From Generation to Judgment** (arXiv:2411.16594) — LLM-as-a-judge survey.
- **Agent-as-a-Judge** (arXiv:2410.10934) — agents evaluating full execution traces of
  other agents.

## Benchmark design lessons

- **SWE-bench Verified** — 500 *human-verified-solvable* problems; the verification pass
  (removing broken/ambiguous tasks) is the design lesson. Grading = fail-to-pass +
  pass-to-pass test execution.
- **τ2-bench** (github.com/sierra-research/tau2-bench) — dual-control conversational eval
  (agent + LLM user simulator), reward gating over DB state/actions/communication; shipped
  75+ task-quality fixes — datasets need ongoing curation.
- **CORE-Bench** — 42% → 95% after fixing grading bugs (over-strict numeric matching) and
  scaffold constraints; grader bugs masquerade as capability gaps.
- **SECQUE** (arXiv:2504.04596) — multi-judge voting improves scoring reliability.
- **FinanceBench** (arXiv:2311.11944) — explicit question-type taxonomy (lookup / numerical
  reasoning / logical inference) enables type-specific analysis.

## Production system lessons

- **Samaya Criteria-Eval** — binary checklists at production scale (3,000 queries, 8,000+
  annotation hours); annotator training + regular calibration sessions are what keep it
  working.
- **Samaya RealityBench** — a correct answer via wrong tool usage is a false positive;
  evaluate tool usage separately from output when capability attribution matters.
- **Descript** (via Anthropic article) — three grading dimensions ("don't break things, do
  what I asked, do it well"); manual → LLM graders with periodic human calibration; runs
  separate quality-benchmark and regression suites.
- **Qodo** (via Anthropic article) — one-shot evals missed agentic-model gains entirely;
  eval shape must match the deployment shape.

## Generation tooling (diversity expansion)

- **RAGAS TestsetGenerator** — document-based QA generation; good linguistic diversity,
  document-centric (best for RAG systems); agent metrics: AgentGoalAccuracy,
  ToolCallAccuracy.
- **DeepEval Synthesizer** — more configurable generation (target types/difficulties,
  structured schemas). Note: their scoring/CI features overlap with Braintrust — in this
  stack, use these frameworks for *generation* only.
