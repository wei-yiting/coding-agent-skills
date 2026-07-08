# Judge Calibration

An uncalibrated LLM judge is noise with a dashboard. This file covers how to validate that a
judge agrees with human judgment, and how to keep it honest over time.

## 1. Build the labeled set

- Have a human (a domain expert if the domain demands it — non-expert annotation of expert
  domains is an anti-pattern) label a sample of real system outputs against the checkpoint
  the judge will score. Binary labels (pass/fail per checkpoint), plus free-text notes on
  the failures.
- Make the labeling instructions concrete: "show rather than tell" — include example outputs
  at different quality levels rather than abstract criteria. Multiple reviewers on a subset
  lets you measure inter-annotator agreement; where humans can't agree, a judge can't be
  calibrated (fix the checkpoint definition first).
- Size: enough to split three ways with tolerable noise — in practice ≥ 50 labeled examples
  per judge, more if failures are rare.

## 2. Split 20 / 40 / 40

- **~20% train** — becomes few-shot examples embedded in the judge prompt.
- **~40% validation** — iterate the judge instructions against this slice: run the judge,
  read disagreements with human labels, fix the prompt (clarify criteria, add steps, adjust
  few-shots), repeat.
- **~40% held-out test** — touched once, at the end, for the reported agreement numbers.
  If you iterated against it, the numbers are fiction.

## 3. Measure TPR and TNR, not accuracy

Accuracy misleads on imbalanced data (if 90% of outputs pass, a judge that says "pass"
always scores 90% accurate and catches nothing).

- **TPR (true positive rate)** — of the outputs humans marked as failures, what fraction
  does the judge flag? (Does it find real problems?)
- **TNR (true negative rate)** — of the outputs humans marked as passes, what fraction does
  the judge pass? (Is it not over-critical?)

Target high on **both**. A judge with great TPR and poor TNR buries you in false alarms and
the team stops trusting the eval; the reverse silently ships regressions.

Complementary check — **ordering validation**: if experts know response A > B > C, confirm
the judge's scores reproduce that ordering.

## 4. Operational hygiene

- **Lock model + temperature.** Pin the judge model version, temperature 0. When the judge
  model must change (deprecation), re-run calibration before trusting new scores — score
  shifts after a judge swap are meaningless until re-validated.
- **Log every judge call**: prompt, raw response, parsed verdict. Braintrust captures scorer
  spans automatically when judges run inside `Eval()`.
- **Spot-check 10–20% ongoing.** Periodic human review of judge verdicts catches systematic
  drift before it distorts your metrics. Read transcripts *and* grades together — the
  failures should "seem fair".
- **Cost-tiering**: calibrate with a strong judge model first. Only after agreement is
  established, test whether a cheaper/faster model maintains it; switch only if TPR/TNR hold.

## 5. Reward hacking detection

The system under test (or its authors, via prompt tweaks) can exploit judge loopholes:
keyword stuffing, confident tone, echoing the rubric, extreme verbosity.

- Primary signal: **automated scores rise while human spot-check scores don't** — divergence
  between judge and human on fresh samples means the judge has been gamed or has drifted.
- Mitigations: judges see the reference/expected material; length-controlled comparisons;
  discrete choice framing (harder to game than "rate 1–10"); adversarial examples in the
  validation slice (deliberately bad outputs dressed in good form — verify the judge fails
  them).

## 6. When to re-calibrate

- Judge model version changes (forced or chosen).
- The checkpoint definition changes.
- Product surface changes the output distribution (new format, new language, new modality).
- Spot-checks show ≥ a few disagreements in a row — treat as an incident, not noise.
