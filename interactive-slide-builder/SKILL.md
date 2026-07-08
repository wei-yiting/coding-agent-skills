---
name: interactive-slide-builder
description: >-
  Design PowerPoint slides interactively, one slide at a time: ASCII layout sketch, element
  inventory, grouping plan, and numbered animation order — all confirmed with the user before
  any code runs. Builds with native PowerPoint shapes and proper grouping, never pasted single-
  image slides. Use when the user wants careful per-slide composition, slide diagrams (boxes,
  arrows, flowcharts), or ordered animations; prefer over the generic pptx skill for visual
  slide design. Skip for bulk bullet-only decks or text extraction.
---

# Interactive Slide Builder

## What this skill does

Designs PowerPoint slides **one slide at a time** through a structured planning conversation. Before any code runs, you and the user agree on layout, text content, shape inventory, grouping, and animation order via four small artifacts. Only after explicit user confirmation do you build — using **native PowerPoint shapes** (rectangles, arrows, lines, ovals) with **proper grouping**, never throwaway single-image dumps.

The value of this skill is **the planning discipline**, not just the rendering. Most slide-generation failures come from skipping the alignment step and guessing at intent. This skill makes alignment cheap by giving you compact, reviewable artifacts.

## When to use vs. when to skip

| Situation | Use this skill? |
|---|---|
| Diagram-heavy slide (boxes + arrows, architecture, flow) | ✅ |
| Slide with click-by-click animation | ✅ |
| User wants careful composition / not just bullets | ✅ |
| User says "讓我們一頁一頁做" / "one slide at a time" | ✅ |
| Read/extract text from existing pptx | ❌ Use `pptx` |
| Bulk-generate a 30-slide deck quickly | ❌ Use `pptx` |
| Plain title + bullets, no diagram | ❌ Use `pptx` |

If the user asks for a multi-slide deck, **first** propose a 1-line outline per slide so they can scope, **then** enter the per-slide loop for each slide they want carefully designed. Some slides in the deck may be simple enough to skip the loop — agree with the user upfront which ones are diagram/animation slides.

## The five non-negotiables

These exist because skipping them is exactly how slides get built wrong. Each rule has a *why* — when you hit an edge case, judge against the why, not the letter.

1. **One slide at a time.** Even if the user gives a full deck brief, the planning loop runs per slide. *Why:* the user's design intuitions shift after seeing slide 1 rendered. Pre-planning slide 4 just produces work to throw away.
2. **No code before all four artifacts are confirmed.** ASCII sketch → element tables → grouping plan → animation order. *Why:* the artifacts make alignment cheap; building first makes it expensive (full rebuild on every wrong guess).
3. **Surface every uncertainty as a question.** If you find yourself thinking "I'll just assume X", stop and ask. *Why:* one turn to ask is cheaper than a rebuild after the user sees the wrong slide.
4. **Native shapes, not pasted images.** Before reaching for an image, ask: "can this be built from rectangles, arrows, lines, ovals, and text?" The answer is almost always yes. *Why:* images can't be edited, re-themed, or animated in PowerPoint. Native shapes survive every future change. Exceptions: photographs, logos, company-supplied artwork.
5. **Group related elements.** A coloured background tile + its text label + its icon belong in one group. *Why:* without grouping, the next human to edit the slide selects four floating things instead of one, and animations get tangled targeting individual members. If you'd want to drag the cluster as a unit later, group it now.

## The per-slide loop

Run this sequence for **each** slide. Don't reorder — the artifacts build on each other.

### Step 1 — Intake (1 turn)

Ask what's on this slide, in 1–3 sentences. Capture:

- Slide purpose (what does the audience learn?)
- Approximate content (title, key text, what visual is involved)
- Where it sits in the deck (intro / body / summary?)
- Any hard constraints (corporate template colours, fixed title text, must include logo, etc.)

If the user already gave this context, restate it back in your own words and ask "did I get this right?" before moving on.

### Step 2 — ASCII layout sketch

Draft a rough ASCII sketch of the slide. Aim for fidelity to **relative position and rough size**, not pixel accuracy. Example:

```
+------------------------------------------------------------+
|  [Title: "How requests flow through the gateway"]          |
|                                                            |
|   +---------+      +---------+      +---------+            |
|   | Client  | ---> | Gateway | ---> | Service |            |
|   +---------+      +---------+      +---------+            |
|                         |                                  |
|                         v                                  |
|                    +---------+                             |
|                    |  Cache  |                             |
|                    +---------+                             |
|                                                            |
|  Caption: "Cache lookup happens before service dispatch"   |
+------------------------------------------------------------+
```

Show it. Ask: **"Does the layout look right? Anything you want bigger / smaller / moved / removed / added?"** Iterate until the user explicitly approves.

See [`references/planning-templates.md`](references/planning-templates.md) for more sketch patterns (two-column, grid, hero+detail, etc.).

### Step 3 — Element inventory (two tables)

Once layout is approved, expand into concrete elements. Use **IDs** so animations and grouping can reference them later.

**Text elements:**

| ID | Role | Content | Approx. size | Notes |
|----|------|---------|--------------|-------|
| T1 | Title | "How requests flow through the gateway" | 32pt bold | top-centre |
| T2 | Box label | "Client" | 16pt | inside box B1 |
| T3 | Box label | "Gateway" | 16pt | inside box B2 |
| T4 | Caption | "Cache lookup happens before service dispatch" | 14pt italic | bottom |

**Shape elements:**

| ID | Type | Position (approx) | Fill | Border | Contains |
|----|------|-------------------|------|--------|----------|
| B1 | Rounded rectangle | left | light blue | none | T2 |
| B2 | Rounded rectangle | centre | light blue | none | T3 |
| B3 | Rounded rectangle | right | light blue | none | (Service) |
| A1 | Arrow → | B1 right → B2 left | dark grey | — | — |
| A2 | Arrow → | B2 right → B3 left | dark grey | — | — |
| A3 | Arrow ↓ | B2 bottom → B4 top | dark grey | — | — |
| B4 | Rounded rectangle | below centre | light yellow | none | (Cache) |

Ask: **"Are these the right elements? Any to add / remove / re-style? Should fills/colours change?"**

### Step 4 — Grouping plan

For each visual unit (a box + its label, a region + its contents), declare a group. Groups are what get animated and moved as a unit.

| Group ID | Members | Purpose |
|----------|---------|---------|
| G1 | B1 + T2 | Client tile |
| G2 | B2 + T3 | Gateway tile |
| G3 | B3 + (Service text) | Service tile |
| G4 | B4 + (Cache text) | Cache tile |

If something doesn't need to be grouped, say so explicitly so the user can confirm:

> "Arrows A1–A3 are not grouped with anything — they animate independently. OK?"

See [`references/grouping-patterns.md`](references/grouping-patterns.md) for common grouping decisions.

### Step 5 — Animation order table

Number every step in the animation timeline. Each row = one click (or one auto-advance).

| # | Target (group or element) | Animation | Trigger | Duration | Notes |
|---|---------------------------|-----------|---------|----------|-------|
| 1 | T1 (Title) | Fade in | On slide load | 0.5s | — |
| 2 | G1 (Client tile) | Fly in from left | On click | 0.4s | — |
| 3 | A1 (Arrow Client→Gateway) | Wipe right | After previous, +0.2s | 0.3s | — |
| 4 | G2 (Gateway tile) | Fly in from left | After previous | 0.4s | — |
| 5 | A2 (Arrow Gateway→Service) | Wipe right | After previous, +0.2s | 0.3s | — |
| 6 | G3 (Service tile) | Fly in from left | After previous | 0.4s | — |
| 7 | A3 (Arrow Gateway→Cache) | Wipe down | On click | 0.3s | second click pulls cache |
| 8 | G4 (Cache tile) | Fade in | After previous | 0.4s | — |
| 9 | T4 (Caption) | Fade in | On click | 0.5s | — |

**Explicitly confirm with the user: "Is this the click sequence you want? Click 1 reveals X, click 2 reveals Y, etc."**

If the slide has no animations, say so explicitly and skip this table — but ask first ("Should this slide be static, or do you want elements to appear progressively?").

### Step 6 — Cross-cutting clarifications

Steps 2–5 each end with a per-artifact confirmation ("does the layout look right?", "is this the animation order?"). Step 6 is the **catch-all for things that don't belong to any single artifact** — slide-level concerns the model needs but hasn't asked about yet.

Batch all of these into a single message so the user answers in one pass:

- Exact colour palette (does the user have brand colours, or should you pick from `pptx/SKILL.md` palettes?)
- Font family (corporate font vs. default)
- Slide dimensions (16:9 / 16:10 / 4:3)
- Whether to add to an existing pptx or start a new one
- Where the output file should live
- For diagrams: should arrow text labels appear too, or is direction enough?

If you've already collected an answer to one of these during intake, don't re-ask — just confirm what you have ("you mentioned brand colours earlier — sticking with that?"). If you have **zero** questions, re-read the spec adversarially before moving on; missing nothing on a real slide is rare.

### Step 7 — User confirmation gate

Wait for an explicit "yes, build it" / "好,做吧" / "go ahead". Re-asking the user to confirm a third time is fine if the spec is large.

### Step 8 — Build

See [`references/build-execution.md`](references/build-execution.md) for the full build playbook. Summary:

- Use `python-pptx` for slide construction (native shapes, native grouping via `shapes.add_group_shape(...)`).
- Apply the grouping plan inline — `build-execution.md` shows the few lines of `python-pptx` needed; each slide's build code is short enough that bundling a generator would be over-engineering.
- For animations, use `scripts/inject_animations.py` to post-process the pptx. This is the only reliable way to add animations programmatically — neither python-pptx nor pptxgenjs supports animations natively.
- Always mirror the animation order into the slide's speaker notes (so the human can verify the sequence in PowerPoint and apply manually if XML injection fails on their version).

### Step 9 — Preview & iterate

Render the slide to an image (see `pptx/SKILL.md` → "Converting to Images"). Show it to the user. Ask: **"Anything to adjust?"** Iterate. Don't declare success until the user signs off on the rendered output.

## When the user pivots mid-loop

Real users change their minds mid-loop. At step 3 they say "actually move the cache box to the top", or at step 5 they say "let's drop the arrows entirely". The rule is **back up to the affected step, redo it cleanly, do not patch later artifacts in place**.

- Layout change (step 2 affected) → re-sketch, reconfirm, then redo inventory because element positions changed.
- Element added/removed (step 3 affected) → update the inventory, then check whether grouping and animation tables still reference the old IDs.
- Grouping change (step 4 affected) → update grouping plan, then check animation targets.
- Animation reorder (step 5 affected) → just update the table.

Patching downstream artifacts to match an upstream change usually drops something on the floor (an animation step still targets an element that no longer exists). Redoing is faster.

## Output artifacts per slide

For each slide built, leave behind:

1. The pptx itself (or the updated pptx if appending).
2. A rendered image of the slide for visual review.
3. `slide-N-spec.md` — the four artifacts captured as a frozen record (handy if the user wants to rebuild or share the design).

Save these under a per-deck directory (e.g., `slides-out/deck-name/`).

## Anti-patterns

These are mistakes the skill exists to prevent. If you catch yourself doing one, back up.

- **Building before the four artifacts are confirmed.** You don't know what the user wants yet.
- **Defaulting silently.** "I'll use blue" without asking. Surface the choice and ask, even if blue is the obvious default.
- **One-image slides.** Generating a single PNG of a diagram and pasting it in. The user can't edit it, animate it, or re-theme it. Use shapes.
- **Ungrouped elements.** A box and its label as separate floating things. The next person to move them will hate you.
- **Animations without a numbered table.** "Things appear" is not a spec. The table is the spec.
- **Skipping clarifying questions because the user seems busy.** It feels faster to guess, but guessing wrong costs a full rebuild. Ask.
- **Pre-planning the whole deck.** The user's mind will change after seeing slide 1. Run the loop per slide.

## Reference files

- [`references/planning-templates.md`](references/planning-templates.md) — ASCII sketch patterns, table formats, common slide archetypes.
- [`references/grouping-patterns.md`](references/grouping-patterns.md) — when to group, how to express grouping in the plan, common groupings.
- [`references/animation-patterns.md`](references/animation-patterns.md) — animation type catalogue (entrance/emphasis/exit), trigger options, sequencing patterns, what works reliably via XML injection.
- [`references/build-execution.md`](references/build-execution.md) — concrete build playbook with `python-pptx`, grouping API, and the animation injection workflow.

## Quick reference card

```
Per-slide loop:
  1. Intake          → confirm purpose & content
  2. Layout sketch   → ASCII, iterate
  3. Inventory       → text table + shape table (with IDs)
  4. Grouping plan   → group ID + members
  5. Animation table → numbered, with trigger
  6. Clarify         → one batched question list
  7. Confirm         → wait for explicit yes
  8. Build           → python-pptx + animation injection
  9. Preview         → render, show, iterate
```

If you're ever unsure where you are in the loop, ask the user. They want to be in the driver's seat.
