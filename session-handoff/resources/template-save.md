# Save Formats

## Multi-Save Planning Format

Use this before any multi-save write. This is a split-confirmation step only — nothing has been saved yet.

```
目前看起來可以拆成 2 筆 session handoff，但我還沒儲存，先跟你確認切分：

A. 暫定任務：調整 Session Handoff skill 的 multi-save workflow
   - 階段：Planning
   - 範圍：補 `SKILL.md` 的 split-review 規則，以及 `report-template.md` 的 pre-save confirmation format
   - 檔案 / 討論重點：session-handoff/SKILL.md、session-handoff/resources/report-template.md
   - 下一步：
     1. 確認 split review wording
     2. 修改 skill 與 template
   - 待確認：這筆是否只涵蓋 workflow，不包含 script 變更

------------------------------

B. 暫定任務：補 multi-save 的驗證案例
   - 階段：Planning
   - 範圍：整理 explicit multi-save、single-save、overlap edge case 的 pressure scenarios
   - 檔案 / 討論重點：eval prompts 與 acceptance criteria
   - 下一步：
     1. 確認要保留哪些 pressure scenarios
     2. 再決定是否寫成 evals
   - 待確認：這筆要不要獨立成 handoff，還是併回 A

如果這樣切沒問題，我再正式儲存。
如果要調整任務名稱、範圍、內容邊界或順序，直接告訴我。
```

## Save Confirmation Format

```
已儲存 session handoff [handoff-20250318-143022]
- 任務：實作 SEC 10-K filing 的 PDF parsing pipeline
- 階段：Implementation
- CodeChange（Uncommitted）：
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
   - CodeChange（Uncommitted）：
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
   - 階段：Human Review — Implementation Result
   - CodeChange（Committed）：
     - 檔案：chunker.py, config.py
     - 內容：處理 reviewer 要求的 config 調整與 error handling 補強
   - Cowork：
     - ✅ reviewer 已指出 config 與 error handling 仍需補完
   - 下一步：
     1. 處理 reviewer 提出的 config 調整
     2. Re-run test suite
```
