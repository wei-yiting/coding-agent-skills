# Grouping Patterns

Grouping in PowerPoint binds related elements so they move, resize, and animate as one unit. Getting it right makes the slide editable by humans later; getting it wrong makes every future edit painful.

## When to group

Group elements that share **visual meaning** — they exist as a unit, not as independent things that happen to be near each other.

### Group these

| Pattern | Members |
|---------|---------|
| **Tile** | Background box + label text (+ optional icon) |
| **Labelled arrow** | Arrow + arrow's text label |
| **Stat card** | Background card + big number + small label below |
| **Icon button** | Icon + caption underneath |
| **Quote block** | Quote-mark shape + quote text + attribution |
| **Step in a pipeline** | Numbered circle + step label + step description |
| **Region** | Background fill region + everything visually "inside" it |

### Don't group these

| Pattern | Why |
|---------|-----|
| Slide title + body content | They have independent visual roles; the title is a fixed slot |
| Unrelated decorative elements | If you'd move one without the other, don't group them |
| Elements that need independent animations | Once grouped, animation usually targets the group, not members |
| All slide content | Defeats the purpose; grouping the entire slide is the same as not grouping |

## Decision rule

Ask: **"If I drag this element somewhere else on the slide, do other elements need to come with it?"**

- Yes → group them.
- No → leave them ungrouped.

A second test: **"If I want to animate just one of these, am I OK animating all of them together?"** If yes, group. If you need to animate them separately, don't.

## How grouping interacts with animation

A group is itself an animation target. So if `G1 = B1 + T2`, you can animate `G1` as a unit (e.g., fly in together), but you generally can't animate `B1` and `T2` differently within the same step.

If you want a tile that *first* slides in as a unit (`G1` fly in) and *then* the label inside emphasises (`T2` pulse), you can do that — but it's animation step 1 targeting the group, animation step 2 targeting a member. This is allowed and sometimes desirable. Note it in the animation table.

## Common groupings, expressed as plan rows

### Architecture diagram with 4 boxes

```
G1 | B1 + T2          | Client tile
G2 | B2 + T3          | Gateway tile
G3 | B3 + T4          | Service tile
G4 | B4 + T5          | Cache tile
(A1, A2, A3 ungrouped — animate independently after each tile lands)
```

### 3-column feature comparison

```
G1 | B1 + T1 + I1     | Column 1 (Feature A): background + heading + icon
G2 | B2 + T2 + I2     | Column 2 (Feature B): same structure
G3 | B3 + T3 + I3     | Column 3 (Feature C): same structure
(Title T0 ungrouped — separate animation)
```

### Pipeline with 5 steps

```
G1 | O1 + T1          | Step 1 (numbered circle + label)
G2 | O2 + T2          | Step 2
G3 | O3 + T3          | Step 3
G4 | O4 + T4          | Step 4
G5 | O5 + T5          | Step 5
(Arrows A1..A4 ungrouped — appear between steps on a separate beat)
```

### Stats slide with 3 big numbers

```
G1 | T1 (big "47%") + T2 (small "of users")    | Stat 1
G2 | T3 (big "12s") + T4 (small "median")      | Stat 2
G3 | T5 (big "$2M") + T6 (small "saved")       | Stat 3
```

## When the user pushes back on grouping

The user might say "I don't care about grouping, just build it". Push back gently once — explain that without grouping, future edits to the slide require selecting and moving 4 things instead of 1, and animations end up tangled. If they still don't want it, build without grouping but **note this choice** in the spec file so it's visible later.

If the user says "group everything inside a region together", that's usually fine — it matches the "tile" pattern. If they say "don't group anything", you've at least asked.

## Implementation note

In `python-pptx`, grouping is done by:

1. Adding all member shapes to the slide first (or to a group container).
2. Calling `shapes.add_group_shape(member_list)` — this returns a `GroupShape` that you can name and reference later for animation targeting.

See [`build-execution.md`](build-execution.md) for the `python-pptx` API surface — position members on the slide first, then call `slide.shapes.add_group_shape(members)` and set `group.name = "G1"` (matching the grouping plan ID) so animation injection can find it.

## Naming groups

Inside the pptx XML, every shape and group has a `name` attribute. Make group names match the group plan IDs (e.g., `G1`, `G2`) so the animation injection script can target them unambiguously. Avoid generic names like "Group 1" — XML lookup becomes flaky.
