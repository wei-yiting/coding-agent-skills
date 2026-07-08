# Section Blueprint — the §0–§9 skeleton

The template's `{{MAIN_CONTENT}}` is a sequence of `<section id="sN">` blocks. This is the
proven ordering — a reviewer reads top-down from "why does this PR exist" to "what do I do
after reading". Keep the order; scale each section's depth to the diff.

Every section follows the htmlify-shell pattern (the `id` on the `<h2>` is the TOC anchor):

```html
<section class="doc-section" id="s4">
<div class="section-head"><span class="section-num">§4</span><h2 id="backend">Backend Walkthrough</h2></div>
...
</section>
```

§0's banner is NOT a section — it goes into the hero placeholders (`{{DOC_TITLE}}`,
`{{DOC_SUBTITLE}}`, `STATUS_BADGE`, `HERO_STATS`, `HERO_META`); only the optional
line-breakdown panel stays as a `doc-section`.

| § | id | Content | When to include |
|---|----|---------|-----------------|
| 0 | `s0` | Banner: branch line, title, subtitle, "怎麼 review" callout, metrics row. Optionally the **line-breakdown panel** | Always. Line-breakdown only when the raw line count would scare a reviewer (>2k lines) — its job is to answer "why so many lines?" |
| 1 | `s1` | **TL;DR card** (why this PR exists, one paragraph) + **Before/After** two-panel + a 3-row "面向" table | Always |
| 2 | `s2` | **Risk map** chips (link to walkthrough anchors) + legend + per-subsystem diff-stats tables | Always |
| 3 | `s3` | Architecture: Mermaid flowcharts (backend + frontend pipeline, `classDef new/mod/ext`) + Mermaid sequence diagram + **numbered step walkthrough** of the core flow | Include when the PR changes a flow/pipeline. For pure-refactor or config PRs, a single small diagram or none |
| 4 | `s4` | Backend walkthrough: per-file `diff-card` + explanation + **review bubbles** on tricky lines | Scale to diff: every behavior-changing file gets a card; mechanical changes get one summary table row instead |
| 5 | `s5` | Frontend walkthrough: same pattern | Same rule. Merge §4/§5 into one "Walkthrough" section if the PR touches only one side |
| 6 | `s6` | **Review Hotspots**: numbered h3 subsections, each = 問題 → 實作上的繞行/緩解 → 後果與建議. Each gets a `pill` severity | Always — even a clean PR has 1–2 "the reviewer will ask about this" items. This is the highest-value section; write it as if pre-answering review comments |
| 7 | `s7` | Tests: what's covered at which layer, how to run | Always |
| 8 | `s8` | **Where to focus**: numbered focus-items with exact `file:line` + why | Always. 3–5 items max — more dilutes the point |
| 9 | `s9` | **Next steps**: checkbox checklist of post-review actions with runnable commands | Always |

## Sidebar TOC (`{{SIDEBAR_TOC}}`)

Group entries under `.toc-group` labels; one `<li>` per major heading — section h2s plus
important h3s (hotspots, per-file walkthrough anchors). Labels are wrapped in `.toc-label`:

```html
<div class="toc-group">Overview</div>
<ul class="toc">
  <li><a href="#tldr"><span class="toc-label">TL;DR · Before/After</span></a></li>
  <li><a href="#scope"><span class="toc-label">Scope · Risk map</span></a></li>
</ul>
<div class="toc-group">Backend</div>
<ul class="toc">
  <li><a href="#reasoning-status"><span class="toc-label">domain_events_schema.py</span></a></li>
  ...
</ul>
```

## Takeaway panel (`{{TAKEAWAY_CARDS}}`)

The left panel holds one `tw-card` per walkthrough file: 改了什麼 / 為什麼這樣設計 / 帶走的.
`data-anchor` must match the corresponding walkthrough heading's `id` — that is what scroll-sync
and click-to-jump key on. See component-patterns.md § Takeaway cards for markup. The panel is
collapsible via the fixed 💡 toggle (bottom-left, state persists; defaults open on ≥1400px
viewports). If the PR is small (≤3 files), fill `{{TAKEAWAY_CARDS}}` with an empty string.

## Scaling guidance

- **Small PR (<300 lines)**: s0, s1, s2, merged walkthrough, s6 (1–2 hotspots), s8, s9. Skip
  line-breakdown, sequence diagram, takeaway panel.
- **Medium (300–2k)**: full skeleton, one flowchart, 2–4 hotspots.
- **Large (>2k)**: everything, line-breakdown mandatory, both pipeline flowcharts + sequence
  diagram, takeaway panel populated.
