# Grader Design

How to turn checkpoints into scorers: choosing the grader family, designing LLM judges,
aggregation, and the anti-pattern catalog.

## Table of Contents

1. [Grader families & when to use each](#1-grader-families--when-to-use-each)
2. [Code graders](#2-code-graders)
3. [LLM-as-judge design](#3-llm-as-judge-design)
4. [Aggregation & partial credit](#4-aggregation--partial-credit)
5. [Anti-pattern catalog](#5-anti-pattern-catalog)

---

## 1. Grader families & when to use each

Decision order — always try the cheaper, more deterministic family first:

1. **Code graders** — anything with checkable ground truth: exact/regex/fuzzy string match,
   state verification (DB rows, files, API responses), tests pass/fail, tool-call
   verification, static analysis, transcript stats (turn count, token usage).
   Fast, reproducible, debuggable, never drift.
2. **LLM judges** — genuinely subjective checkpoints: faithfulness to sources, reasoning
   quality, tone, structure, completeness of open-ended answers. Non-deterministic, cost
   money, and **require calibration** (see `judge-calibration.md`).
3. **Humans** — the calibration anchor and the gold standard for deeply subjective or
   high-stakes judgments. Used to validate judges and for periodic spot-checks, not for
   routine scoring.

A single task usually combines several: e.g. a support-agent task = state check (ticket
resolved) + transcript constraint (< 10 turns) + judge (appropriate tone).

**Grade outcomes, not paths.** Verify what the agent *produced* (final state, final answer),
not that it followed a specific tool-call sequence — agents regularly find valid approaches
the designer didn't anticipate, and step-sequence graders punish that creativity. Trajectory
inspection is a diagnostic for failures, not the primary grade (see
`agent-eval-patterns.md`).

## 2. Code graders

- Prefer semantic comparison over brittle string equality: `1` vs `1.0` and `96.12` vs
  `96.124991` should usually pass — use numeric tolerance, JSON-aware diffs, or fuzzy match.
- For tool-call checkpoints, grade tool *name* and *arguments* as separate checkpoints;
  compare arguments semantically (parsed values), not as raw strings.
- Verify **backend state, not surface appearance**: for computer-use/workflow agents,
  confirm the booking exists in the DB / the file changed / the URL is correct — not that
  the screenshot looks right.
- Robustness checkpoints are code-gradable: stub a tool to return 404/timeout and assert the
  transcript acknowledges the error and no fabricated result appears.
- In Braintrust these are plain functions returning 0–1 (see
  `braintrust-implementation.md`).

## 3. LLM-as-judge design

**Structure — one focused judge per checkpoint.** A mega-prompt scoring ten dimensions at
once produces worse results than ten focused binary prompts. Each judge call answers one
specific question.

**Prefer discrete choices over raw scores.** LLMs discriminate better than they rate:
classification into labeled choices ("Relevant"/"Irrelevant", "A"/"B"/"tie") mapped to
scores beats asking for a 1–5 number. For version comparison, pairwise ("which response is
better?") yields a win/loss/tie rate that is far more reliable than deltas in a noisy
absolute score. Control for length — judges are biased toward longer responses.

**Prompt contents:**
- The checkpoint question, precisely stated, with step-by-step evaluation instructions
  (numbered steps before the verdict measurably improve judge performance — the G-Eval
  pattern).
- Everything the judge needs: the input, the output under test, the reference/expected
  (if any), and relevant context. The judge cannot check faithfulness to sources it
  can't see.
- 2–3 few-shot examples spanning quality levels (excellent / acceptable / poor), ideally
  drawn from your human-labeled set.
- Chain-of-thought: ask for reasoning before the verdict (`use_cot` in autoevals).
- **An escape hatch**: instruct the judge to answer "Unknown" when information is
  insufficient — otherwise it hallucinates verdicts.

**Configuration:**
- Use a strong model for the judge first; only downgrade after agreement with human labels
  is validated at the cheaper tier.
- Lock the judge model version and temperature (0). If the judge changes between runs, you
  can't tell whether score movement is your system or the judge.
- Log every judge call (prompt, response, parsed verdict) for spot-checking and debugging.

**Reward-hacking resistance:** design tasks/graders so passing genuinely requires solving
the problem. Detection signal: automated scores high, human scores low → the grader has a
loophole. See `judge-calibration.md`.

## 4. Aggregation & partial credit

- **Partial credit for multi-component tasks**: score components separately and combine —
  an agent that identifies the problem and verifies the customer but fails the final step
  is meaningfully better than one that fails immediately; a binary all-or-nothing task
  score hides that progress.
- Aggregation modes: weighted combination vs. all-must-pass (binary gate) vs. hybrid
  (hard gates for safety checkpoints + weighted score for quality). Safety/harm checkpoints
  should be gates, not weights — a 100%-effective agent that causes harm is a total failure.
- Report scores with breakdowns (by category, by checkpoint group, by difficulty tag) —
  a single aggregate hides which capability regressed. Keep raw per-checkpoint results
  (Braintrust stores per-scorer results per row automatically).
- Don't set pass/fail release thresholds prematurely; early on, report scores and trends.
  Thresholds come once the metric is trusted and stable.

## 5. Anti-pattern catalog

Merged from Anthropic, OpenAI, and Google sources. Check the design against this list before
calling Phase 4 done.

**Task/dataset:**
1. Waiting for a comprehensive suite instead of starting with 20–50 real-failure tasks.
2. One-sided problem sets (no negative cases) → one-sided optimization.
3. Ambiguous tasks (two experts wouldn't agree on the verdict).
4. No reference solution → broken/unsolvable tasks shipped; 0% pass read as "model is bad".
5. Dataset distribution diverging from production traffic ("biased design").
6. Task text contradicting the grader (METR: "reach threshold" vs grader "exceed threshold").

**Grader:**
7. Rigid step-sequence grading punishing valid alternative solutions.
8. Over-strict matching (rejecting `96.12` for `96.124991…`; string-matching tool arguments).
9. Generic academic metrics (BLEU/ROUGE/perplexity) as the primary quality signal — they
   capture surface similarity, not correctness or user value; acceptable only as cheap trend
   indicators on a golden set.
10. Grader-hackable tasks (passing without genuinely solving).

**Judge:**
11. Judges without an "Unknown" escape hatch → hallucinated verdicts.
12. Judges never calibrated against human labels; trusting judge accuracy on imbalanced
    data (use TPR/TNR).
13. Open-ended scalar scoring where pairwise/classification would be reliable.
14. Ignoring judge biases: position (in pairwise), verbosity, preference for LLM-styled text.

**Process:**
15. Never reading transcripts — grader validity unverifiable; failures must "seem fair".
16. Treating a saturated (~100%) eval as success instead of graduating it to regression
    and adding harder tasks.
17. One-shot evals mis-measuring agentic behavior (Qodo initially missed model gains because
    their single-shot coding evals couldn't see long-task improvements).
18. Skipping qualitative failure analysis and jumping straight to metrics.
19. Vibe-based evaluation ("prompt and pray") with no structured cases at all.
20. Shared state between trials → correlated failures misattributed to the agent.
