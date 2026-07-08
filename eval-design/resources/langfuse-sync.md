# Langfuse → Braintrust Harvest

Phase 7's core loop: production traces live in Langfuse (observability home); the eval
dataset lives in Braintrust. This file covers the **batch sync** pattern — pulling selected
Langfuse traces into Braintrust dataset rows so every production failure ends its life as a
permanent regression case.

Scope note: production quality *monitoring* (automatic scoring of live traffic) stays in
Langfuse (its evaluator feature) and is out of this skill's scope. The alternative
architecture — OTel dual-export so traces also land in Braintrust, enabling Braintrust
online scoring — is sketched at the end for when a project outgrows batch sync.

## 1. What to harvest

Pull traces that carry signal, not volume:

- Negative user feedback (thumbs-down, low CSAT) — highest-value, pre-labeled failures.
- Low scores from Langfuse evaluators (if configured).
- Error spans / unhandled exceptions in the trace.
- Behavioral smells: unusually long trajectories, user rephrasing the same request,
  abandoned sessions.
- Novel intents — requests unlike anything in the current dataset (coverage gaps, not
  failures).
- A thin slice of *successes* too: representative passing traces keep the dataset's
  distribution honest and provide positive cases.

## 2. Batch sync mechanics

Langfuse public API → transform → Braintrust `dataset.insert`.

```python
import braintrust
from langfuse import Langfuse   # or raw REST: GET /api/public/traces

langfuse = Langfuse()  # LANGFUSE_PUBLIC_KEY / LANGFUSE_SECRET_KEY / LANGFUSE_HOST
dataset = braintrust.init_dataset(project="My Project", name="golden-set")

traces = langfuse.api.trace.list(
    # filter server-side where possible: tags, timestamp window, user feedback score
    from_timestamp=since, tags=["thumbs_down"], limit=100,
)

for t in traces.data:
    dataset.insert(
        input=extract_input(t),            # the user request / initial state
        expected=None,                     # see §3 — usually needs human curation
        metadata={
            "source": "production",
            "origin_trace": f"langfuse:{t.id}",
            "harvested_at": today,
            "harvest_reason": "thumbs_down",
            "category": None,              # assigned during curation
        },
    )
dataset.flush()
```

Practical notes:
- **Dedup before insert**: check existing rows' `metadata.origin_trace`, and near-duplicate
  inputs (same intent, same entities) against the current dataset — harvesting the same
  failure mode fifty times skews the distribution.
- `metadata.origin_trace` is the provenance link back to Langfuse (Braintrust's native
  `origin` back-link only works for Braintrust's own logs).
- PII: production inputs may carry personal data — scrub before inserting into a long-lived
  dataset.

## 3. Curation: a harvested trace is not yet a task

Raw traces enter as *candidates*. Before they count as dataset rows, apply the Phase 3
quality bar (`dataset-design.md`):

1. Write `expected` — what *should* have happened. The production output was wrong; the
   correct answer usually needs a human (or a carefully-reviewed strong model) to author.
2. Assign category + tags; add `applicable_checkpoints`.
3. Two-expert test + reference solution check, same as any task.
4. If the failure revealed a *new* failure mode, loop back: add it to the failure taxonomy
   and consider a new grader (Phase 2/4), not just a new row.

A lightweight kanban works: `harvested` → `curated` → `active`. Rows without `expected`
stay out of scored runs (filter on metadata).

## 4. Cadence

- **Incident-driven**: any user-visible failure gets harvested immediately — while context
  exists to write `expected` correctly.
- **Periodic sweep**: weekly/bi-weekly script run over feedback + evaluator-score filters.
- **Post-release**: after each model/prompt swap, sweep the following days' traces — new
  versions surface new failure modes.
- Watch the offline/online gap: if Langfuse production signals degrade but the Braintrust
  eval stayed green, the eval is missing a category — that gap defines the next harvest.

## 5. When batch sync stops being enough (advanced)

Signals you've outgrown this pattern:
- You want the *same scorers* running on production traffic and offline evals (today the
  production side would be reimplemented as Langfuse evaluators).
- You need production quality dashboards/alerts in Braintrust itself.

The upgrade is **OTel dual-export**: instrument once with the OpenTelemetry SDK (GenAI
semantic conventions), configure two OTLP exporters — Langfuse (`/api/public/otel`) and
Braintrust (both ingest OTLP). Then Braintrust **online scoring** rules (project
Automations: sampling rate, scorer list, trace- or span-level scope) score live traffic
asynchronously, and low-scoring traces promote to datasets with a native `origin` link.
Costs: double ingestion fees, instrumentation migration to OTel. Decide per project;
default remains batch sync.
