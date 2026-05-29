---
name: htmlify
description: >
  Convert a structured markdown document (design doc, spec, RFC, research note, plan,
  technical writeup) into a polished, self-contained, interactive HTML page optimized for
  human review. Output has a floating collapsible table-of-contents, rendered + click-to-zoom
  Mermaid diagrams, syntax-highlighted code, color-tagged sections, an auto-detected stats
  header, and a built-in text-selection commenting system that persists in localStorage and
  exports feedback as JSON or a paste-back prompt. Use this skill whenever the user wants an
  HTML version of a markdown doc, a "review-friendly" / "shareable" / "nicer to read" doc, a
  webpage to leave comments on a spec or design, or says things like "htmlify", "make this
  into HTML", "turn this doc/spec/design into a web page", "把這份文件做成 HTML", "轉成 HTML",
  "做一個可以 review 的網頁", "做一個可以反白留言的版本". Prefer this over hand-writing HTML
  whenever the goal is a readable, navigable rendering of an existing markdown doc — even if
  the user doesn't say the word "htmlify".
---

# htmlify

Turn a markdown doc into a single interactive HTML file built for human review.

## Why HTML (the point of this skill)

Markdown over ~100 lines is tiring to read and impossible to navigate or annotate.
HTML carries far more signal: tables render, diagrams render and zoom, code is highlighted,
sections are color-coded for scanning, and — critically — a reviewer can **select text and
leave comments** that export straight back to Claude. The output is one self-contained file
(CSS + JS inline, three CDN libraries) that opens in any browser and is trivial to share.

You are not writing CSS or JS. The template (`assets/template.html`) already contains the
entire stylesheet and all behaviour, heavily iterated. Your job is to parse the source
markdown and fill a handful of placeholders with **content HTML**.

## Inputs & output

- **Input**: a markdown file (the user names it, or it's obvious from context — e.g. the
  `design.md` they were just discussing).
- **Output**: `artifacts/html/<source-basename>.html` by default. Create the `artifacts/html/`
  directory if it doesn't exist. If the user gives an explicit path, honor it.
- After writing, **open it** with `open <path>` (macOS) so the user sees it immediately.

## Workflow

### 1. Locate the source and resolve the output path

Confirm which markdown file to render. Compute the output path
(`artifacts/html/<basename>.html`). If an HTML already exists there, **don't silently
clobber it** — tell the user it exists and summarize what regeneration changes (e.g. "the
existing file has 12 sections, the source now has 15; regenerating refreshes the rendered
content. Your in-browser comments persist as long as the storage key is unchanged. Proceed?"),
then wait for the go-ahead. Comments live in `localStorage`, so overwriting the file does
**not** erase them.

### 2. Read the source and the references

Read the full source markdown. Then read the three reference files (they're short and you'll
need all of them):

- `references/styling-guide.md` — the exact content-HTML patterns (section block, tables,
  decision tables, callouts, mermaid, code, hero pieces, sidebar). **This is your main
  reference while generating.**
- `references/section-keyword-map.md` — how to pick each section's color tag from its heading.
- `references/annotation-system.md` — the commenting system + the two JS constants you must set.

### 3. Plan the content mapping

Walk the markdown structure and decide:

- **Sections**: each top-level `## ` heading → one `<section id="sN">` in order. Sidebar TOC
  gets one `<li>` per section. **Ignore `## ` lines that appear inside fenced code blocks**
  (between ` ``` ` fences) — those are sample content, not real sections. A naive
  `grep '^## '` over-counts because example markdown in code fences trips it; eyeball the
  structure or strip fenced blocks before counting.
- **Section tags**: apply a `tag-*` color per `section-keyword-map.md` where the heading
  clearly matches; otherwise leave untagged.
- **Hero stats**: include the `stats-grid` ONLY if the doc is substantial enough to have
  meaningful counts (long spec, decision table, etc.). For a short/simple doc, omit it — an
  empty-looking stat card is worse than none. Same "show only if present" logic for the
  status badge, prereq callout, and reference chips.
- **Rich elements**: map ` ```mermaid ` fences → `<div class="mermaid">`, code fences →
  `<pre><code class="language-*">`, markdown tables → `.table-wrap` tables, "Decision
  Summary"-style tables → `decisions-table cat-*`, and prominent notes/insights → `callout-*`.
- **Callouts**: don't over-apply. Use them for genuine emphasis (key insight, caveat,
  confirmed result, important context), not every paragraph.

### 4. Fill the template placeholders

Copy `assets/template.html` to the output path, then substitute:

| Placeholder | Fill with |
|---|---|
| `{{DOC_TITLE}}` | the doc title (appears in `<title>` and hero `<h1>`) |
| `{{DOC_SUBTITLE}}` | one-line subtitle / tagline |
| `{{STATUS_BADGE}}` | `<span class="status-badge">draft</span>` if the doc states a status; else empty |
| `{{HERO_STATS}}` | the `<div class="stats-grid">…</div>` if warranted; else empty |
| `{{HERO_META}}` | optional `.prereq` callout + `.research-links` chips; else empty |
| `{{SIDEBAR_BRAND}}` | short doc name for the sidebar header |
| `{{SIDEBAR_SUB}}` | one-line sidebar subtitle |
| `{{SIDEBAR_TOC}}` | the `<li>` TOC entries, one per section |
| `{{MAIN_CONTENT}}` | all the `<section>` blocks |
| `{{FOOTER_TEXT}}` | a short footer line (e.g. "Rendered from <source>.md · YYYY-MM-DD") |
| `{{STORAGE_KEY}}` | unique per doc, e.g. `htmlify-comments-<basename>-v1` (see annotation-system.md) |
| `{{DOC_NAME}}` | human-readable name embedded in comment exports |

Substitution is mechanical — Edit the copied file to replace each marker. Remove the
explanatory HTML comments next to the optional-hero placeholders once filled.

**Template is ~2000 lines (over the Read tool's single-pass limit) — don't try to Read it
whole.** The Edit tool needs a prior Read of the region you're editing, so read each
placeholder's surrounding lines with `offset`/`limit` (grep for `{{` first to get line
numbers), then Edit there. All placeholders sit in a compact band near the top
(`<title>`, hero, sidebar) plus the two JS constants (`{{STORAGE_KEY}}`, `{{DOC_NAME}}`) —
you never need the giant `<style>`/`<script>` middle. The big `{{MAIN_CONTENT}}` body is
one marker you replace with the full generated sections in a single Edit.

### 5. Annotations on/off

Annotations are **on by default**. If the user explicitly wants a view-only / no-comments
page, add `class="annotations-off"` to the `<body>` tag — the CSS hides the comment UI and
the layout collapses to a single centered column automatically.

### 6. Write, open, and verify

Write the filled file, `open` it, and sanity-check: every `{{PLACEHOLDER}}` is gone (grep
for `{{` to be sure), section count matches the source, and mermaid/code blocks are present.
Tell the user the path and a one-line summary of what's in it.

## Mermaid rendering note

Mermaid source goes **inline** inside `<div class="mermaid">…</div>`, never inside `<pre>`.
Keep node labels double-quoted and use `<br/>` for in-node line breaks. The lightbox
(click-to-zoom + pan) and CDN wiring are already in the template — don't add them.

## What to preserve from the template (don't touch)

- The entire `<style>` block and all `<script>` blocks.
- The comment panel, dialogs, toast, mermaid modal, sidebar toggle markup.
- The CDN `<script>`/`<link>` tags (mermaid, highlight.js, svg-pan-zoom).

You only ever edit the placeholder regions and (optionally) the `<body>` class.

## After generating

If the user reviews in-browser and exports comments back (JSON or prompt), address each
comment by editing the **source markdown** (the source of truth), then offer to regenerate
the HTML. Resolved comments stay dim and excluded from future exports; comments whose anchor
text changed become `outdated` automatically. See `references/annotation-system.md` for the
full review loop.
