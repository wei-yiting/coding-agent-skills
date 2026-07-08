---
name: eval-design
description: >-
  End-to-end evaluation design for LLM and AI agent systems, synthesized from Anthropic's
  "Demystifying evals for AI agents", OpenAI's evaluation best practices, and Google's Agent
  Quality whitepaper, implemented on Braintrust (offline evals) with Langfuse as the production
  trace source. Covers the full lifecycle: objective definition, failure analysis, dataset
  design, grader design, LLM-judge calibration, baseline runs, CI integration, and the
  production-failure harvest loop. Produces artifacts/current/eval-design.md as the human
  review surface.
disable-model-invocation: true
---

# Eval Design

A guided workflow for designing and evolving evaluations for LLM/agent systems. The goal is
an eval suite you can actually trust: one that catches regressions before users do, tells you
*why* something failed, and grows from real production failures instead of staying a static
quiz you wrote on day one.

## Stack assumptions

- **Braintrust** is the home of offline evaluation: datasets, `Eval()` experiments, scorers, CI.
- **Langfuse** is the home of production observability: traces, user feedback, its own
  production evaluators. Production quality *monitoring* is out of scope for this skill —
  what is in scope is **harvesting** Langfuse traces into Braintrust datasets (Phase 7).
- If a project deviates from this stack, the methodology phases still apply; swap the
  implementation resource for the project's tooling.

## Entry points

This skill is multi-entry. Ask the user (or infer from their request) where they are, and
jump to the matching phase — do not force every session through all seven phases:

| Situation | Enter at |
|---|---|
| No evals exist yet for this system | Phase 1, walk forward |
| "The agent keeps failing in production / users complain" | Phase 2 (failure analysis) |
| Dataset exists but feels thin / one-sided | Phase 3 |
| Scores look wrong, or grading feels unfair | Phase 4 → 5 |
| LLM judge disagrees with human judgment | Phase 5 |
| Need CI wiring or baseline comparison | Phase 6 |
| Eval passing ~100%, or new failure modes appeared in production | Phase 7 |

Whatever the entry point, read the existing `artifacts/current/eval-design.md` first if it
exists — it is the record of prior decisions.

## Core principles

These are the load-bearing ideas from all four sources. When in doubt mid-phase, return here.

1. **Start small, from real failures.** 20–50 tasks drawn from actual failures beat a
   comprehensive synthetic suite that takes months. Evals get harder to build the longer you
   wait, and early on each change has a large effect size, so small samples suffice.
2. **Grade outcomes, not paths.** Checking exact tool-call sequences is brittle — agents
   regularly find valid approaches the eval designer didn't anticipate. Grade what the agent
   produced; inspect the trajectory only as a *diagnostic* when the outcome fails
   (the "Outside-In" order: black box first, glass box to explain failures).
3. **Code graders first.** Anything deterministically checkable (exact values, tool calls
   made, state changes, format) gets a code scorer. LLM judges are reserved for genuinely
   subjective checkpoints — they cost more, drift, and need calibration.
4. **Binary/discrete beats scalar.** Decompose "is this good?" into specific yes/no
   checkpoints. Binary questions improve inter-evaluator agreement dramatically (CheckEval:
   +0.45 over Likert) and are what LLM judges answer most reliably. Prefer pairwise
   comparison or pass/fail over 1–5 scores.
5. **A judge is a model too — calibrate it.** Never trust LLM-judge scores until they are
   validated against human labels (TPR/TNR, not accuracy). An uncalibrated judge is noise
   with a dashboard.
6. **Read the transcripts.** Scores are not self-certifying. You don't know your graders
   work until you've read transcripts and confirmed failures "seem fair". A 0% pass rate
   across many trials usually means a broken task, not an incapable agent.
7. **The dataset is a living asset.** Production failures become new cases; saturated
   capability evals (~100% pass) graduate into the regression suite and get replaced by
   harder tasks; broken/ambiguous tasks get fixed or retired.

## The seven phases

### Phase 1 — Define the objective

Write the eval's purpose as behavioral statements with numeric targets, not vibes.

- State what the system should do in the user's terms ("provides precise answers that
  satisfy the user's need"), then attach measurable targets (e.g., "context recall ≥ 0.85",
  "≥ 70% positively rated answers").
- Use the four quality pillars as a coverage menu — Effectiveness (goal achievement),
  Efficiency (tokens/latency/steps), Robustness (graceful failure on bad inputs/tool errors),
  Safety & Alignment — but only target the pillars that matter for this system now.
- Decide the reliability semantics early: does the product need *at least one success*
  (pass@k) or *success every time* (pass^k)? This changes targets: a 75% per-trial success
  rate is only ~42% pass^3.

Done when: objective statements + numeric targets are written into the artifact.

### Phase 2 — Failure analysis (qualitative first)

Skipping this and jumping straight to metrics is the most common way eval efforts fail —
you end up measuring things that don't matter. If the system already runs (even in dev),
ground the eval in observed behavior. Read `resources/error-analysis.md`.

- Pull ~50 problematic traces (from Langfuse in production, or dev transcripts).
- Open coding: free-form label what went wrong in each. Axial coding: cluster labels into a
  failure taxonomy with frequencies.
- Each major failure category becomes (a) dataset cases and (b) a candidate grader.

Greenfield (nothing runs yet): practice eval-driven development — derive expected behaviors
from the spec/design doc, build the eval before the agent, iterate the agent against it.

Done when: failure taxonomy with rough frequencies is in the artifact.

### Phase 3 — Design the dataset

Read `resources/dataset-design.md` for task quality bars, categories, scoring-method choice,
generation strategies, and the Braintrust dataset schema.

Non-negotiables:
- Start with 20–50 tasks from real failures / real manual checks; grow later.
- Every task passes the **two-expert test** (two domain experts would reach the same
  pass/fail verdict) and has a **reference solution** proven to pass all graders.
- Balance positive AND negative cases per behavior ("should search" and "should not
  search") — one-sided sets create one-sided optimization.
- Cover typical, edge, and adversarial cases; match production traffic distribution.
- Store in a Braintrust dataset with per-row `metadata` (category, difficulty, source,
  applicable checkpoints) so results can be sliced.

Done when: dataset exists in Braintrust; spec (categories, sizes, sources) is in the artifact.

### Phase 4 — Design the graders

Read `resources/grader-design.md` (grader families, decomposition into checkpoints, judge
prompt design, anti-patterns) and `resources/braintrust-implementation.md` (autoevals
catalog, custom scorers, `LLMClassifier`).

- Map each checkpoint from the failure taxonomy/rubric to a grader: code scorer where
  deterministic, LLM judge where subjective. One focused judge per checkpoint — a single
  mega-prompt asking ten things produces worse results than ten focused prompts.
- Build partial credit for multi-component tasks: an agent that identifies the problem and
  verifies the customer but fails the refund is meaningfully better than one that fails
  immediately, and your scores should show that continuum.
- Give judges an "Unknown" escape hatch and design tasks/graders so passing genuinely
  requires solving the problem (anti reward-hacking).

Done when: grader inventory table (checkpoint → type → scorer name) is in the artifact.

### Phase 5 — Calibrate the judges

Read `resources/judge-calibration.md`. Any LLM judge that gates decisions must be validated:

- Human-label a sample; split ~20% train (few-shot examples in the judge prompt) /
  ~40% validation (iterate judge instructions) / ~40% held-out test.
- Measure **TPR and TNR**, not accuracy (accuracy lies on imbalanced data). Target high both.
- Lock judge model + temperature; log every judge call; spot-check 10–20% ongoing.

Done when: judge agreement numbers are in the artifact and pass your bar.

### Phase 6 — Run, baseline, and wire into CI

Read `resources/braintrust-implementation.md` for `Eval()` mechanics, trials, experiment
conventions, `bt eval` CLI, and the GitHub Action.

- Run the full dataset with `trial_count ≥ 3` (agents are non-deterministic; single runs
  can't distinguish regression from noise). Record the baseline experiment.
- Read transcripts of failures before believing the numbers (Principle 6).
- Wire `bt eval` into CI so every prompt/model/scaffold change runs the suite and posts
  deltas against baseline.

Done when: baseline experiment linked in the artifact; CI runs on changes.

### Phase 7 — Operate the lifecycle

Read `resources/langfuse-sync.md` for the harvest mechanics.

- **Harvest**: periodically (or when incidents happen) pull failing/interesting production
  traces from Langfuse and insert them as Braintrust dataset rows with provenance metadata.
  Every production failure should end its life as a permanent regression case.
- **Graduate**: when a capability eval saturates (~100% pass), move it to the regression
  suite (run continuously, target 100%) and add harder capability tasks — a saturated eval
  tracks regressions but provides zero signal for improvement.
- **Maintain**: fix or retire ambiguous/broken tasks; retire non-discriminating tasks that
  score identically across every version; re-calibrate judges when the judge model changes.

Done when: harvest cadence + graduation criteria are documented in the artifact.

## Artifact contract

This skill's output is `artifacts/current/eval-design.md` — the human review surface for the
eval design, peer to `design.md` / `implementation.md`. Commit it to the branch as it
evolves. Structure:

```markdown
# Eval Design: <system name>

## Objective & Targets          ← Phase 1 (behavioral statements + numbers, pass@k vs pass^k)
## Failure Taxonomy             ← Phase 2 (categories, frequencies, example traces)
## Dataset Spec                 ← Phase 3 (categories/sizes/sources, Braintrust dataset name,
                                   task quality checklist status)
## Grader Inventory             ← Phase 4 (table: checkpoint | code/judge | scorer | notes)
## Judge Calibration            ← Phase 5 (labeled-set size, TPR/TNR per judge, judge model+version)
## Baseline & CI                ← Phase 6 (baseline experiment link, trial count, CI trigger)
## Lifecycle Plan               ← Phase 7 (harvest cadence, graduation criteria, owner)
```

The review question this artifact answers for the human gate: **「我們量的東西對嗎？分數能被信任嗎？」**
(scope: metrics/dataset/grader choices — not implementation code line-by-line).

## Resources

| File | Read when |
|---|---|
| `resources/error-analysis.md` | Phase 2 — open/axial coding procedure, trace sampling |
| `resources/dataset-design.md` | Phase 3 — task quality, categories, scoring methods, generation |
| `resources/grader-design.md` | Phase 4 — grader families, judge prompt design, anti-patterns |
| `resources/judge-calibration.md` | Phase 5 — labeling splits, TPR/TNR, biases, reward hacking |
| `resources/agent-eval-patterns.md` | Agent-specific: trials/pass@k/pass^k, per-agent-type playbooks, trajectory diagnostics |
| `resources/braintrust-implementation.md` | Phases 3–6 — Eval() API, autoevals, datasets, CLI, CI |
| `resources/langfuse-sync.md` | Phase 7 — harvesting Langfuse traces into Braintrust datasets |
| `resources/references.md` | Primary sources, academic backing, benchmark design examples |
