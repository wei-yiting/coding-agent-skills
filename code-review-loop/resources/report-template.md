# Code Review Improvement Report Template

Use this template in Step 5 to produce the final report.
Replace all `{variables}` with actual data from all rounds.

**Output language:** Traditional Chinese (zh-TW) with English technical terms (`file paths`, `function names`, `CLI commands`, `issue IDs`).

**Readability rule (important):**
- The report must be understandable without reading round files.
- Every fixed issue must include: **Problem / Fix / Impact / Verification**.
- Do not only provide round-level summaries.

---

```markdown
# Code Review Improvement Report

> **Task:** {task_name}
> **Date:** {date}
> **Rounds:** {total_rounds}
> **Reviewer model:** {reviewer_model}
> **Fixer model:** {fixer_model}

## 架構影響摘要

- {architecture_change_1}
- {architecture_change_2}
- {architecture_change_3}

如果沒有架構層級變更，寫：
`本次 review 無架構層面的變更，所有修正皆為 correctness / stability / documentation。`

## Summary

| 指標 | 數值 |
| --- | --- |
| 總輪數 | {n} |
| 發現 issues 總數 | {total_issues} |
| Blocking | {blocking_fixed}/{blocking_total} fixed |
| Major | {major_fixed}/{major_total} fixed |
| Minor | {minor_fixed}/{minor_total} fixed |
| Suggestion | {suggestion_adopted}/{suggestion_total} adopted |
| 文件修正 | {doc_fix_count} |

## 所有修正問題詳解

> 必填。每個 issue 都要用同一格式，避免 reviewer 需要回頭看 round artifacts。

### {ISSUE_ID}（{severity}）
- **問題：** {what_was_wrong}
- **修法：** {what_changed}
- **影響：** {why_it_matters}
- **驗證：** {tests/commands/evidence}

{repeat for every fixed issue, including verification-discovered issues}

## 文件修正

| 目錄 | 修正內容 |
| --- | --- |
| `{path}` | {doc_change_summary} |

如果沒有文件修正，寫 `無`。

## 未處理項目

| 類型 | 內容 | 原因 | 建議後續 |
| --- | --- | --- | --- |
| Suggestion / Design issue / Env-blocked | {item} | {reason} | {next_step} |

若全部處理完成，寫：`無`。

## Final Verification Results

### Code Level

- [ ] Unit Tests: {result}
- [ ] Lint: {result}
- [ ] Type Check: {result}

### Behavior Level

- [ ] {behavior_check_1}: {result}
- [ ] {behavior_check_2}: {result}

### Runtime / Observable Level

- [ ] {runtime_or_e2e_check}: {result}

## All Changed Files

| 檔案 | Review 修正摘要 |
| --- | --- |
| `{path}` | {review_fix_summary} |
```

---

## Authoring Notes

- Prefer issue-first readability over chronology.
- If an issue was reopened in later rounds, present it once in final form and mention "re-opened" in the **問題** line.
- Include real verification evidence (command + result), not "expected pass" wording.
