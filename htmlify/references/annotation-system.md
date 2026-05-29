# Annotation System

The template ships a complete client-side commenting/annotation system. It's **on by
default**; to ship a view-only HTML, add `class="annotations-off"` to `<body>` (the CSS
hides the comment UI and the layout collapses to a single column; `init()` skips wiring it
up). You don't write any of this JS — it's already in the template. This doc explains what
it does so you can (a) set the two required JS constants correctly and (b) explain the
workflow to the user.

## What the user can do

1. **Select text** anywhere in the doc body → a floating "💬 新增 comment" toolbar appears.
2. Click it → a dialog to type a comment. The selected text is highlighted yellow and a
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

Because comments live in `localStorage` (browser-side), **regenerating the HTML file does
not wipe them** — the new file with the same `STORAGE_KEY` re-attaches the existing
comments. This is why the per-doc `STORAGE_KEY` is important.
