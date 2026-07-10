# HTML Recap Template (htmlify-unavailable fallback)

Spec for the self-contained recap page. It must work offline as a single file: inline all CSS/JS, no external requests at view time.

## Page structure

1. `<title>` + heading: `<Repo> 面試複習 — <topic>`
2. **⚠ cram box** — the weak-spot list in one visually loud card (warn color, top of page). One `<ol>` for all items, not one per item.
3. TOC sidebar (sticky) built from `h2`/`h3`.
4. Recap sections in document order, mirroring the markdown source.
5. Provenance legend: ✅ 證據確鑿 / ❓ 未確認 — style ❓ passages distinctly (e.g. dashed underline) so unconfirmed claims are visible at a glance while reading.

Readable typography (65–80ch measure, comfortable line height), light/dark via `prefers-color-scheme`.

## Mermaid

Prefer pre-rendering to inline SVG with mermaid-cli: `npx -y @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.svg`, then embed the SVG. If `mmdc` is unavailable, inline the mermaid.js library source into a `<script>` tag (do not rely on a CDN `<script src>` — the file must work offline). Verify the final HTML contains no raw ```mermaid text.

## Comment panel

Purpose: while the user reads, anything that feels shaky gets a comment — those comments are the input for the next rehearsal session. The panel is not a nice-to-have; it closes the review loop.

Behavior spec:

- **Add**: on text selection (`mouseup` with a non-empty selection), show a small 「留言」 bubble near the selection; clicking it opens an input; saving stores `{id, quote (selected text), sectionAnchor (nearest heading id), note, createdAt}`.
- **Display**: a right-side panel lists all comments (quote excerpt + note); clicking one scrolls to its section. Annotated passages get a persistent highlight, re-applied on load by text-matching the stored `quote` (best-effort — if the text isn't found, still show the comment in the panel, marked as unanchored).
- **Persist**: `localStorage` under `recap-comments:<topic-slug>` — survives reloads with zero setup.
- **Export**: a button that downloads `<topic-slug>.comments.json` (the full comment array). **Import**: a button that loads such a file and merges by `id`. Export exists because localStorage is invisible to the next Claude session — the JSON file is how comments travel back into rehearsal.

Timestamps come from the browser at comment time (`new Date().toISOString()`), never hardcoded.

## Verify before delivering

Open-file sanity check (or grep the HTML): inline SVG present, no raw mermaid source, cram box is the first content block, and the strings `localStorage`, the export filename, and the comment-panel container appear in the file.
