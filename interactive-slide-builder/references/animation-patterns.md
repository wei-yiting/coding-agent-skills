# Animation Patterns

PowerPoint animations are powerful but fiddly to specify and even fiddlier to add programmatically. This reference defines the vocabulary the skill uses in the animation order table, and covers which animations work reliably via XML injection vs. which are best left for the human to apply.

## The three categories

PowerPoint groups animations into three:

| Category | Purpose | Examples |
|----------|---------|----------|
| **Entrance** | Element appears | Fade, Fly in, Wipe, Appear, Zoom |
| **Emphasis** | Element changes while visible | Pulse, Spin, Grow/Shrink, Colour change |
| **Exit** | Element disappears | Fade out, Fly out, Wipe out, Disappear |

Most slides only need entrance animations. If the user asks for emphasis or exit, ask why — there's usually a simpler way.

## The vocabulary the skill uses

In the animation order table, use these names. They map directly to PowerPoint's preset animation IDs.

### Entrance (use these freely)

| Name | What it does | When to use |
|------|--------------|-------------|
| `Appear` | Element pops into view instantly | When timing matters more than aesthetic |
| `Fade in` | Element fades from 0% to 100% opacity | Default for clean professional looks |
| `Fly in from left` | Slides in from the left edge | For sequence reveals where left-to-right flow makes sense |
| `Fly in from right` | Slides in from the right edge | Mirror of above |
| `Fly in from top` | Slides in from above | For drop-down reveals (e.g., header banners) |
| `Fly in from bottom` | Slides in from below | Less common, can feel rising-up |
| `Wipe right` | Reveals left-to-right (good for arrows) | Arrows pointing right |
| `Wipe left` | Reveals right-to-left | Arrows pointing left |
| `Wipe up` / `Wipe down` | Vertical wipes | Vertical arrows |
| `Zoom` | Element scales up from centre | Hero numbers, stat callouts |

### Emphasis (use sparingly)

| Name | When to use |
|------|-------------|
| `Pulse` | Call attention to a single element after it's already on the slide |
| `Spin` | Rare; loading-style indicators |
| `Grow/Shrink` | When you literally want size to change for emphasis |
| `Colour change` | When state matters (e.g., highlight current step in pipeline) |

### Exit (use rarely)

Almost always, "exit" animations are a sign the slide is doing too much. Consider splitting into two slides. If exit is needed:

| Name | Mirror of |
|------|-----------|
| `Fade out` | Fade in |
| `Fly out left/right/top/bottom` | Fly in directions |

## Triggers

| Trigger | Meaning |
|---------|---------|
| `On slide load` | Plays automatically when slide opens. Use for the title and anything that should be visible immediately. |
| `On click` | Waits for the user's next click. Use to control pacing. |
| `After previous` | Plays immediately after the previous animation step completes. Use when two animations are tightly coupled (box appears → arrow points to it). |
| `After previous +Xs` | Like `After previous`, but with an explicit delay. Use for deliberate beats. |
| `With previous` | Plays simultaneously with the previous step. Use when two things should appear together but are separate animation targets. |

## Sequencing patterns

### Pattern 1: Click-through reveal

Each click reveals one logical unit. Simplest, most common.

| # | Target | Animation | Trigger | Duration |
|---|--------|-----------|---------|----------|
| 1 | Title | Fade in | On slide load | 0.5s |
| 2 | G1 | Fly in from left | On click | 0.4s |
| 3 | G2 | Fly in from left | On click | 0.4s |
| 4 | G3 | Fly in from left | On click | 0.4s |

### Pattern 2: Coupled box-and-arrow

Box appears, then arrow draws to point at the *next* box, then next box appears. Each click reveals a step pair.

| # | Target | Animation | Trigger | Duration |
|---|--------|-----------|---------|----------|
| 1 | Title | Fade in | On slide load | 0.5s |
| 2 | G1 | Fly in from left | On click | 0.4s |
| 3 | A1 | Wipe right | After previous | 0.3s |
| 4 | G2 | Fly in from left | After previous | 0.4s |
| 5 | A2 | Wipe right | On click | 0.3s |
| 6 | G3 | Fly in from left | After previous | 0.4s |

### Pattern 3: Parallel pop-in

Everything appears at once, but with a slight stagger so it feels orchestrated rather than dumped.

| # | Target | Animation | Trigger | Duration |
|---|--------|-----------|---------|----------|
| 1 | Title | Fade in | On slide load | 0.5s |
| 2 | G1 | Fade in | On click | 0.3s |
| 3 | G2 | Fade in | After previous +0.1s | 0.3s |
| 4 | G3 | Fade in | After previous +0.1s | 0.3s |

### Pattern 4: Highlight current step

For pipeline slides where you want the "active" step to glow. Combine entrance + emphasis.

| # | Target | Animation | Trigger | Duration |
|---|--------|-----------|---------|----------|
| 1 | Title | Fade in | On slide load | 0.5s |
| 2 | All steps | Fade in | After previous | 0.5s |
| 3 | G1 | Colour change | On click | 0.3s |
| 4 | G1 | Colour change (back) | On click | 0.3s |
| 5 | G2 | Colour change | With previous | 0.3s |

(Alternating off-the-prev, on-the-next.) This pattern is fiddly. For non-trivial pipelines, prefer Pattern 1 instead.

## What's reliable via XML injection

`scripts/inject_animations.py` makes a deliberate trade-off: cover the most common case **correctly**, and route everything else to speaker notes so the human applies it in PowerPoint's Animation Pane (a 2-minute task per slide). Authoring fragile XML by hand produces decks that look fine in one PowerPoint version and broken in the next.

**Injected via XML (animation × trigger must both be in this set):**

| Reliable animations | Reliable triggers |
|---|---|
| Appear | On slide load |
| Fade in / Fade out | On click |
| Fly in (left/right/top/bottom) | |
| Wipe (left/right/up/down) | |
| Zoom | |

**Routed to speaker notes (the human applies manually):**

- `After previous`, `After previous +Xs`, `With previous` — these resolve their parent-relative timing through PowerPoint's sequence interpreter, which is fragile when authored by hand.
- Emphasis animations (Pulse, Grow/Shrink, Colour change, Spin).
- Exit animations beyond simple fade.
- Motion-path animations.

The script *always* writes the full animation plan into speaker notes, regardless of what gets injected. The notes are the canonical source of truth; the XML injection is a convenience that saves manual work for the cases where it's reliable.

## Speaker-note format

Whether or not XML injection succeeds, always mirror the animation table into speaker notes. This gives the human verifying the slide a single source of truth:

```
ANIMATION ORDER:
1. Title — Fade in — On slide load (0.5s)
2. G1 (Client tile) — Fly in from left — On click (0.4s)
3. A1 (Arrow Client→Gateway) — Wipe right — After previous +0.2s (0.3s)
...
```

This text is invisible in the rendered slide but visible in PowerPoint's notes pane and during presenter view.

## When NOT to use animations

Some slides are worse with animations. Push back when:

- The slide is a static reference (architecture diagram for a handout — animation makes the PDF version look weird).
- The animation order isn't meaningful (e.g., "boxes appear in alphabetical order" — animate only if order serves the story).
- The user is presenting via screen-share without click control (e.g., async video).
- The deck will be exported to PDF or shared as a file.

Ask the user upfront: "Will this deck be presented live with clicks, or shared as a file/PDF?" The answer should shape whether animations are worth specifying.
