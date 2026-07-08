# Braintrust Implementation Reference

API patterns for implementing the methodology on Braintrust. Verified against Braintrust
docs (2026-07); for anything load-bearing, re-check current docs via Context7
(`/websites/braintrust_dev`) before writing code.

## Table of Contents

1. [Concept model](#1-concept-model)
2. [Eval() — running experiments](#2-eval--running-experiments)
3. [Scorers](#3-scorers)
4. [Datasets](#4-datasets)
5. [Trials & comparing experiments](#5-trials--comparing-experiments)
6. [CLI & CI](#6-cli--ci)

---

## 1. Concept model

**Project** → contains **Datasets**, **Experiments** (immutable eval-run snapshots),
**Logs**, **Prompts**, **Scorers**. One `Eval()` call = one experiment.
An eval = `data` (rows: `input`/`expected`/`metadata`) + `task` (input → output) +
`scores` (scorers each returning 0–1).

Auth: `BRAINTRUST_API_KEY` env var (or `login({ apiKey })` in TS).

## 2. Eval() — running experiments

**TypeScript** (`*.eval.ts`):

```typescript
import { Eval, initDataset } from "braintrust";
import { Factuality } from "autoevals";

await Eval("My Project", {
  experimentName: "prompt-v3",            // name per variant; auto-named if omitted
  data: initDataset("My Project", { dataset: "golden-set" }),
  // or inline: data: [{ input, expected, metadata }]
  task: async (input) => await runAgent(input),
  scores: [Factuality, myCodeScorer],
  metadata: { model: "...", prompt_rev: "..." }, // experiment-level, for filtering
  maxConcurrency: 10,
  trialCount: 3,
});
```

**Python** (`eval_*.py` for CLI discovery; snake_case):

```python
from braintrust import Eval, init_dataset

Eval(
    "My Project",
    experiment_name="prompt-v3",
    data=init_dataset(project="My Project", name="golden-set"),
    task=run_agent,
    scores=[accuracy_scorer, faithfulness_judge],
    metadata={"model": "...", "prompt_rev": "..."},
    max_concurrency=10,
    trial_count=3,
)
```

Conventions worth adopting:
- `experimentName` encodes the variant under test; `metadata` carries the knobs
  (model, prompt revision, scaffold version) so experiment comparisons can filter/group.
- `noSendLogs: true` for local-only dry runs.
- Task functions can invoke hosted Braintrust prompts (`invoke({ projectName, slug, input })`).

## 3. Scorers

### Custom code scorers — plain functions returning 0–1

```typescript
function NonNull({ output }: { output: unknown }) {
  return output != null ? 1 : 0;
}
// named inline: ({ output, expected }) => ({ name: "exact_match", score: output === expected ? 1 : 0 })
```

```python
def accuracy_scorer(output, expected, **kwargs):
    return 1 if output == expected else 0
```

Scorers receive `{ input, output, expected, metadata }` — use `metadata.applicable_checkpoints`
to return `null`/skip checkpoints that don't apply to a row.

### autoevals built-ins

- **Heuristic (code)**: `ExactMatch`, `Levenshtein`, `NumericDiff`, `JSONDiff`,
  `EmbeddingSimilarity`.
- **LLM judges**: `Factuality`, `ClosedQA`, `Battle` (pairwise), `Moderation`, `Security`,
  `Summarization`, `Sql`, `Translation`.
- **RAG (RAGAS-style)**: `ContextPrecision`, `ContextRelevancy`, `ContextRecall`,
  `Faithfulness`, `AnswerRelevancy`, `AnswerCorrectness`.
- Judges accept a `model` option — any provider via the Braintrust AI proxy. Pin it
  (calibration requirement).

### Custom LLM judges

TypeScript — `LLMClassifierFromTemplate`:

```typescript
import { LLMClassifierFromTemplate } from "autoevals";

const StructureJudge = LLMClassifierFromTemplate({
  name: "Structure",
  promptTemplate: `Evaluate ONLY the structure of the response...
[numbered evaluation steps]
Question: {{input}}
Response: {{output}}
Reference: {{expected}}
Answer "Good", "Poor", or "Unknown" (if there is not enough information to judge).`,
  choiceScores: { Good: 1, Poor: 0, Unknown: 0.5 },
  useCoT: true,
  model: "<pinned-judge-model>",
});
```

Python — `LLMClassifier`:

```python
from autoevals import LLMClassifier

structure_judge = LLMClassifier(
    name="Structure",
    prompt_template=JUDGE_PROMPT,          # {{input}} / {{output}} / {{expected}}
    choice_scores={"Good": 1, "Poor": 0, "Unknown": 0.5},
    use_cot=True,
    model="<pinned-judge-model>",
)
```

Design notes: discrete `choice_scores` (not raw numbers), `use_cot=True`, an "Unknown"
choice as the escape hatch, few-shot examples inside the template drawn from the
calibration train split. One classifier per checkpoint.

## 4. Datasets

```python
import braintrust

dataset = braintrust.init_dataset(project="My Project", name="golden-set")  # creates or opens
dataset.insert(
    input={"question": "..."},
    expected={"answer": "...", "must_call_tools": ["search"]},
    metadata={"id": "QA-RETRIEVAL-001", "category": "retrieval",
              "source": "production", "origin_trace": "langfuse:abc123"},
)
dataset.flush()   # required
```

- `insert` upserts; datasets are versioned — experiments record the dataset version they
  ran against, so past experiments stay reproducible.
- Promoting Braintrust production logs into a dataset can carry an `origin` back-link;
  for Langfuse-sourced rows use `metadata.origin_trace` instead (see `langfuse-sync.md`).

## 5. Trials & comparing experiments

- `trial_count` / `trialCount` runs each input N times; results aggregate by matching
  `input`. Per-row override: `{ input, expected, trialCount: 5 }` for known-flaky tasks.
- Experiments page: side-by-side deltas per case, improvements/regressions per scorer.
  Compare runs that differ in exactly one knob (recorded in `metadata`).
- For version A/B on subjective quality, prefer a pairwise `Battle`-style judge over
  comparing absolute judge scores.

## 6. CLI & CI

- CLI: `bt eval file.eval.ts` / `bt eval tests/` (older: `npx braintrust eval`).
  Discovery: TS `*.eval.ts`, Python `eval_*.py`.
- Useful flags: `--no-input` (CI), `--json` (machine-readable), `--first N` / `--sample N`
  (subset smoke runs), `--watch` (dev), `--no-send-logs`.
- Reads `.env.local` / `.env` automatically.

GitHub Action — posts score deltas as a PR comment:

```yaml
- uses: braintrustdata/eval-action@v1
  with:
    api_key: ${{ secrets.BRAINTRUST_API_KEY }}
    runtime: node   # or python
```

Minimal alternative: `run: bt eval evals/ --no-input --json` with the API-key secret.

CI policy that matches the methodology: run the **regression suite** (graduated,
target-100% tasks) on every change; run the full capability suite on demand or nightly
(it's slower and its pass rate is *supposed* to be < 100%).
