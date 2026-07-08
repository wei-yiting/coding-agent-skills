# Annotation System

The template ships a complete client-side commenting/annotation system. It's **on by
default**; to ship a view-only HTML, add `class="annotations-off"` to `<body>` (the CSS
hides the comment UI and the layout collapses to a single column; `init()` skips wiring it
up). You don't write any of this JS — it's already in the template. This doc explains what
it does so you can (a) set the two required JS constants correctly and (b) explain the
workflow to the user.

## What the user can do

1. **Select text** anywhere in the doc body → a floating "💬 新增 comment" toolbar appears.
2. Click it → a dialog to type a comment. The dialog carries IME guards (ported from
   pr-review-html, 2026-07-07): Escape/keyCode-229 during CJK composition is ignored
   (`compositionstart`/`end` tracking + 30ms deferred clear, capture-phase keydown), backdrop
   dismiss requires mousedown AND click on the backdrop (drag-out doesn't close), and stray
   OS-level Escapes are ignored unless the textarea/body has focus. Don't simplify these away —
   they fix "dialog vanishes while typing Chinese". The selected text is highlighted yellow and a
   card appears in the right-hand comment panel.
3. Each comment is **active** (yellow), and can be toggled to **resolved** (dim gray-green)
   or auto-flagged **outdated** (dim gray-blue) — see status model below.
4. **Export** the comments to hand back to Claude: `Copy JSON` (clipboard, primary daily
   action) or `Export ▾` → JSON file / Prompt markdown.

## The two constants you MUST set

In the template's first `<script>`:

```js
const STORAGE_KEY = '{{STORAGE_KEY}}';
const DOC_NAME = '{{DOC_NAME}}';
```

- **`STORAGE_KEY`** — the `localStorage` key the comments persist under. This MUST be
  **unique per document**, otherwise two different HTML docs opened in the same browser
  would share/clobber each other's comments. Derive it from the output filename, e.g.
  `htmlify-comments-design-v1` for `design.html`. Keep the `-v1` suffix — bumping it (`-v2`)
  is the escape hatch if you ever change the comment schema and need a clean slate.
- **`DOC_NAME`** — human-readable doc name embedded in exports so Claude knows which doc the
  comments belong to. e.g. `design.md — SEC Filing Pipeline 簡化`.

Everything else the persistence layer needs is derived from `STORAGE_KEY` at runtime (the
dirty flag `STORAGE_KEY + '-dirty'`, the panel width `STORAGE_KEY + '-width'`, the linked-file
IndexedDB handle key) and the sidecar filename is derived from the page URL — so these two
constants are still the only things you set.

## Status model (3 states)

| State | Trigger | Highlight | Card | In export? |
|---|---|---|---|---|
| **active** | new comment, or text still found on reload | yellow `#fef08a` | normal, no pill | ✅ yes |
| **resolved** | user clicks `✓ Resolve` | dim gray-green `#e6ede9`, opacity 0.5 | "resolved" pill | ❌ excluded |
| **outdated** | on reload, the selected text is no longer found in its section | dim gray-blue `#dbe6f3`, opacity 0.5 (no in-doc mark) | "outdated" pill | ❌ excluded |

**Why outdated matters:** when you regenerate the HTML after editing the source doc, a
comment's anchored text may no longer exist. Instead of silently failing or showing an
error, the system flags it `outdated` and dims it — the reviewer sees "this comment was
about something that changed" without it cluttering the active queue. `resolved` takes
precedence over `outdated` (a done comment stays done even if its text is gone).

Marks are restored on reload by searching each section's text for the saved `selectedText`
substring — so as long as the commented passage still exists, the highlight comes back.

## Export JSON schema

`Copy JSON` / `Export ▾ → JSON` produces:

```json
{
  "version": 1,
  "doc": "<DOC_NAME>",
  "exported_at": "2026-05-28T...",
  "comment_count": 3,
  "resolved_excluded": 5,
  "outdated_excluded": 2,
  "comments": [
    {
      "id": "c...",
      "sectionId": "s5",
      "sectionLabel": "§5 Chunking & Plan B",
      "selectedText": "the exact highlighted text",
      "comment": "the user's note",
      "createdAt": "2026-05-28T..."
    }
  ]
}
```

Only **active** comments are in `comments[]`; resolved/outdated are reported as counts only.
The `Export ▾ → Prompt` variant produces the same data as readable markdown that the user
can paste straight back into a Claude session.

## How the review loop works (explain this to the user)

1. You generate `<doc>.html` and open it.
2. User reads, selects text, leaves comments.
3. User clicks `Copy JSON` (or `Export Prompt`) and pastes the result back to Claude.
4. Claude addresses each comment (editing the **source `.md`**, which is the source of
   truth — not the HTML).
5. User clicks `✓ Resolve` on addressed comments (or `Resolve all`), then regenerates the
   HTML. Resolved comments stay dim & excluded; anything whose text changed becomes
   `outdated`. Only genuinely-new/unaddressed comments remain active.

Because comments live in the sidecar JSON (and `localStorage` as a cache), **regenerating the
HTML file does not wipe them** — the new file with the same `STORAGE_KEY` and the same sidecar
re-attaches the existing comments. This is why the per-doc `STORAGE_KEY` is important.

## Persistence: sidecar JSON + auto-fetch ("static + git" model)

Comments are stored in a **sidecar file next to the HTML**, `<basename>.comments.json`
(`design.html` → `design.comments.json`), derived automatically from the page URL — nothing
to template. localStorage is a cache/fallback, not the source of truth.

**Read is automatic and gesture-free.** On load, when the page is served over http(s) (VS Code
Live Preview, any static host, GitHub Pages), the page `fetch`es the sidecar — so a deployed
page shows every committed comment read-only to all viewers. `file://` (double-clicking the
HTML) can't `fetch`, so it falls back to localStorage; tell users to serve over localhost.

**Write needs one click** (browsers forbid silent file writes). The sync-status pill in the
comment panel reflects state and offers the action:

| Pill | Meaning | Action offered |
|---|---|---|
| 📄 read-only | loaded from the sidecar via fetch, no write access | `enable editing…` (link the file) / `import…` |
| 💾 unsaved edits | in-memory edits not yet in the file (dirty) | `save to …json…` / `download…` / `import…` |
| 📁 Synced | linked via File System Access API, auto-saves (debounced) | `unlink` |
| ⚠ remembered | handle remembered but permission lapsed this session | `grant permission` |
| 💾 Local only | no sidecar / browser without File System Access API | `link…` or `import…` |

A **dirty flag** (`STORAGE_KEY + '-dirty'`) guards unsaved edits so a reload never clobbers
them with the older committed file. File System Access API is Chrome/Edge only; other browsers
read via fetch and write via `import…` / `download…`.

**Load priority:** linked file handle → fetched sidecar → localStorage.

**Deploy / collaborate:** commit `<basename>.comments.json` next to the HTML. The author edits
+ saves locally (File System Access API) and commits; reviewers on the deployed page see all
comments read-only and hand changes back via git or by exporting JSON. Pure static — no
backend.
