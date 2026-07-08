# Component Patterns — expression elements and when to reach for each

All CSS/JS for these already lives in the template. Your job is to emit the markup with the
right class names. Every snippet here is copy-paste-ready; adapt content, keep structure.

**Decision table — match the change to the element:**

| The change is… | Express it as… |
|---|---|
| A behavior change (old path vs new path) | **Before/After two-panel** |
| A new multi-step flow across files | **Numbered step walkthrough** (+ Mermaid) |
| A judgment call the reviewer will question | **Review bubble** next to the diff |
| A known weakness / private-API dependency / spec deviation | **Hotspot subsection** (§6) |
| Risk triage across many files | **Risk map chips** |
| A scary line count | **Line breakdown panel** |
| Mechanical/routine change (renames, config bumps) | One table row or one prose sentence — no diff card |

Contents: [TL;DR card](#tldr-card) · [Before/After](#beforeafter) · [Risk map](#risk-map) ·
[Mermaid panels](#mermaid-panels) · [Step walkthrough](#step-walkthrough) · [Review bubbles](#review-bubbles) ·
[Status pills](#status-pills) · [Focus items](#focus-items) · [Checklist](#checklist) ·
[Line breakdown](#line-breakdown) · [Banner](#banner) · [Takeaway cards](#takeaway-cards) · [Callout](#callout)

## TL;DR card

One paragraph answering "why does this PR exist" — problem, root cause, what the PR does.
Write it so a reviewer who reads *only this* could still review sanely.

```html
<div class="tldr-card">
  <div class="tldr-label">為什麼這個 PR 存在</div>
  <p>舊 pipeline 假設 X … 結果 Y 壞掉。本 PR 把 … 。</p>
</div>
```

## Before/After

Two side-by-side panels, bulleted. Left = concrete broken/old behavior, right = new behavior.
Make bullets *parallel* (same aspect, before vs after) and bold the observable symptom.

```html
<div class="ba-grid">
  <div class="ba-panel before">
    <div class="ba-label">Before — 舊 pipeline 的狀態</div>
    <ul><li>…<strong>0 個 event 到 frontend</strong></li></ul>
  </div>
  <div class="ba-panel after">
    <div class="ba-label">After — 修完之後</div>
    <ul><li>…</li></ul>
  </div>
</div>
```

## Risk map

Chips linking to walkthrough anchors, three severities. Sort attention → medium → safe.
Follow with the legend.

```html
<div class="risk-map">
  <a class="risk-chip attention" href="#event-mapper"><span class="dot"></span>event_mapper.py</a>
  <a class="risk-chip medium" href="#segmenter"><span class="dot"></span>reasoning_segmenter.py</a>
  <a class="risk-chip safe" href="#sse-serializer"><span class="dot"></span>sse_serializer.py</a>
</div>
<div class="risk-legend">
  <span><span class="dot" style="background: var(--success-fg);"></span> Safe — 型別 / 配置 / 純 additive</span>
  <span><span class="dot" style="background: var(--warn-fg);"></span> Worth a look — 行為改動</span>
  <span><span class="dot" style="background: var(--ab);"></span> Needs attention — 複雜邏輯 / 私 API</span>
</div>
```

Severity rubric: **attention** = complex logic, private-API dependency, or state machines;
**medium** = behavior change with controlled surface; **safe** = types / config / purely additive.

## Mermaid panels

A bare `<div class="mermaid">` — the template styles it as a card with hover hint +
click-to-zoom lightbox (every rendered SVG becomes pan/zoomable). Do NOT add extra wrappers.
Use `classDef` to color node status and say so in prose ("綠色 = 新增、藍色 = 修改、灰色 = 未變動").

```html
<div class="mermaid">
flowchart LR
    A[StreamEventMapper<br/>content_blocks dispatch]:::mod --> B[ReasoningSegmenter]:::new
    B --> C[(Langfuse)]:::ext
    classDef new fill:#ecf7ee,stroke:#1f7a3a,stroke-width:1.5px,color:#1f7a3a
    classDef mod fill:#eef0ff,stroke:#5b6cff,stroke-width:1.5px,color:#1d4f8d
    classDef ext fill:#f6f6f4,stroke:#7a7e88,stroke-width:1.5px,color:#5a5e68
</div>
```

Mermaid source is inline (never in `<pre>`); quote node labels; `<br/>` for line breaks inside
nodes. Sequence diagrams for cross-component ordering; flowcharts for pipelines.

## Step walkthrough

Numbered end-to-end trace of the core flow — one step per file/function boundary. Add class
`hot` on steps whose logic deserves extra scrutiny. `details.snippet` holds a short source
excerpt (plain `<pre>`, no data-diff — this is "what the code looks like now", not a diff).

```html
<div class="steps">
  <div class="step">
    <div class="step-badge">1</div>
    <div class="step-body">
      <div class="step-loc">backend/…/event_mapper.py <span class="range">_handle_messages</span></div>
      <p>Chunk 進來先 … <strong>這是 PR 的核心 fix</strong>。</p>
      <details class="snippet">
        <summary>show source</summary>
<pre>for block in blocks:
    ...</pre>
      </details>
    </div>
  </div>
  <div class="step hot">…</div>
</div>
```

## Review bubbles

Pre-answer the review comment you *know* is coming. Place directly under the relevant
diff-card. Three flavors: `blocking` (must resolve before merge), `note` (why-explanation),
`nit`. Anchor names the exact location; bolded first line is the question being answered.

```html
<div class="review-bubble note">
  <div class="anchor">_handle_messages · LLM-call boundary check</div>
  <span class="rb-label">note</span>
  <strong><code>msg_chunk.id != self._current_llm_call_id</code> 為什麼是 boundary 訊號？</strong>
  LangChain v2 stream 在多回合 tool flow 下 … 。
</div>
```

Use `blocking` sparingly — it flags things the *author* believes need a reviewer decision.

## Status pills

Inline severity/status markers used in tables and h3 headings:
`<span class="pill low">new</span>`, `<span class="pill med">modified</span>`,
`<span class="pill med">medium</span>`, `<span class="pill high">high</span>`.

## Focus items

§8's "if you only have 10 minutes" list. 3–5 items, each with exact `file:line` and *why it
deserves eyes* — not what it does.

```html
<div class="focus-list">
  <div class="focus-item">
    <div class="focus-num">1</div>
    <div>
      <div class="focus-title">D29 schema 在 abort 路徑被打破</div>
      <div class="focus-desc"><code>base.py:589-614</code>. Completed path 寫 … 請 reviewer 確認 …</div>
    </div>
  </div>
</div>
```

## Checklist

§9's actionable post-review steps. Checkbox state is client-side only. Include the runnable
command in `check-note` whenever one exists.

```html
<ul class="checklist">
  <li>
    <input type="checkbox" id="ns1" />
    <label for="ns1">
      跑一輪 verifier，確認 abort path 真的寫 key。
      <span class="check-note">命令：<code>uv run python -m …</code></span>
    </label>
  </li>
</ul>
```

## Line breakdown

s0's "why so many lines?" panel: stacked bar + category table. Compute real percentages from
`git diff --stat` buckets (impl / tests / config / docs). Bar segment widths are the
percentage of total additions.

```html
<div class="breakdown">
  <h3>+7,814 行、81 個檔到底分布在哪？</h3>
  <p style="font-size: 15px; color: var(--fg-soft); margin: 0 0 12px;">實作 25% / 測試 70% / 非程式碼 5% …</p>
  <div class="bd-bar">
    <span class="bd-impl-fe" style="width: 8.61%;" title="Frontend impl: +673">8.6%</span>
    <span class="bd-impl-be" style="width: 12.03%;" title="Backend impl: +940">12.0%</span>
    <span class="bd-test-fe" style="width: 29.95%;" title="Frontend tests: +2340">30.0%</span>
    <span class="bd-test-be" style="width: 40.26%;" title="Backend tests: +3146">40.3%</span>
    <span class="bd-cfg" style="width: 4.40%;" title="Config: +344">4.4%</span>
  </div>
  <div class="bd-legend">
    <span><span class="swatch" style="background: #2b5fcc;"></span>Frontend impl</span>
    …
  </div>
  <table>…exact numbers per category…</table>
</div>
```

Available segment classes: `bd-impl-fe`, `bd-impl-be`, `bd-scripts`, `bd-test-fe`,
`bd-test-be`, `bd-cfg`, `bd-doc`, `bd-art`. Omit segments under ~0.5% width labels.

## Hero (replaces the old banner)

The opener lives in the template's hero placeholders, not in a section:

- `<!--{{STATUS_BADGE}}-->` → `<span class="status-badge">feat/xxx → main</span>`
- `{{DOC_TITLE}}` → human-readable PR title (also the `<title>`)
- `{{DOC_SUBTITLE}}` → 一句話講這個 PR 做什麼
- `<!--{{HERO_STATS}}-->` → the sizing numbers:

```html
<div class="stats-grid">
  <div class="stat"><div class="stat-num">36</div><div class="stat-label">commits</div></div>
  <div class="stat"><div class="stat-num">81</div><div class="stat-label">files changed</div></div>
  <div class="stat"><div class="stat-num">+7,814 / −133</div><div class="stat-label">lines</div></div>
  <div class="stat"><div class="stat-num">37 + 5</div><div class="stat-label">scenarios</div></div>
</div>
```

- `<!--{{HERO_META}}-->` → the「怎麼 review」callout:

```html
<div class="callout">
  <span class="label">💬 怎麼 review</span>
  選任何文字（含 diff 行）→ toolbar 浮出 → 「新增 comment」。Comment 存 sidecar JSON
  （<code>&lt;basename&gt;.comments.json</code>，可 commit）+ localStorage cache。
  右側 Comments panel 可 resolve / 匯出，「»」可收合（右下 💬 重開）；左側 💡 是
  Takeaway panel。Diff 區塊右上可切 Unified / Split。
</div>
```

## Takeaway cards

Left-panel cards, one per walkthrough file. `data-anchor` MUST equal the walkthrough heading
`id` it pairs with (scroll-sync + click-jump depend on it). Three fixed bits: 改了什麼 /
為什麼這樣設計 / 帶走的 — the last one is the generalizable engineering lesson.

```html
<article class="tw-card" data-anchor="segmenter">
  <div class="tw-head">
    <span class="tw-num">§4</span>
    <h4 class="tw-title">reasoning_segmenter.py</h4>
  </div>
  <div class="tw-body">
    <div class="tw-bit">
      <h5 class="tw-bit-label">改了什麼</h5>
      <p>新檔。把 token-by-token reasoning 切成完整句子再 emit。</p>
    </div>
    <div class="tw-bit">
      <h5 class="tw-bit-label">為什麼這樣設計</h5>
      <p>不能放 frontend — 不該把語言邏輯塞進 React。</p>
    </div>
    <div class="tw-tip">
      <span class="tw-tip-label">帶走的</span>
      <span class="tw-tip-body">ephemeral UI 資料要在 wire format 層就標 transient。</span>
    </div>
  </div>
</article>
```

## Callout

Generic emphasis block, used sparingly:

```html
<div class="callout">
  <span class="label">⚠ 注意</span>
  內文 …
</div>
```
