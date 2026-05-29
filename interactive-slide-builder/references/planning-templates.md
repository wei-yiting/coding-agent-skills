# Planning Templates

Concrete templates for the four pre-build artifacts: ASCII sketch, element inventory, grouping plan, animation order. Use these as starting points — adapt to the slide.

---

## ASCII sketch conventions

Keep the sketch *small* and *legible* in a terminal. The goal is shared understanding of layout, not pixel accuracy. Aim for a box about 60 cols × 12 rows.

### Conventions

- `+---+` for box borders. Use `+-...-+` for the slide outline so it's visually distinct.
- `[Text in brackets]` for text content placeholders, with a short description, not the full string.
- `--->` `<---` `--->` for arrows; vertical: `|` with `v` or `^`.
- Use whitespace generously — relative position matters more than spacing perfection.
- If multiple elements stack at the same location, mark with `(z)` (z-order) and explain below the sketch.
- Show the slide title placement explicitly.
- If the slide has a left/right column split, indicate the split visually.

### Archetype: title + diagram

```
+------------------------------------------------------------+
|  [Title: 35 chars max — top, centred]                      |
|                                                            |
|   +-------+      +-------+      +-------+                  |
|   | Box A | ---> | Box B | ---> | Box C |                  |
|   +-------+      +-------+      +-------+                  |
|                                                            |
|  [Caption text below diagram, 14pt italic]                 |
+------------------------------------------------------------+
```

### Archetype: two-column (text + diagram)

```
+------------------------------------------------------------+
|  [Title]                                                   |
|                                                            |
|  Left column:              | Right column:                 |
|  - Bullet 1                |   +-------+                   |
|  - Bullet 2                |   | Box A |                   |
|  - Bullet 3                |   +-------+                   |
|                            |       |                       |
|                            |       v                       |
|                            |   +-------+                   |
|                            |   | Box B |                   |
|                            |   +-------+                   |
+------------------------------------------------------------+
```

### Archetype: 2×2 comparison grid

```
+------------------------------------------------------------+
|  [Title: "Old vs. New"]                                    |
|                                                            |
|   +---------------+    +---------------+                   |
|   | Old approach  |    | New approach  |                   |
|   | - point 1     |    | - point 1     |                   |
|   | - point 2     |    | - point 2     |                   |
|   +---------------+    +---------------+                   |
|                                                            |
|   +---------------+    +---------------+                   |
|   | Cost (old)    |    | Cost (new)    |                   |
|   | - $X/mo       |    | - $Y/mo       |                   |
|   +---------------+    +---------------+                   |
+------------------------------------------------------------+
```

### Archetype: icon row + descriptions

```
+------------------------------------------------------------+
|  [Title]                                                   |
|                                                            |
|   (icon)      (icon)      (icon)      (icon)               |
|   Feat A      Feat B      Feat C      Feat D               |
|   one line    one line    one line    one line             |
|                                                            |
+------------------------------------------------------------+
```

### Archetype: hero + supporting detail

```
+------------------------------------------------------------+
|  [Title]                                                   |
|                                                            |
|                +----------------+                          |
|                |                |                          |
|                |  HERO VISUAL   |                          |
|                |  (diagram/img) |                          |
|                |                |                          |
|                +----------------+                          |
|                                                            |
|  [3 short supporting facts in a single row across bottom]  |
+------------------------------------------------------------+
```

### Archetype: pipeline / process (5+ steps)

```
+------------------------------------------------------------+
|  [Title: "Onboarding pipeline"]                            |
|                                                            |
|  +---+   +---+   +---+   +---+   +---+                     |
|  | 1 |-->| 2 |-->| 3 |-->| 4 |-->| 5 |                     |
|  +---+   +---+   +---+   +---+   +---+                     |
|  Sign     Verify  Setup   Tour    Done                     |
|  up                                                        |
|                                                            |
|  [Highlight step in colour as user clicks through]         |
+------------------------------------------------------------+
```

---

## Element inventory table format

Use **stable, short IDs** so animations and grouping can reference them. Convention:

- `T*` — text (T1, T2, …)
- `B*` — box / rectangle / shape (B1, B2, …)
- `A*` — arrow (A1, A2, …)
- `L*` — line (L1, L2, …)
- `I*` — icon / image (I1, I2, …)
- `G*` — group (defined in the grouping plan)

### Text table

| Column | Required? | Example |
|--------|-----------|---------|
| ID | yes | `T1` |
| Role | yes | Title / box label / caption / bullet / footnote |
| Content | yes | The literal string (or "see notes" if long) |
| Approx size | yes | 32pt bold, 14pt italic |
| Colour | sometimes | hex or "default" |
| Notes | optional | "top-centred", "wraps to 2 lines" |

### Shape table

| Column | Required? | Example |
|--------|-----------|---------|
| ID | yes | `B1` |
| Type | yes | Rounded rect / arrow → / line / oval |
| Position | yes | "left", "top-right", or rough coords |
| Fill | yes | hex or "none" |
| Border | yes | hex + width, or "none" |
| Contains | optional | which text IDs sit inside |

---

## Grouping plan table format

| Column | Example |
|--------|---------|
| Group ID | `G1` |
| Members | `B1, T2` |
| Purpose | "Client tile — animates as one unit" |

Always include a row even for items that are *not* grouped, so it's explicit:

> Arrows A1–A3: not grouped, animate independently.

---

## Animation order table format

| Column | Required? | Example |
|--------|-----------|---------|
| # | yes | 1, 2, 3 … (sequential) |
| Target | yes | Group ID or element ID (`G2`, `T1`) |
| Animation | yes | Fade in / Fly in from left / Wipe right / Appear |
| Trigger | yes | "On slide load" / "On click" / "After previous" / "After previous +Xs" |
| Duration | yes | 0.3s, 0.4s, 0.5s |
| Notes | optional | "second click pulls cache" |

Rule of thumb on triggers:

- **On slide load** — for the title and anything that should be visible immediately.
- **On click** — when the user wants to control pacing (most common for body content).
- **After previous** — for tightly coupled sequences (e.g., box appears, then arrow points to it).
- **After previous +Xs** — when you want a deliberate pause between two coupled animations.

---

## Common slide archetypes (full mini-spec examples)

### Archetype A: Architecture diagram, click-through reveal

Use when the user wants to walk through a system architecture click by click.

- Layout: hero diagram in centre, title on top, caption on bottom.
- Inventory: tiles for each component, arrows between them.
- Grouping: each tile = box + label.
- Animation: title fades in on load; each tile + its incoming arrow appear on click in flow order.

### Archetype B: Comparison (before/after, this/that)

- Layout: 2-column or 2×2 grid.
- Inventory: matching tiles per side; matching colours (one warm, one cool).
- Grouping: each tile is its own group.
- Animation: left side appears on click 1, right side on click 2 (so the audience compares pair-wise), or all on slide load if static.

### Archetype C: Stats / key numbers

- Layout: large hero number(s) + small labels + supporting context.
- Inventory: 1–3 huge numbers (60–72pt), 1–3 small labels (10–12pt), 1 caption.
- Grouping: each (number + label) is a group.
- Animation: numbers fade in on click with slight stagger.

### Archetype D: Process / pipeline

- Layout: horizontal row of steps with arrows.
- Inventory: numbered circles + step labels + arrows between them.
- Grouping: each (circle + label) is a group.
- Animation: steps appear left-to-right on click, current step optionally highlighted.

### Archetype E: Quote / hero text

- Layout: one large quote centred; small attribution.
- Inventory: quote text (big), attribution (small), maybe a quote-mark shape.
- Grouping: usually not needed (only 2–3 elements).
- Animation: fade in on slide load.
