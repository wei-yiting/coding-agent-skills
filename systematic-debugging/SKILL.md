---
name: systematic-debugging
description: Use when encountering any bug, test failure, performance regression, or unexpected behavior, before proposing fixes — build a red feedback loop first, then investigate root cause
---

# Systematic Debugging

## Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.

Systematic debugging is FASTER than guess-and-check thrashing: minutes instead of hours, ~95% first-time fix rate instead of ~40%.

**Violating the letter of this process is violating the spirit of debugging.**

## The Iron Law

```
NO HYPOTHESES WITHOUT A RED FEEDBACK LOOP FIRST
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot form theories. If you haven't completed Phases 1–4, you cannot propose fixes.

## When to Use

Use for ANY technical issue: test failures, production bugs, unexpected behavior, performance problems, build failures, integration issues.

**Use this ESPECIALLY when:**
- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes / previous fix didn't work
- You don't fully understand the issue

**Don't skip when:**
- Issue seems simple (simple bugs have root causes too)
- You're in a hurry (rushing guarantees rework)
- Manager wants it fixed NOW (systematic is faster than thrashing)

## The Six Phases

You MUST complete each phase before proceeding to the next.

### Phase 1: Build a Feedback Loop

**This is the skill.** Everything downstream — bisection, hypothesis-testing, instrumentation, the fix itself — consumes this loop. If you have a **tight** pass/fail signal that goes red on _this_ bug, you will find the cause. If you don't, no amount of staring at code will save you.

Spend disproportionate effort here. Be aggressive. Be creative. Refuse to give up.

Two cheap inputs before you build:
- **Read the error completely** — full stack trace, line numbers, file paths, error codes. Not to form a theory; to know where to attach the loop.
- **Check recent changes** — git diff, new dependencies, config changes. If the bug appeared between two known states, that points you at a bisection harness.

**Ways to construct a loop — try in roughly this order:**

1. **Failing test** at whatever seam reaches the bug — unit, integration, e2e.
2. **Curl / HTTP script** against a running dev server.
3. **CLI invocation** with a fixture input, diffing stdout against a known-good snapshot.
4. **Headless browser script** (Playwright/Puppeteer) — drives the UI, asserts on DOM/console/network.
5. **Replay a captured trace** — save a real request/payload/event log, replay it through the code path in isolation.
6. **Throwaway harness** — minimal subset of the system (one service, mocked deps) exercising the bug path with a single call.
7. **Property / fuzz loop** — if output is "sometimes wrong", run 1000 random inputs and look for the failure mode.
8. **Bisection harness** — automate "boot at state X, check, repeat" so you can `git bisect run` it.
9. **Differential loop** — same input through old vs new version (or two configs), diff outputs.
10. **HITL bash script** — last resort. If a human must click, drive _them_ with `scripts/hitl-loop.template.sh` so the loop is still structured and output feeds back to you.

**Tighten the loop.** Once you have _a_ loop, treat it as a product: make it faster (cache setup, skip unrelated init), sharper (assert the specific symptom, not "didn't crash"), more deterministic (pin time, seed RNG, isolate filesystem). A 30-second flaky loop is barely better than no loop; a 2-second deterministic one is a debugging superpower.

**Non-deterministic bugs.** The goal is not a clean repro but a **higher reproduction rate**. Loop the trigger 100×, parallelise, add stress, inject sleeps. A 50%-flake bug is debuggable; 1% is not — raise the rate until it's debuggable.

**When you genuinely cannot build a loop:** stop and say so explicitly. List what you tried. Ask your human partner for environment access, a captured artifact (HAR, log dump, core dump, recording), or permission to add temporary production instrumentation. Do NOT proceed to hypothesise without a loop.

**Completion criterion:** you can name **one command** — a script path, test invocation, curl — that you have **already run at least once** (paste the invocation and its output), and that is:

- [ ] **Red-capable** — drives the actual bug path and asserts the user's exact symptom; goes red on this bug, green once fixed
- [ ] **Deterministic** — same verdict every run (flaky bugs: pinned high repro rate)
- [ ] **Fast** — seconds, not minutes
- [ ] **Agent-runnable** — runs unattended; human in the loop only via the HITL script

If you catch yourself reading code to build a theory before this command exists, **STOP — jumping straight to a hypothesis is the exact failure this skill prevents.**

### Phase 2: Reproduce + Minimise

Run the loop. Watch it go red. Confirm:

- [ ] It produces the failure mode the **user** described — not a nearby different failure. Wrong bug = wrong fix.
- [ ] It's reproducible across runs (or at a high enough rate to debug against).
- [ ] You captured the exact symptom (error message, wrong output, slow timing) so later phases can verify the fix addresses it.

**Minimise:** shrink the repro to the smallest scenario that still goes red. Cut inputs, callers, config, data, and steps **one at a time**, re-running the loop after each cut. Done when **every remaining element is load-bearing** — removing any one makes the loop go green.

A minimal repro shrinks the hypothesis space in Phase 3 and becomes the clean regression test in Phase 5. Do not proceed until you have reproduced AND minimised.

### Phase 3: Pattern Analysis + Hypotheses

**Gather comparative evidence:**
- Find similar working code in the same codebase; list every difference from the broken code, however small — don't assume "that can't matter"
- If implementing a pattern, read the reference implementation COMPLETELY — partial understanding guarantees bugs
- Note what the broken code depends on: config, environment, assumptions

**Generate 3–5 ranked hypotheses** before testing any of them. Single-hypothesis generation anchors on the first plausible idea.

Each hypothesis must be **falsifiable** — state the prediction it makes:

> "If \<X\> is the cause, then \<changing Y\> will make the bug disappear / \<changing Z\> will make it worse."

If you cannot state the prediction, the hypothesis is a vibe — discard or sharpen it.

**Show the ranked list to your human partner before testing.** They often re-rank instantly ("we just deployed a change to #3") or have already ruled hypotheses out. Cheap checkpoint, big time saver. Don't block on it — proceed with your ranking if they're AFK.

### Phase 4: Instrument + Test Hypotheses

Each probe must map to a specific prediction from Phase 3. **Change one variable at a time** — never fix multiple things at once; you can't isolate what worked.

**Tool preference:**
1. **Debugger / REPL inspection** if the environment supports it — one breakpoint beats ten logs
2. **Targeted logs** at the boundaries that distinguish hypotheses
3. Never "log everything and grep"

**Multi-component systems** (CI → build → signing, API → service → database): instrument each component boundary — log what enters and exits, verify env/config propagation — run once, and let the evidence show WHERE it breaks before investigating that component:

```bash
echo "IDENTITY: ${IDENTITY:+SET}${IDENTITY:-UNSET}"   # layer 1: workflow
env | grep IDENTITY || echo "not in env"              # layer 2: build script
security find-identity -v                             # layer 3: signing env
```

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup becomes a single grep. Untagged logs survive; tagged logs die.

**Deep call stacks:** trace the bad value backward to its origin — see `root-cause-tracing.md`. Fix at the source, not at the symptom.

**Perf branch:** for performance regressions, logs are usually wrong. Establish a baseline measurement (timing harness, profiler, query plan), then bisect. Measure first, fix second.

**Verify before continuing:** hypothesis confirmed → Phase 5. Refuted → next hypothesis. All refuted → return to Phase 3 with the new evidence. DON'T stack fixes on top of each other. If you don't understand something, say "I don't understand X" — don't pretend.

### Phase 5: Fix

**Regression test before the fix** — but only at a **correct seam**: one where the test exercises the real bug pattern as it occurs at the call site. A too-shallow seam (unit test that can't replicate the triggering chain) gives false confidence.

**If no correct seam exists, that itself is the finding** — the architecture is preventing the bug from being locked down. Document it and flag for Phase 6.

If a correct seam exists (use the `test-driven-development` skill):

1. Turn the minimised repro into a failing test at that seam; watch it fail
2. Apply ONE fix addressing the identified root cause — no "while I'm here" improvements, no bundled refactoring
3. Watch it pass; check no other tests broke
4. Re-run the Phase 1 loop against the original (un-minimised) scenario

**If the fix doesn't work — STOP and count:**
- If < 3 attempts: return to Phase 3, re-analyze with new information
- **If ≥ 3 attempts: STOP and question the architecture**

**3+ failed fixes = architectural problem, not a failed hypothesis:**
- Each fix reveals new shared state/coupling in a different place
- Fixes require "massive refactoring" to implement
- Each fix creates new symptoms elsewhere

Question fundamentals: is this pattern sound, or are we sticking with it through sheer inertia? **Discuss with your human partner before attempting more fixes.**

### Phase 6: Cleanup + Post-mortem

Required before declaring done:

- [ ] Original repro no longer reproduces (re-run the Phase 1 loop)
- [ ] Regression test passes (or absence of a correct seam is documented)
- [ ] All `[DEBUG-...]` instrumentation removed (grep the prefix)
- [ ] Throwaway harnesses deleted (or moved to a clearly-marked debug location)
- [ ] The winning hypothesis stated in the commit/PR message — so the next debugger learns

**Then ask: what would have prevented this bug?** If the answer is architectural (no good test seam, tangled callers, hidden coupling), raise it with your human partner — after the fix is in, not before; you know more now than when you started.

## Red Flags - STOP and Follow Process

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- Reading code to build a theory before a red-capable command exists
- "Add multiple changes, run tests"
- "Skip the test, I'll manually verify"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "Pattern says X but I'll adapt it differently"
- "Here are the main problems: [lists fixes without investigation]"
- Proposing solutions before tracing data flow
- **"One more fix attempt" (when already tried 2+)**
- **Each fix reveals new problem in different place**

**ALL of these mean: STOP. Return to the earliest incomplete phase.**

**If 3+ fixes failed:** question the architecture (Phase 5).

## Your Human Partner's Signals You're Doing It Wrong

- "Is that not happening?" - You assumed without verifying
- "Will it show us...?" - You should have added evidence gathering
- "Stop guessing" - You're proposing fixes without understanding
- "Ultrathink this" - Question fundamentals, not just symptoms
- "We're stuck?" (frustrated) - Your approach isn't working

**When you see these:** STOP. Return to Phase 1.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "I can see the bug just from reading the code" | Without a red loop you can't prove it — or prove the fix. Build the loop; it takes minutes. |
| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
| "I'll write test after confirming fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "Reference too long, I'll adapt the pattern" | Partial understanding guarantees bugs. Read it completely. |
| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question pattern, don't fix again. |

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Feedback Loop** | Build a tight red-capable command | One command, run once, red on this bug |
| **2. Reproduce + Minimise** | Cut elements one at a time | Every remaining element load-bearing |
| **3. Patterns + Hypotheses** | Compare working code; 3–5 ranked falsifiable hypotheses | Predictions stated; list shown to human |
| **4. Instrument + Test** | Probes map to predictions, one variable at a time | Hypothesis confirmed or refuted |
| **5. Fix** | Regression test at correct seam, single fix | Loop green on original scenario |
| **6. Cleanup** | Remove instrumentation, post-mortem | Checklist complete |

## When Process Reveals "No Root Cause"

If systematic investigation reveals the issue is truly environmental, timing-dependent, or external:

1. You've completed the process
2. Document what you investigated
3. Implement appropriate handling (retry, timeout, error message)
4. Add monitoring/logging for future investigation

**But:** 95% of "no root cause" cases are incomplete investigation.

## Supporting Techniques

Available in this directory:

- **`root-cause-tracing.md`** - Trace bugs backward through call stack to find original trigger
- **`defense-in-depth.md`** - Add validation at multiple layers after finding root cause
- **`condition-based-waiting.md`** - Replace arbitrary timeouts with condition polling
- **`scripts/hitl-loop.template.sh`** - Structured human-in-the-loop repro when a human must drive the steps

**Related skills:**
- **test-driven-development** - For creating the failing regression test (Phase 5)
- **verify** - Verify the fix worked end-to-end before claiming success
