# Section Tag Auto-Detection

When filling `{{MAIN_CONTENT}}`, look at each top-level section's **heading text** and
pick a `section-tag` color if it clearly matches one of the categories below. This is a
heuristic, not a strict rule — use judgment, and when a heading doesn't clearly fit, **omit
the tag** (a tagless section is cleaner than a miscolored one).

The point of the colors is to let a reviewer scan the doc and immediately see "this is the
cleanup section, this is the decision summary, this is the open-questions section." So tag
for *signal*, not for decoration.

## Keyword → tag map

| Tag (color) | Heading contains any of (case-insensitive) |
|---|---|
| `tag-architecture` (blue) | architecture, design, schema, data flow, dataflow, structure, component, model, overview, background, motivation, context, introduction, 背景, 動機, 架構, 設計, 結構 |
| `tag-sunset` (orange) | sunset, cleanup, clean-up, deprecat, migration, removal, teardown, retire, legacy, 移除, 清理, 淘汰, 退場 |
| `tag-inspect` (green) | inspect, debug, observability, tooling, monitoring, logging, ergonomics, devtools, 偵錯, 觀測, 工具 |
| `tag-decision` (purple) | decision, summary, trade-off, tradeoff, rationale, choices, 決策, 取捨, 總結 |
| `tag-ab` (red) | testing, test plan, experiment, a/b, ab testing, eval, evaluation, validation, methodology, benchmark, 實驗, 測試, 驗證, 評估 |
| `tag-api` (teal) | api, contract, endpoint, protocol, interface, method, payload, request, response, 介面, 合約 |
| `tag-open` (yellow) | open question, open questions, future work, todo, unresolved, pending, risk, next step, 待解, 待辦, 未來工作, 風險, 待續 |

## Resolution rules

1. **First clear match wins** — scan categories top-to-bottom in the table above; the order
   roughly reflects specificity. (e.g. a heading "API Contract Decisions" matches both
   `tag-decision` and `tag-api` — "decision" appears earlier, but "API contract" is the more
   specific subject, so prefer `tag-api`. Use judgment for these overlaps.)
2. **No match → no tag.** Don't force `tag-architecture` onto everything; leave it off.
3. **Reference/appendix sections** (e.g. "Research 摘要", "Appendix", "References") usually
   read as neutral context → `tag-architecture` or no tag.
4. **The decision-table category classes** (`cat-pipeline` / `cat-coexist` / `cat-ab` /
   `cat-api`) are separate from section tags — they color the `#` column inside a decision
   table. Match them to the table's theme the same way.

## Examples

| Heading | Tag |
|---|---|
| `## 1. 背景與動機` | `tag-architecture` (background) |
| `## 4. Detection Logic` | `tag-architecture` (design/logic) |
| `## 8. Sunset 計畫` | `tag-sunset` |
| `## 10. Inspect Ergonomics` | `tag-inspect` |
| `## 12. Decision Summary` | `tag-decision` |
| `## 15. A/B Testing Methodology` | `tag-ab` |
| `## API Contract` | `tag-api` |
| `## 13. Open Questions` | `tag-open` |
| `## Glossary` | (no tag) |
