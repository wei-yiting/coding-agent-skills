# htmlify — Styling Guide & Content Patterns

The template (`assets/template.html`) already ships every CSS rule and JS behaviour.
Your job when filling `{{MAIN_CONTENT}}` is only to emit **content HTML** that uses the
class names below. Don't invent new CSS — reuse these classes so the doc stays visually
coherent and the annotation system keeps working.

## Table of Contents
- [Section block](#section-block)
- [Section tags (colors)](#section-tags-colors)
- [Headings inside a section](#headings-inside-a-section)
- [Tables](#tables)
- [Decision tables (categorized)](#decision-tables-categorized)
- [Callouts](#callouts)
- [Mermaid diagrams](#mermaid-diagrams)
- [Code blocks](#code-blocks)
- [Collapsible details](#collapsible-details)
- [Hero block (optional pieces)](#hero-block-optional-pieces)
- [Sidebar TOC](#sidebar-toc)
- [Color palette reference](#color-palette-reference)

---

## Section block

Every top-level heading (`## ` in markdown) becomes one `<section>`. The `id` must be
`s1`, `s2`, … in document order — the sidebar TOC links and the annotation system both
key off section ids. `section-num` shows `§N`.

```html
<section id="s1" class="doc-section">
  <div class="section-head">
    <span class="section-num">§1</span>
    <h2>背景與動機</h2>
    <span class="section-tag tag-architecture">Architecture</span>
  </div>

  <p>... section body ...</p>
</section>
```

The `<span class="section-tag …">` is **optional** — include it only when the section
clearly matches a category (see [section tags](#section-tags-colors) +
`section-keyword-map.md`). If nothing fits, omit the tag rather than forcing a wrong color.

## Section tags (colors)

| Class | Color | Typical section meaning |
|---|---|---|
| `tag-architecture` | blue | design / schema / data flow / structure / background |
| `tag-sunset` | orange | cleanup / deprecation / migration / teardown |
| `tag-inspect` | green | inspect / debug / observability / tooling |
| `tag-decision` | purple | decision summary / trade-offs / rationale |
| `tag-ab` | red | testing / experiment / A-B / eval / methodology |
| `tag-api` | teal | API / contract / endpoint / protocol |
| `tag-open` | yellow | open questions / future work / TODO / risk |

The label text inside the span is free — usually a one-word category (`Architecture`,
`Sunset`, `Decisions`, `Open`, …).

## Headings inside a section

Use `<h3>` for sub-headings and `<h4>` for sub-sub-headings. They're already styled
(h3 = medium weight, h4 = uppercase muted label). Don't use `<h1>` inside content — `<h1>`
is reserved for the hero title.

## Tables

Always wrap tables in `.table-wrap` so they scroll horizontally on narrow screens and get
the card border / hover styling.

```html
<div class="table-wrap">
<table>
  <thead><tr><th>Column A</th><th>Column B</th></tr></thead>
  <tbody>
    <tr><td>cell</td><td>cell</td></tr>
  </tbody>
</table>
</div>
```

## Decision tables (categorized)

When a doc has a "Decision Summary" style table, use `decisions-table` with a category
class to color the `#` column. Group rows by category and split into multiple tables (one
per category) so each gets its own color stripe.

```html
<div class="table-wrap">
<table class="decisions-table cat-pipeline">
  <thead><tr><th>#</th><th>Decision</th><th>選擇</th><th>理由</th></tr></thead>
  <tbody>
    <tr><td>1</td><td>...</td><td>...</td><td>...</td></tr>
  </tbody>
</table>
</div>
```

Category classes (drive the colored first column): `cat-pipeline` (blue), `cat-coexist`
(orange), `cat-ab` (red), `cat-api` (teal). Pick whichever maps to the section's theme;
if a doc has only one decision table, `cat-pipeline` is a fine neutral default.

## Callouts

Four callout flavours for emphasis blocks. Lead with a bold label, then the message.

```html
<div class="callout callout-info"><strong>Note</strong> · neutral context / definition.</div>
<div class="callout callout-warn"><strong>Heads-up</strong> · caveat, gotcha, or risk.</div>
<div class="callout callout-key"><strong>核心 insight</strong> · the key idea to remember.</div>
<div class="callout callout-success"><strong>已驗證</strong> · confirmed / positive result.</div>
```

- `callout-info` (blue) — neutral context, definitions, cross-references
- `callout-warn` (orange) — caveats, things to watch, design conflicts
- `callout-key` (purple) — the central insight of a section
- `callout-success` (green) — confirmed findings, "this works"

## Mermaid diagrams

Convert ` ```mermaid ` fences to a `<div class="mermaid">`. The diagram source goes inline
(NOT inside `<pre>`). The template's mermaid.js renders it and the lightbox makes it
click-to-zoom automatically — no extra wiring.

```html
<div class="mermaid">
graph TD
    A["Start"] --> B{"Decision?"}
    B -->|yes| C["Path 1"]
    B -->|no| D["Path 2"]
</div>
```

Keep node labels in double quotes and use `<br/>` for line breaks inside nodes (mermaid
HTML labels are enabled). Preserve any `classDef` / `class` styling from the source.

## Code blocks

```html
<pre><code class="language-python">def example():
    return 42</code></pre>
```

highlight.js auto-highlights. Use the right `language-*` class (`language-python`,
`language-javascript`, `language-bash`, `language-markdown`, …). HTML-escape the code
body: `<` → `&lt;`, `>` → `&gt;`, `&` → `&amp;`. For a pseudo-code / plain block, drop the
`language-*` class.

## Collapsible details

For long reference material (full pseudo-code, verbose tables) that would bloat the page,
tuck it into a `<details>` so the reader can expand on demand.

```html
<details>
  <summary>對應 pseudo-code（implementation reference）</summary>
<pre><code>... long content ...</code></pre>
</details>
```

## Hero block (optional pieces)

The hero always has `<h1>` (title) + `.subtitle`. Everything else is **conditional** —
include a piece only when the source doc justifies it (per the "auto-detect, show if
present" rule):

**Status badge** — only if the doc states a status (draft / WIP / approved / …):
```html
<span class="status-badge">draft</span>
```

**Stats grid** — only for docs rich enough to have countable structure (e.g. a long spec
with a decision table). Skip it for short/simple docs; an empty-looking stat card is worse
than none. Pick 2–4 genuinely meaningful counts:
```html
<div class="stats-grid">
  <div class="stat"><div class="stat-num">15</div><div class="stat-label">Sections</div></div>
  <div class="stat"><div class="stat-num">43</div><div class="stat-label">Decisions</div></div>
</div>
```

**Prereq / context callout** — only if the doc has a "前置 / prerequisites / background"
note worth surfacing at the top:
```html
<div class="prereq"><strong>前置</strong> · ...</div>
```

**Reference chips** — only if the doc references a set of companion files/links:
```html
<div class="research-links">
  <span class="research-chip">some_reference.md</span>
</div>
```

## Sidebar TOC

One `<li>` per top-level section, in order. `toc-num` is the number, `toc-label` is the
title. The `href` must match the section `id`.

```html
<li><a href="#s1"><span class="toc-num">1.</span><span class="toc-label">背景與動機</span></a></li>
```

`{{SIDEBAR_BRAND}}` = short doc name; `{{SIDEBAR_SUB}}` = one-line subtitle.

## Color palette reference

These are the exact values baked into the template — listed here so you understand the
system, not because you need to re-declare them.

| Token | Hex | Use |
|---|---|---|
| primary (blue) | `#2563eb` | links, primary button, architecture |
| sunset (orange) | `#f97316` | cleanup / deprecation |
| inspect (green) | `#10b981` | tooling / debug |
| decision (purple) | `#8b5cf6` | decisions |
| ab (red) | `#ef4444` | experiments |
| api (teal) | `#14b8a6` | API / contracts |
| open (yellow) | `#eab308` | open questions |
| active highlight | `#fef08a` | annotation: active comment mark + counter |
| resolved | `#e6ede9` (dim, opacity 0.5) | annotation: resolved comment (gray-green) |
| outdated | `#dbe6f3` (dim, opacity 0.5) | annotation: outdated comment (gray-blue) |

The annotation status colors (active/resolved/outdated) are load-bearing — the comment
panel counters, mark backgrounds, and card styles all reference them. Don't repurpose
those three for section content.
