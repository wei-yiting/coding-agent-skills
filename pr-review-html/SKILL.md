---
name: pr-review-html
description: >-
  Generate an interactive, self-contained code-review HTML for a branch/PR from its git diff —
  real diff rendering with +/- gutters and per-language syntax highlighting, TL;DR + Before/After,
  risk map, Mermaid architecture diagrams with click-to-zoom, numbered flow walkthrough, review
  hotspots, a left takeaway panel, and a text-selection comment system that persists to a sidecar
  JSON. Use whenever the user wants a human-friendly review surface for a branch, PR, or diff —
  phrases like "make a PR review html", "explain this branch's changes for review", "做一份
  code review 的 HTML", "解釋這個 branch 的 code change 方便 PR review", "diff 的解釋頁面".
  Prefer this over hand-writing HTML whenever the input is a git diff / branch / PR; for
  converting a markdown doc to HTML use htmlify instead.
---

# pr-review-html

Turn a branch's git diff into a single interactive HTML file that guides a human reviewer
through the change — a *guided tour with an opinion*, not a diff mirror.

## Why this exists

A reviewer with only GitHub's diff view gets files in alphabetical order, no narrative, no
risk triage, and nowhere to leave structured comments that flow back to the author's agent.
This skill produces the review surface: why the PR exists, what changed where, which files
deserve real attention, the questions the author expects — with real diffs, zoomable
diagrams, and select-to-comment feedback that exports straight back into a Claude prompt.

You are not writing CSS or JS. The template (`assets/template.html`) contains the entire
runtime, heavily iterated (diff renderer, comment system with IME guards, resizable panels,
Mermaid lightbox, sidecar persistence). Your job: analyze the diff, write the content HTML,
fill the placeholders.

## Inputs & output

- **Input**: the current branch (vs its merge-base with main), or an explicit PR / branch /
  diff the user names. Also read PR body, `artifacts/current/implementation.md` or
  `briefing.md` if present — they carry intent you should reflect, not re-derive.
- **Output**: `artifacts/current/code-review.html` (create the directory if needed). If the
  user names a path, honor it. If the file already exists, don't silently clobber — say what
  regeneration changes and note that comments live in the sidecar JSON / localStorage, so
  they survive as long as `STORAGE_KEY` is unchanged.
- After writing, `open` it (macOS) so the user sees it immediately.

## Language convention

Explanatory prose is Traditional Chinese (Taiwan usage). Terminology, identifiers, file
paths, and code stay English. Headings may mix ("Backend Walkthrough", "系統架構圖" both fine).

## Workflow

### 1. Gather

```bash
git diff --stat main...HEAD        # sizing + file list
git log --oneline main...HEAD     # commit narrative
git diff main...HEAD -- <path>    # per-file, as needed while writing
```

Read intent sources (PR body / implementation.md / briefing.md / design.md) if they exist.
Skim the actual changed files where the diff alone is ambiguous — the walkthrough must
explain *why*, and why lives in the surrounding code.

### 2. Cluster & grade

- Group files by subsystem (backend / frontend / tests / config / docs). This decides the
  section structure — read `references/section-blueprint.md` now for the §0–§9 skeleton and
  how to scale it to diff size.
- Grade every non-trivial file for the risk map: **attention** (complex logic, private-API
  dependency, state machines, race guards), **medium** (behavior change, controlled surface),
  **safe** (types / config / purely additive). New public API and error paths outrank
  mechanical renames.
- Pick the hotspots (§6): anything the author had to work around, deviate from spec for, or
  depend on something fragile for. These are the pre-answered review comments — the section
  reviewers thank you for.

### 3. Write the content

Read `references/component-patterns.md` (markup for every element + a decision table matching
change-type → expression element) and `references/diff-authoring.md` (the `data-diff` block
format and hunk-curation rules) before writing.

Principles that make the output worth reading:

- **Curate, don't dump.** Show decision-carrying hunks (10–40 lines); summarize mechanical
  changes in one sentence. The reviewer has the full diff elsewhere.
- **Explain why, not what.** "改了什麼" is visible in the diff; the prose earns its place by
  carrying design rationale, rejected alternatives, and failure modes.
- **Pre-answer the review.** Every judgment call a reviewer would question gets a review
  bubble or hotspot *before* they ask.
- **Every code block gets highlighting**: `data-diff` blocks need `data-lang`; plain blocks
  need `<pre><code class="language-*">`. HTML-escape bodies.

### 4. Fill the template

Copy `assets/template.html` to the output path, then substitute:

| Placeholder | Fill with |
|---|---|
| `{{DOC_TITLE}}` | `PR Review · <branch>` (appears in `<title>` AND hero h1 — 2 occurrences) |
| `{{DOC_SUBTITLE}}` | one-line PR summary |
| `<!--{{STATUS_BADGE}}-->` | `<span class="status-badge"><branch> → main</span>` |
| `<!--{{HERO_STATS}}-->` | `stats-grid` (commits / files / ±lines / scenarios) |
| `<!--{{HERO_META}}-->` | the「怎麼 review」`.callout` (comment system + panel-collapse hints) |
| `{{SIDEBAR_BRAND}}` / `{{SIDEBAR_SUB}}` | `PR Review` / branch name |
| `<!--{{SIDEBAR_TOC}}-->` | `.toc-group` labels + `<ul class="toc">` entries (see section-blueprint.md) |
| `{{TAKEAWAY_CARDS}}` | left-panel `tw-card`s, or empty string for small PRs |
| `<!--{{MAIN_CONTENT}}-->` | all `<section class="doc-section" id="sN">` blocks |
| `{{FOOTER_TEXT}}` | `Rendered from <branch> · git diff main...HEAD · YYYY-MM-DD` |
| `{{STORAGE_KEY}}` | unique per doc, e.g. `pr-review-<branch-slug>-v1` |
| `{{DOC_NAME}}` | human-readable, e.g. `PR Review · feat/xxx` (embedded in comment exports) |

The template is ~4100 lines — don't Read it whole. Grep for `{{` to locate placeholders, read
each region with offset/limit, Edit there. `{{MAIN_CONTENT}}` is one marker replaced with the
full generated sections in a single Edit. Never touch the `<style>`/`<script>` blocks or CDN
tags. Both side panels ship collapsible: the takeaway panel toggles via the fixed 💡 button
(bottom-left), the comment panel collapses via the header » and reopens via the 💬 fab —
state persists per doc. The page is theme-aware (light/dark follow the OS).

### 5. Verify, open, hand off

- `grep '{{'` → zero leftovers.
- Every `pre[data-diff]` has `data-lang`; every plain `<pre><code>` has `language-*`.
- Anchors referenced by risk chips / TOC / `tw-card[data-anchor]` all exist as heading ids.
- `open` the file. Tell the user the path and that comments export back via the panel
  (Copy JSON / Export prompt-markdown → paste to Claude to address feedback).

## Comment persistence

Same model as htmlify: comments auto-save to a sidecar `<basename>.comments.json` next to the
HTML (File System Access API link, or import/download on other browsers), with localStorage as
cache; served-over-http pages auto-fetch the committed sidecar read-only. The sidecar is
committable — review feedback travels with the branch. When the user exports comments back,
address them by changing *code or the generated explanations*, then regenerate; unchanged
`STORAGE_KEY` keeps existing comments alive (text that changed flips to `outdated`).

## Runtime provenance

`assets/template.html` = the `htmlify` skill's template (visual shell, sidebar, hero,
comment panel + sidecar sync, mermaid lightbox, theme system) as of 2026-07-07, plus
PR-specific layers: diff renderer with unified/split toggle, risk map, review bubbles,
walkthrough, takeaway panel (collapsible), comment-panel desktop collapse, and dialog IME
guards that htmlify does not have yet (worth backporting). The two templates drift
independently — when fixing a runtime bug in either skill, check whether the other needs the
same patch.
