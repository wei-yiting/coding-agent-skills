# Diff Authoring — the `data-diff` block

The template ships a custom diff renderer (`renderDiffs()` in the first `<script>`). At load it
finds every `<pre data-diff>`, splits lines, classifies each (`@@` hunk header / `+` add /
`-` remove / ` ` context), renders a left sign-gutter with red/green row backgrounds, and runs
highlight.js **per line** with the language from `data-lang` — so Python diffs highlight as
Python, TypeScript as TypeScript. Every rendered block gets a **Unified / Split mode toggle**
automatically (GitHub-style side-by-side pairing; one click switches the whole page, preference
persists in localStorage) — nothing to author for it.

## Markup

Wrap each diff in a `diff-card` with a file header, then the `pre`:

```html
<div class="diff-card">
  <div class="code-head">
    <span class="filename">backend/agent_engine/streaming/domain_events_schema.py</span>
    <div class="badges">
      <span class="stat add">+7</span>
      <span class="stat rem">−0</span>
      <span class="badge modified">modified</span>   <!-- or: <span class="badge new">new</span> -->
      <span class="lang">Python</span>
    </div>
  </div>
<pre data-diff data-lang="python">@@ -55,6 +55,12 @@ class ToolProgress:
     data: dict


+@dataclass(frozen=True)
+class ReasoningStatus:
+    reasoning_id: str
+    text: str
+
 @dataclass(frozen=True)
 class StreamError:</pre>
</div>
```

Rules the renderer depends on:

- **`data-lang`** is required — its value must be a highlight.js language id already loaded in
  the `<head>` (`python`, `typescript`, `javascript`, `yaml`, `css`, `xml`). Missing/unknown
  lang falls back to plaintext (works, but loses highlighting — treat as a bug).
- The `<pre>` content starts **immediately after the opening tag** (no leading newline) —
  a leading blank line renders as an empty context row.
- Keep unified-diff conventions: context lines start with one space, adds with `+`, removes
  with `-`, hunk headers with `@@`. `+++`/`---`/`diff --git` meta lines are also styled if
  included, but usually omit them — the `code-head` already names the file.
- HTML-escape the body (`<` → `&lt;`, `&` → `&amp;`) — diffs of TSX/HTML will break the page
  otherwise.

## Sourcing from git

Generate raw material with:

```bash
git diff --stat main...HEAD                 # file list + counts for risk map / stats tables
git diff main...HEAD -- <path>              # per-file diff to curate
```

Use the merge-base three-dot form so the diff shows only this branch's changes.

## Curating hunks — the most important judgment call

Do NOT paste whole-file diffs. The HTML is a *guided tour*, not a mirror of `git diff` — the
reviewer has the real diff in their IDE/GitHub. Each `data-diff` block should show only the
hunk(s) that carry the point being made in the surrounding prose:

- Show the **decision-carrying lines**: the new dispatch branch, the guard clause, the changed
  signature. Cut mechanical spillover (import shuffles, rename fallout) — mention those in one
  prose sentence instead.
- Keep 2–3 context lines around changes so the reader can orient; trim the rest. It is fine to
  splice non-adjacent hunks of the same file into one block — the `@@` headers keep them
  honest about line numbers.
- A good target is 10–40 lines per block. If a block wants to be 100+ lines, the explanation
  is probably trying to cover two points — split into two cards with their own prose.
- The `+N/−N` stats in `code-head` should be the **file's real totals** from `--stat` (not the
  curated excerpt's), so the reviewer knows how much they are *not* seeing.
- New files: show the core class/function bodies as all-`+` lines, badge `new`. For a large
  new file, show the public surface + the one tricky private helper; summarize the rest.
