# Overview Report (Stage 1)

The overview is shown when listing all open sessions. Each session is concise — just enough to identify and pick one. The detail view (Stage 2) is shown only after the user selects a session to resume.

## Project Name

- Use the GitHub repo name (`environment.repo_name`) when available
- Fall back to the last path segment of `environment.project_root`

## Relative Time

Display `updated_at` as relative time calculated from the moment of report generation, using the same system time source as `updated_at`:

- Under 1 hour: "不到 1 小時前"
- 1–23 hours: "約 N 小時前"
- 1–6 days: "約 N 天前"
- 7+ days: "約 N 週前"

## Overview Format

```
你有 N 個進行中的 session：

A. claude-skills ｜ main
   任務：Improve implementation-planning skill description
   階段：Human Review — Implementation Result ｜ 約 3 小時前
   Review 狀態：best description 已套用，待 human review skill 完整內容
   CodeChange：SKILL.md description 更新為 Iteration 2 best description
   - ✅ 3 iterations 完成，best = Iter2（test 88%/precision 100%）
   - 下一步：Human review skill 完整內容，評估失敗 query
------------------------------------------- [handoff-20260320-003000]
B. claude-skills ｜ main
   任務：Fix Skill Creator eval pipeline bugs
   階段：Implementation ｜ 約 3 小時前
   CodeChange：修復 4 個 eval pipeline bugs，accuracy 50%→88%
   - ✅ 4 bugs 全部修復驗證通過
   - 下一步：發 PR 到 Anthropic skill-creator repo
------------------------------------------- [handoff-20260320-003001]
C. fin-lab-x ｜ feat/v1-frontend-streaming（worktree）
   任務：UI Streaming Decomposition — S1/S2/S3 Master Design Track
   階段：Planning ｜ 約 2 小時前
   CodeChange：none
   - ✅ S1/S2/S3 分解與執行策略確認，Langfuse v4 + fallback，UI stack 定案
   - 💬 S1 event contract 與 v4 回退門檻待定
   - 下一步：新增 decomposition master section 並完成 S1 定稿
------------------------------------------- [handoff-20260320-081849]

另外還有 1 筆 pending 項目，輸入 'show pending' 查看。

要接手哪一個？
```

## Overview Field Rules

| Field | Rule |
|-------|------|
| Project line | `A.` followed by `repo_name ｜ branch`; append `（worktree）` after branch when `is_worktree` is true |
| 階段 | `workflow_stage` display value; for `human_review`, append ` — {review_target_label}`. Followed by `｜ relative_time` |
| Review 狀態 | Only shown when `is_human_reviewing` is true. One-line summary from `human_review_summary` |
| CodeChange | One-line summary from `file_changes.description`; `none` when no changes exist |
| ✅ line | Condense all `cowork.confirmed` items into one summary line |
| 💬 line | Condense all `cowork.in_discussion` items into one line. Omit if empty |
| 🚧 line | Condense all `cowork.blockers` items into one line. Omit if empty |
| 下一步 | Condense all `next_steps` into one summary line |
| Separator + Handoff ID | A dash line followed by the handoff ID on the same line: `------------------------------------------- [handoff-YYYYMMDD-HHmmss]`. Immediately follows the last content line of the block (no blank line above or below) |

## `human_review_target` Display Labels

| Value | Label |
|-------|-------|
| `brainstorm_design` | Design |
| `implementation_planning` | Implementation Plan |
| `implementation_result` | Implementation Result |
| `agent_review_result` | Agent Review Result |
| `manual_validation` | Manual Validation |

## Stale Warning (open, updated_at > 5 days)

Stale records use a minimal format — no CodeChange, Cowork, Memo, or next steps.

If all open records are stale, skip the "要接手哪一個？" question.

```
A. ⚠️ claude-skills ｜ main（超過 5 天未更新）
   任務：設定 Qdrant vector store
   階段：Planning ｜ 約 8 天前
   → 這筆超過 5 天沒更新了。已經完成了嗎？要改成 pending？還是繼續？
------------------------------------------- [handoff-20250312-091500]
B. ⚠️ claude-skills ｜ main（超過 5 天未更新）
   任務：清理 vector store migration script
   階段：Implementation ｜ 約 10 天前
   → 這筆超過 5 天沒更新了。已經完成了嗎？要改成 pending？還是繼續？
------------------------------------------- [handoff-20250310-184500]
```
