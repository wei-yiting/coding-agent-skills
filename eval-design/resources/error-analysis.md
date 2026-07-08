# Failure Analysis: Open & Axial Coding

Qualitative failure analysis is the foundation the rest of the eval stands on. Automated
measurement without it is "a castle in the air — you have no idea what you're actually
measuring" (OpenAI evaluation flywheel). The output of this phase is a **failure taxonomy**:
a short list of named failure categories with rough frequencies, each of which becomes
dataset cases and candidate graders.

## 1. Collect ~50 problematic traces

Aim for around 50 traces where the system misbehaved or plausibly misbehaved. Sources, in
order of value:

1. **Langfuse production traces** — filter by: negative user feedback (thumbs-down),
   low scores from Langfuse evaluators (if configured), error spans, unusually long
   trajectories (high step/token count often signals flailing), sessions with user
   rephrasing (a strong implicit failure signal).
2. **Bug tracker / support queue / user reports** — each report is a pre-labeled failure.
3. **Dev transcripts** — if not yet in production, run the agent on realistic inputs
   yourself and keep the transcripts.

Don't over-sample one channel: 50 thumbs-down traces from the same feature tells you less
than 30 traces spread across feedback types and time windows.

## 2. Open coding

Go through each trace and write a free-form, descriptive label for what actually went wrong,
grounded in the data. Do not try to build a taxonomy yet — premature categories blind you to
what's actually there.

Good open codes are concrete and specific:

- "bot suggested a tour time that wasn't available"
- "amenities list rendered as a single block of text"
- "agent didn't recognize the 404 from the pricing API and kept going"
- "answer cited the right document but the number was from a different row"

Bad open codes are abstract: "hallucination", "bad quality", "wrong". If you catch yourself
writing these, re-read the trace and describe the observable behavior instead.

One trace can carry multiple codes. Keep a simple table: trace id/link, open codes, severity.

## 3. Axial coding

Cluster the open codes into higher-level categories. For example, "suggested unavailable
tour time" + "double-booked slot" + "quoted last week's schedule" → **tour scheduling
issues**; three formatting complaints → **formatting errors**.

The result is a quantitative picture: each category with its count. Sort by
frequency × severity. This is your failure taxonomy.

Sanity checks on the taxonomy:
- 4–10 categories is typical. One giant category means axial coding stopped too early;
  20 tiny ones means it went too far.
- Every category should suggest an obvious question: "how would I *detect* this
  automatically?" If no detection idea exists, the category may need splitting.

## 4. Map the taxonomy forward

For each category, decide:

| Category | → Dataset cases | → Grader |
|---|---|---|
| e.g. "unavailable tour times" | 5 tasks with known availability fixtures, incl. edge cases (fully booked day) | code scorer: proposed time ∈ availability set |
| e.g. "ignored API error state" | tasks with a tool stubbed to return 404/timeout | code scorer: transcript contains error acknowledgment, no fabricated result |
| e.g. "rambling / poor structure" | representative prompts | LLM judge: structure checkpoint (binary) |

Also mark which categories are **out of scope** for automation for now (deep subjectivity,
very rare) — these stay in periodic human review instead of pretending a grader covers them.

## 5. When the system is greenfield

If nothing runs yet, invert the process (eval-driven development):

- Derive expected behaviors from the design doc / spec — each acceptance criterion and each
  "the agent should never X" sentence is a proto-category.
- Write the tasks and graders *before* the agent works, then iterate the agent until it
  passes. The first real transcripts will still deserve an open-coding pass — expect the
  taxonomy to change once reality arrives.

## Cadence

Re-run a lightweight version of this analysis (10–20 traces) whenever:
- a new failure mode is reported that no grader caught,
- a model/prompt swap ships,
- the online metrics move but the offline eval didn't (that gap *is* the missing category).
