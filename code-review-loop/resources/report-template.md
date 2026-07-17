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

> 三個時間點視角的第三站——post-implementation、結果已知，回答「做完後實際學到什麼?」（design.md 🎓 問「探索中我學到什麼?」、briefing.md 🎓 問「這個 slice 我將練習什麼?」）。內容須從本 slice 各 review round **實際發現**的 pattern、issue 與取捨蒸餾而來，不是通用原則的照抄。
> **概念進程，非重複：** design.md / briefing.md 的 Learning Notes 已教過的概念，只寫一行 recap + 指回原處，接著只補本階段的新角度；不重教。
> **Slice scoping：** 只涵蓋本 slice changeset 實際觸及的概念。
> 本節同時是 `/issue-ship` do-i-understand interview 的素材來源——這裡浮現的概念會成為訪談驗證的候選目標。以 `htmlify` 轉檔後，本節會呈現為浮動側欄，方便對照 diff 閱讀。

### 採用的工程策略

- {哪些計畫中的策略在實作中存活下來；實作時發現的概念理解修正（不重教概念——指回 design.md / briefing.md Learning Notes），連到促成它的 issue ID。}

### 權衡取捨

- {expected-vs-actual：plan / briefing 預期的 trade-off 對照實際發生的狀況，偏差扣回 review issue ID（CR-x.x / SP-x.x）。}

### 關鍵收穫

- {2–4 條 verified takeaway：review rounds 暴露的盲點，generalize 成原則，每條扣回揭露它的 issue ID。}
```

---

## Authoring Notes

- Prefer issue-first readability over chronology.
- If an issue was reopened in later rounds, present it once in final form and mention "re-opened" in the **問題** line.
- Include real verification evidence (command + result), not "expected pass" wording.
- **Reading Guide:** order files by review dependency (contracts/types → core logic → wiring → tests), not by path or diff order. Flag `⚠️` only for files on irreversible / external-contract / security paths — over-flagging defeats the purpose of pointing the reviewer at what matters. Keep each role description to one line.
- **Learning Notes:** distil from what the rounds actually surfaced — do not invent generic best-practice bullets. Each takeaway should trace back to a concrete issue ID and the principle behind its fix. Omit a subsection only if the rounds genuinely produced nothing for it.
