# Agent-Specific Eval Patterns

What changes when the system under test is an agent (multi-turn, tool-using, stateful)
rather than a single LLM call.

## Table of Contents

1. [Non-determinism: trials, pass@k, pass^k](#1-non-determinism-trials-passk-passk)
2. [Outcome first, trajectory as diagnostic](#2-outcome-first-trajectory-as-diagnostic)
3. [Evaluation areas by architecture tier](#3-evaluation-areas-by-architecture-tier)
4. [Environment & harness](#4-environment--harness)
5. [Per-agent-type playbooks](#5-per-agent-type-playbooks)

---

## 1. Non-determinism: trials, pass@k, pass^k

Single runs cannot distinguish regression from noise. Run multiple **trials** per task
(`trial_count` in Braintrust; ≥ 3 as a floor) and choose the metric by product requirement:

- **pass@k** — probability of at least one success in k attempts. Rises with k. Use when one
  success is enough (a human reviews/selects, retries are cheap).
- **pass^k** — probability that *all* k trials succeed. Falls with k. Use when every
  interaction must work (customer-facing autonomy). Sobering arithmetic: 75% per-trial
  success → pass^3 ≈ 42%.

Report per-trial variance; a task whose trials swing wildly is telling you something
(ambiguous task, flaky environment, or genuinely unstable capability).

## 2. Outcome first, trajectory as diagnostic

The "Outside-In" order:

1. **Black box**: did the final outcome achieve the goal? (task success, final state
   correct, user satisfied). Grade this first — it's the only metric that ultimately
   matters.
2. **Glass box**: when the outcome fails (or efficiency/robustness targets miss), open the
   trajectory to locate *why*. Systematic checklist of failure loci:
   - **Planning/thought** — hallucinated plan, off-topic loops, context pollution.
   - **Tool selection & parameterization** — wrong tool, missing required call,
     hallucinated tool/param names, malformed arguments.
   - **Tool-response interpretation** — misread numbers, missed entities, and the classic:
     not recognizing an error response (404) and proceeding as if it succeeded.
   - **RAG** — irrelevant/outdated retrieval, or retrieved-context ignored.
   - **Efficiency/robustness** — excessive steps, redundant calls, unhandled exceptions.

Trajectory *metrics* (turn count, token usage, tool-error rate) are fine as efficiency
checkpoints; trajectory *exact-match* grading is the brittleness anti-pattern.

An **agent-as-judge** (a critic agent reading the trace object and answering process
questions: "was the plan logical? was tool_A the right first choice? were arguments
well-formed?") can automate glass-box diagnosis — treat it like any judge: calibrate it.

## 3. Evaluation areas by architecture tier

Additive — each tier keeps all checks from the previous:

| Architecture | Adds |
|---|---|
| Single-turn | Instruction following (system beats conflicting user prompt; stays on task); functional correctness |
| Workflow (fixed chain) | Each chained step evaluated independently; final response **completeness** (contains order status, ETA…) and **correctness** (values are right) as separate checkpoints |
| Single agent (dynamic tools) | Tool selection matches intent; data precision (argument extraction correct) |
| Multi-agent | Handoff accuracy (routing to the right agent; returning control on topic change); circular-handoff prevention; per-agent instruction compliance; system-level emergent failures (contention, deadlock) can't be attributed to one agent — evaluate the system trajectory |

## 4. Environment & harness

- **Clean state per trial.** No leftover files, cached data, or shared state between runs —
  shared state produces correlated failures that look like agent regressions.
- **Production-like scaffold.** The agent under eval should run the same harness as
  production; scaffold differences alone can swing results massively (CORE-Bench went
  42% → 95% largely from grading + scaffold fixes).
- **Multi-turn simulation**: conversational tasks need a second LLM simulating the user
  (τ-bench pattern). Keep the simulator's persona/goals fixed per task; the simulator is
  part of the eval environment and its drift is your noise.
- Watch infra flakiness (rate limits, sandbox timeouts) — mitigate and annotate, or it
  reads as capability regression.

## 5. Per-agent-type playbooks

**Coding agents**
- Primary: deterministic outcome graders — does it run, do tests pass (fail-to-pass +
  pass-to-pass to catch breakage).
- Secondary: static analysis (lint/type/security), transcript grading for code quality.
- Reference designs: SWE-bench Verified (500 human-verified-solvable problems — note that
  the *verification* is the design lesson), Terminal-Bench.

**Conversational agents**
- Interaction quality is part of the outcome. Combine: state check (ticket resolved) +
  transcript constraints (< N turns) + judge checkpoints (tone, policy compliance).
- User-simulator driven (τ2-bench pattern: expected-action checks + reward gating over DB
  state/actions/communication).

**Research agents**
- Hardest to grade; ground truth drifts as sources change. Combine: groundedness (claims ↔
  cited sources), coverage (key facts present), source quality, exact match for objective
  sub-answers, judge rubrics for synthesis quality — calibrated frequently against experts.

**Computer-use agents**
- Verify **backend/system state**, not screenshots: URL/page state, DB rows, file system,
  app config (WebArena/OSWorld patterns). "Confirm the action occurred, not just
  appearance."
- Efficiency trade-off worth measuring: DOM interaction is fast but token-heavy; screenshots
  slower but token-light.
