# Build Execution

The playbook for the build step (step 8 of the per-slide loop). Use `python-pptx` for shape composition and grouping, then `scripts/inject_animations.py` to add animation timing XML.

## Why python-pptx for this skill

The existing `pptx` skill primarily uses **pptxgenjs** (Node) for from-scratch decks. This skill uses **python-pptx** instead because:

1. **Native grouping support** — `shapes.add_group_shape(members)` returns a `GroupShape` you can name and animate. PptxGenJS has no equivalent.
2. **OOXML access** — python-pptx exposes the underlying XML tree (`shape._element`, `slide._element`), which is the only way to add animations. The skill's animation injection script depends on this.
3. **Stable shape names** — easier to assign and retrieve `name` attributes via the `_element` API, which animation injection needs.

If the user already has a pptx authored with pptxgenjs and wants a slide added, this skill still uses python-pptx for *that slide* — you can append to existing pptx files. No need to rebuild the whole deck.

## Dependencies

```bash
pip install python-pptx lxml
```

`lxml` is python-pptx's dependency anyway, but the animation injection script uses it directly.

## Shape composition reference

### Slide setup

```python
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE

prs = Presentation()  # or Presentation("existing.pptx") to append
prs.slide_width = Inches(13.333)   # 16:9 widescreen
prs.slide_height = Inches(7.5)

# blank layout (index 6 in default template), strips placeholders
slide = prs.slides.add_slide(prs.slide_layouts[6])
```

Use `Inches(x)`, `Pt(x)`, or `Emu(x)` consistently. Mixing them silently produces tiny shapes.

### Rectangles and rounded rectangles

```python
# Rectangle (sharp corners — use for accent bars, overlays)
box = slide.shapes.add_shape(
    MSO_SHAPE.RECTANGLE,
    left=Inches(1), top=Inches(2),
    width=Inches(2.5), height=Inches(1.2),
)
box.fill.solid()
box.fill.fore_color.rgb = RGBColor(0xE0, 0xF2, 0xFE)  # light blue
box.line.color.rgb = RGBColor(0x0E, 0x76, 0x90)
box.line.width = Pt(1.5)
box.name = "B1"  # stable name for grouping/animation references

# Rounded rectangle (use for tiles, cards, friendly visuals)
tile = slide.shapes.add_shape(
    MSO_SHAPE.ROUNDED_RECTANGLE,
    left=Inches(1), top=Inches(2),
    width=Inches(2.5), height=Inches(1.2),
)
tile.adjustments[0] = 0.15  # corner radius (0..0.5 of half-side)
```

### Arrows

```python
# Right-pointing arrow
arrow = slide.shapes.add_shape(
    MSO_SHAPE.RIGHT_ARROW,
    left=Inches(3.6), top=Inches(2.4),
    width=Inches(0.8), height=Inches(0.4),
)
arrow.fill.solid()
arrow.fill.fore_color.rgb = RGBColor(0x6B, 0x72, 0x80)
arrow.name = "A1"

# Connector line/arrow between two shapes
from pptx.enum.shapes import MSO_CONNECTOR
connector = slide.shapes.add_connector(
    MSO_CONNECTOR.STRAIGHT,
    Inches(3.5), Inches(2.6),    # start
    Inches(4.5), Inches(2.6),    # end
)
connector.line.color.rgb = RGBColor(0x6B, 0x72, 0x80)
connector.line.width = Pt(2)
```

For arrows in diagrams, **prefer `MSO_SHAPE.RIGHT_ARROW`** (a shape, not a connector) — easier to position and animate as a unit.

### Text

```python
# Text inside a shape
tile.text_frame.text = "Client"
para = tile.text_frame.paragraphs[0]
para.font.size = Pt(16)
para.font.bold = True
para.font.color.rgb = RGBColor(0x1F, 0x29, 0x37)
para.alignment = PP_ALIGN.CENTER

# Standalone text box
from pptx.enum.text import PP_ALIGN
tb = slide.shapes.add_textbox(
    left=Inches(1), top=Inches(0.5),
    width=Inches(11.3), height=Inches(0.8),
)
tf = tb.text_frame
tf.text = "How requests flow through the gateway"
tf.paragraphs[0].font.size = Pt(32)
tf.paragraphs[0].font.bold = True
tb.name = "T1"
```

Set `tile.text_frame.margin_left = 0` (and right/top/bottom) when you need text to align flush with the shape edge — defaults add internal padding.

### Grouping

```python
# Create members first, then group them
# IMPORTANT: members must already be on the slide before grouping
shapes_to_group = [tile, label_textbox]  # references to existing shapes
group = slide.shapes.add_group_shape(shapes_to_group)
group.name = "G1"  # match the grouping plan ID
```

The members become children of the group; you can no longer position them individually relative to the slide (positions become relative to the group). If you need to tweak positions, do it *before* grouping.

### Slide background

```python
from pptx.dml.color import RGBColor
background = slide.background
fill = background.fill
fill.solid()
fill.fore_color.rgb = RGBColor(0xFA, 0xFA, 0xFA)  # off-white
```

For images: use `add_picture()` and stretch to fill — but reach for this only when the user has supplied artwork.

## Naming convention

Every shape and group **must** have a meaningful `name` attribute that matches the IDs in the plan tables:

- Text → `T1`, `T2`, …
- Box / shape → `B1`, `B2`, …
- Arrow → `A1`, `A2`, …
- Group → `G1`, `G2`, …

Why: the animation injection script looks shapes up by name to attach timing nodes. If two shapes have the same name (or the default "Rectangle 1"), the script can't disambiguate.

## Speaker notes — always populate

```python
notes_slide = slide.notes_slide
notes_text = notes_slide.notes_text_frame
notes_text.text = """ANIMATION ORDER:
1. T1 (Title) — Fade in — On slide load (0.5s)
2. G1 (Client tile) — Fly in from left — On click (0.4s)
3. A1 (Arrow Client→Gateway) — Wipe right — After previous +0.2s (0.3s)
...
"""
```

Even if XML injection fully succeeds, leave these notes. They're the human-readable source of truth.

## Animation injection workflow

After all slides are built and saved:

```bash
python scripts/inject_animations.py \
    --in deck.pptx \
    --spec animations.json \
    --out deck_animated.pptx
```

Where `animations.json` is:

```json
{
  "slides": [
    {
      "slide_index": 0,
      "steps": [
        {"target": "T1", "animation": "fade_in", "trigger": "on_load", "duration_ms": 500},
        {"target": "G1", "animation": "fly_in_left", "trigger": "on_click", "duration_ms": 400},
        {"target": "A1", "animation": "wipe_right", "trigger": "on_click", "duration_ms": 300}
      ]
    }
  ]
}
```

The script:

1. Reads the pptx.
2. For each slide step, locates the named shape via XML lookup.
3. Generates the `<p:timing>` XML node for that step.
4. Inserts/extends the slide's `<p:timing>` element.
5. Saves the result.

If a step's animation type isn't reliably injectable, the script:

- Logs a warning.
- Skips XML injection for that step.
- Ensures the speaker-note mirror is present so the human can apply manually.

See [`animation-patterns.md`](animation-patterns.md) for the reliable-injection list.

## Render & verify

After build + inject:

```bash
# Convert to PDF for inspection
soffice --headless --convert-to pdf deck_animated.pptx

# Slice into per-slide images
pdftoppm -jpeg -r 150 deck_animated.pdf slide
```

Then visually inspect (use the QA checklist in `pptx/SKILL.md`). For animated slides, you can only verify the **final composed state** in the PDF — animations don't render to PDF. To verify animation order, open the pptx in PowerPoint or LibreOffice Impress.

If the user is on macOS without PowerPoint, suggest opening with Keynote (Keynote imports pptx animations imperfectly but is usually enough to verify order).

## Common build pitfalls

1. **Forgot to set `.name`** → animation injection can't find the shape. Always name every shape.
2. **Grouped before positioning** → can't tweak individual shape positions after grouping. Position first, group last.
3. **Wrong units** → mixing `Pt` and `Inches` gives tiny/huge shapes. Stick to `Inches` for layout, `Pt` for text.
4. **No `text_frame.margin_*`** → text doesn't align with shape edges. Set margins to 0 when alignment matters.
5. **Append vs. new** — if appending to an existing pptx, the slide layout dimensions are inherited; don't try to set `slide_width`/`slide_height` after loading. Use the existing deck's dimensions.
6. **Duplicate names** — adding two shapes both named `B1` makes lookup ambiguous. Use unique IDs from the plan.

## Output file conventions

For a multi-slide deck:

```
slides-out/<deck-name>/
├── deck.pptx                  # the built file
├── deck_animated.pptx         # post-animation-injection
├── slide-1-spec.md            # frozen spec for slide 1
├── slide-2-spec.md            # ...
├── animations.json            # the full animation spec across slides
└── preview/
    ├── slide-1.jpg
    └── slide-2.jpg
```

Save `slide-N-spec.md` with the four tables + ASCII sketch, frozen at confirmation time. This is the artefact the user can come back to weeks later to remember what was decided.
