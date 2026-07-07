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
| Spec findings (SP-) | {spec_fixed}/{spec_total} fixed |
| 文件修正 | {doc_fix_count} |

## Spec Conformance（Spec 軸）

> 與 Quality 軸並列呈現，不合併排序。每筆引用對應的 spec 來源行。

| ID | 類型 | Spec 依據 | 結果 |
| --- | --- | --- | --- |
| SP-{n}.{n} | Missing / Scope creep / Misimplemented | "{spec line}" | {fixed / accepted / deferred} |

若 Spec 軸零 findings，寫：`Spec 軸無 findings — 需求覆蓋完整、無 scope creep。`
若因無 spec 來源而跳過，寫：`Spec 軸未執行：無 spec 來源（無 implementation.md / Linear issue / 使用者提供的 spec）。`

## Reading Guide

> 給人類 reviewer 的建議閱讀順序。這是 slice PR 的導覽表——不必從上到下讀整個 diff，依此表逐檔查看即可。
> 排序原則：先讀 contracts/types，再讀 core logic，接著 wiring/整合，最後才是 tests。
> **風險標記：** `⚠️` 表示該檔案觸及不可逆操作、對外 contract（API / schema / wire format / migration）或 security 路徑，應優先且仔細檢視；其餘留白。

| 順序 | 檔案 | 在本次變更中的角色 | 風險 |
| --- | --- | --- | --- |
| 1 | `{path}` | {one_line_role} | {⚠️ or blank} |

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

## Learning Notes

> 教學性總結，供邊做邊學時回顧。內容須從各 review round **實際發現**的 pattern、issue 與取捨蒸餾而來，不是通用原則的照抄。以 `htmlify` 轉檔後，本節會呈現為浮動側欄，方便對照 diff 閱讀。

### 採用的工程策略

- {本次 review 實際強制或確立的 pattern，例如某個 boundary 的處理方式、error handling 慣例、測試分層策略。連到促成它的 issue ID。}

### 權衡取捨

- {以「選了 A 而非 B，因為 C」的形式描述。例如：為了 {目標} 接受了 {代價} 的 trade-off，放棄了 {被否決的方案}。}

### 關鍵收穫

- {2–4 條 takeaway，每條扣回一個 issue ID 及其背後的原則（issue 錯在哪、修正遵循什麼原則）。}
```

---

## Authoring Notes

- Prefer issue-first readability over chronology.
- If an issue was reopened in later rounds, present it once in final form and mention "re-opened" in the **問題** line.
- Include real verification evidence (command + result), not "expected pass" wording.
- **Reading Guide:** order files by review dependency (contracts/types → core logic → wiring → tests), not by path or diff order. Flag `⚠️` only for files on irreversible / external-contract / security paths — over-flagging defeats the purpose of pointing the reviewer at what matters. Keep each role description to one line.
- **Learning Notes:** distil from what the rounds actually surfaced — do not invent generic best-practice bullets. Each takeaway should trace back to a concrete issue ID and the principle behind its fix. Omit a subsection only if the rounds genuinely produced nothing for it.
