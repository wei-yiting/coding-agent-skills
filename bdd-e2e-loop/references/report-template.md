# BDD Verification Report Template

Follow this template when writing `.artifacts/current/bdd-verification-report.md`.
Use Traditional Chinese (zh-TW) with English technical terms for user-facing sections.

---

```markdown
# BDD Verification Report

## Meta
- Date: {YYYY-MM-DD}
- Scenarios: `.artifacts/current/bdd-scenarios.md`
- Verification Plan: `.artifacts/current/verification-plan.md`

## 摘要

| 指標 | 值 |
|------|-----|
| Automated Scenarios | {N} |
| Manual Scenarios | {N} |
| Automated 通過 | {N} |
| Manual 通過 | {N} |
| Automated 輪數 | {N} / 5 |
| Manual 觸發的 Re-verification 輪數 | {N} / 3 |
| Fix Commits | {N} |
| 升級為 Design Issue | {N} |

## 最終狀態: {全部通過 | 部分通過 | 達到輪數上限}

---

## Automated Verification 結果

### Round {N}

**驗證結果:**
- 通過: {scenario IDs}
- 失敗: {scenario IDs + 簡要原因}

**Fixer 修復:**
- Commit: `{hash}`
- 修復內容: {摘要}
- 未修復: {scenario IDs + 原因}

{每輪重複}

---

## Design Issues

### {scenario ID}: {title}
- **問題**: {scenario 預期 vs code 實際行為}
- **User 決定**: {調整 design / 調整 scenario / 接受現狀}
- **結果**: {因應決定做了什麼改動}

{每個 design issue 重複}

---

## Manual Verification 結果

### Manual Behavior Test
> 因技術限制需要人工輔助的 behavior verification

#### {scenario ID}: {title}
- **結果**: Pass | Fail
- **User 回饋**: {從 manual-results JSON 整合}
- **修復**: {如果有的話}

### User Acceptance Test
> 待 PR review 時由 User 執行的產品驗收

#### {scenario ID}: {title}
- **狀態**: Pending — 待 PR review 驗收
- **驗收問題**: {acceptance question}
- **驗證步驟**: {steps}
- **預期結果**: {expected}

---

## Fix Commit 紀錄

| 輪次 | Commit Hash | 摘要 |
|------|------------|------|
| Automated Round 1 | `{hash}` | {修了什麼} |
| Automated Round 2 | `{hash}` | {修了什麼} |
| Manual Fix | `{hash}` | {修了什麼} |

---

## 未解決的問題

{列出仍然失敗的 scenarios，附上分析為什麼在輪數限制內無法修復}

{如果沒有未解決問題，寫: "所有 scenarios 均已通過。"}
```

---

## Template Notes

- **Language**: User-facing sections in Traditional Chinese; technical terms (file paths, commit hashes, scenario IDs, commands) in English
- **Design Issues section**: Only include if design issues were surfaced. Omit if none.
- **未解決的問題 section**: Only include if there are remaining failures. If everything passes, write a single line confirming.
- **Integrate manual results**: Do not reference `manual-results-round-{N}.json` as a standalone artifact. All manual verification content belongs in this report.
- **Round detail level**: Include enough detail for each round that someone reading the report can understand the progression without reading the temp files.
