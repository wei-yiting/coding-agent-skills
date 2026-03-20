# Report Format Reference

This file is the single source of truth for `session-handoff` output formatting.
Keep workflow logic in `SKILL.md`; keep rendering rules and canonical examples here.

## Standard Report (open sessions)

```
你有 N 個進行中的 session：

A. [handoff-20250318-143022] feature/etl-pipeline
   - CLI Tool：Claude Code
   - 專案：lexlab-x（worktree）
   - 任務：實作 SEC 10-K filing 的 PDF parsing pipeline
   - 階段：Implementation
   - 最後更新：2025-03-18 14:30

   File Changes：
   - Git Status：2 files with uncommitted changes, 1 untracked file
   - 檔案：chunker.py, test_chunker.py, experimental_splitter.py
   - 內容：正在實作 table-aware splitting，包含跨頁表格 merge 和對應 test case

   Cowork：
   - ✅ 確定使用 pdfplumber（而非 PyMuPDF）
   - ✅ chunking 策略確定用 semantic splitting + section boundary
   - 💬 正在討論 chunk overlap 策略（固定 token vs. sentence-boundary）
   - 🚧 卡住：PDF 表格跨頁的 merge 策略

   下一步：
   1. 完成 chunker.py 的 table-aware splitting
   2. 跑 test_chunker.py
   3. End-to-end test

------------------------------

B. [handoff-20250318-160000] feature/chunker-refactor
   - CLI Tool：Codex
   - 專案：lexlab-x
   - 任務：重構 chunker module
   - 階段：Human Review
   - Review 對象：implementation_result
   - Review 狀態：Reviewer 認為 error handling 不夠完整，config 的部分還沒改
   - 最後更新：2025-03-18 16:00

   下一步：
   1. 處理 reviewer 提出的 config 調整
   2. Re-run test suite

另外還有 1 筆 pending 項目，輸入 'show pending' 查看。

要接手哪一個？
```

## Stale Warning (open, updated_at > 5 days)

Stale records show only basic info and the stale warning prompt — no File Changes,
Cowork, or detailed next steps. The user needs to resolve the stale status first.

If all open records are stale, skip the "要接手哪一個？" question.

```
A. ⚠️ [handoff-20250312-091500] feature/qdrant-setup（超過 5 天未更新）
   - 專案：lexlab-x
   - 任務：設定 Qdrant vector store
   - 階段：Planning
   - 最後更新：2025-03-12 09:15
   → 這筆超過 5 天沒更新了。已經完成了嗎？要改成 pending？還是繼續？

------------------------------

B. ⚠️ [handoff-20250310-184500] feature/vector-cleanup（超過 5 天未更新）
   - 專案：lexlab-x
   - 任務：清理 vector store migration script
   - 階段：Implementation
   - 最後更新：2025-03-10 18:45
   → 這筆超過 5 天沒更新了。已經完成了嗎？要改成 pending？還是繼續？
```

## Human Review Session

```
A. [handoff-20250318-160000] feature/chunker-refactor
   - CLI Tool：Claude Code
   - 專案：lexlab-x
   - 任務：重構 chunker module
   - 階段：Human Review
   - Review 對象：implementation_result
   - Review 狀態：Reviewer 認為 error handling 不夠完整，config 的部分還沒改
   - 最後更新：2025-03-18 16:00

   下一步：
   1. 處理 reviewer 提出的 config 調整
   2. Re-run test suite
```

## Query Pending Format

```
你有 N 個暫時擱置的 session：

A. [handoff-20250315-091500] feature/qdrant-setup
   - CLI Tool：Opencode
   ...（same report format as above）
```

## Output Contract

- Use `A.`, `B.`, `C.` for session blocks in multi-session outputs.
- Insert a divider line with at least 30 hyphens between session blocks, for example `------------------------------`.
- Include `CLI Tool` in `Report Handoff` and `Query Pending`.
- `CLI Tool` is optional in stale warnings and save confirmations.
- Render the project name from the last path segment of `project_root`; append `（worktree）` when `is_worktree` is true.
- If `is_human_reviewing` is true, prioritize `Review 對象` and `Review 狀態` over `File Changes`.
- Within a session block, keep `File Changes`, `Cowork`, and similar sections as label + `-` bullets.
- Reserve `1. 2. 3.` numbering for `下一步`.

## Emoji Rules

- ✅ for confirmed items in cowork
- 💬 for in-discussion items in cowork
- 🚧 for blockers in cowork
- ⚠️ for stale warnings (open records > 5 days without update)
- No emoji on section headers (File Changes, Cowork, 下一步, etc.)

## After User Picks Up — Expanded Next Steps

When the user selects a handoff to resume and environment check passes, present
each next step with added context drawn from briefing, file_changes, and cowork:

```
接手 [handoff-20250318-143022] — 實作 SEC 10-K filing 的 PDF parsing pipeline

目前階段：Implementation
Branch：feature/etl-pipeline

詳細下一步：

1. 完成 chunker.py 的 table-aware splitting
   → 主要需要處理 nested table 的 edge case。目前 pdfplumber 在遇到
     nested table 時會把內外層 table 都回傳，需要過濾掉內層的。

2. 跑 test_chunker.py 確認新增的 test case 通過
   → 目前有 3 個新 test case 測試跨頁表格的 merge，之前還沒跑過。

3. 跑一次 end-to-end test 確認 parser → chunker 串接正常
   → 用 tests/fixtures/ 裡面的 sample PDF 跑完整 pipeline。
```

## Save Confirmation Format

```
已儲存 session handoff [handoff-20250318-143022]
- 任務：實作 SEC 10-K filing 的 PDF parsing pipeline
- 階段：Implementation
- File Changes：
  - Git Status：2 files with uncommitted changes, 1 untracked file
  - 檔案：chunker.py, test_chunker.py, experimental_splitter.py
  - 內容：正在實作 table-aware splitting，包含跨頁表格 merge 和對應 test case
- Cowork：
  - ✅ 確定使用 pdfplumber（而非 PyMuPDF）
  - 🚧 卡住：PDF 表格跨頁的 merge 策略
- 下一步：
  1. 完成 chunker.py 的 table-aware splitting
  2. 跑 test_chunker.py 確認新增的 test case 通過
  3. End-to-end test
```

If you are confirming multiple saved handoffs in one response:

```
已儲存 2 筆 session handoff：

A. [handoff-20250318-143022]
   - 任務：實作 SEC 10-K filing 的 PDF parsing pipeline
   - 階段：Implementation
   - File Changes：
     - Git Status：2 files with uncommitted changes, 1 untracked file
     - 檔案：chunker.py, test_chunker.py, experimental_splitter.py
     - 內容：正在實作 table-aware splitting，包含跨頁表格 merge 和對應 test case
   - Cowork：
     - ✅ 確定使用 pdfplumber（而非 PyMuPDF）
     - 🚧 卡住：PDF 表格跨頁的 merge 策略
   - 下一步：
     1. 完成 chunker.py 的 table-aware splitting
     2. 跑 test_chunker.py 確認新增的 test case 通過
     3. End-to-end test

------------------------------

B. [handoff-20250318-160000]
   - 任務：重構 chunker module
   - 階段：Human Review
   - File Changes：
     - Git Status：clean
     - 檔案：chunker.py, config.py
     - 內容：正在處理 reviewer 要求的 config 調整與 error handling 補強
   - Cowork：
     - ✅ reviewer 已指出 config 與 error handling 仍需補完
   - 下一步：
     1. 處理 reviewer 提出的 config 調整
     2. Re-run test suite
```
