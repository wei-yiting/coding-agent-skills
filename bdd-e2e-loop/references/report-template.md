# BDD Verification Report Template

Follow this template when writing `artifacts/current/bdd-verification-report.md`.
Use Traditional Chinese (zh-TW) with English technical terms for user-facing sections.

---

```markdown
# BDD Verification Report

## Meta
- Date: {YYYY-MM-DD}
- Scenarios: `artifacts/current/bdd-scenarios.md`
- Verification Plan: `artifacts/current/verification-plan.md`

---

## Part 1: 測試紀錄與修復過程

### Scenario 進展矩陣

僅列出**曾經失敗過**的 scenario。首輪即通過且從未回歸的 scenario 不列入。

| Scenario | 類型 | Round 1 | Round 2 | ... | Final |
|----------|------|---------|---------|-----|-------|
| {S-id} | {type} | FAIL | PASS | ... | PASS |
| {S-id} | {type} | FAIL | FAIL | ... | PASS |
| {S-id} | {type} | PASS | REGRESS | ... | PASS |

> 標記說明: PASS = 通過, FAIL = 失敗, ERROR = 執行錯誤, SKIP = 該輪未執行, REGRESS = 前輪通過但本輪失敗

**始終通過:** {N} 個 scenario 在所有輪次中均通過，未列入上表。

### 修復歷程

#### Round {N}

**驗證結果:** {pass_count} pass / {fail_count} fail / {error_count} error

**失敗 Scenarios:**

| Scenario | 預期 | 實際 | 分類 |
|----------|------|------|------|
| {S-id}: {title} | {expected result} | {actual result} | Implementation Bug / Design Issue |

**Fixer 修復:**

| Scenario | Root Cause | 修復方式 | 變更檔案 |
|----------|-----------|---------|---------|
| {S-id} | {為什麼會 fail — 根本原因} | {具體做了什麼改動} | {file paths} |

**未修復:**

| Scenario | 原因 |
|----------|------|
| {S-id} | {為什麼沒修 — e.g., scenario expectation 有問題, 需要 design 決策} |

**回歸觀察:** {本輪修復是否造成之前通過的 scenario 回歸？列出受影響的 scenario}

{每輪重複以上區塊}

### Design Issue 決策紀錄

> 僅在有 design issue 時列出。無則省略此區塊。

#### {S-id}: {title}

- **衝突**: {scenario 預期 vs code 實際行為}
- **分析**: {為什麼判定為 design issue 而非 implementation bug — 例如連續 N 輪修復失敗}
- **User 決定**: {調整 design / 調整 scenario / 接受現狀}
- **結果**: {因應決定做了什麼改動}

---

## Part 2: 最終狀態

### Automated Scenarios

僅列出曾經失敗過或最終仍失敗的 scenario。

| Scenario | Status | 首次通過輪次 | 修復摘要 |
|----------|--------|------------|---------|
| {S-id}: {title} | PASS | Round {N} | {最終修好的關鍵修復，例如「Round 2 加入 email validation」} |
| {S-id}: {title} | FAIL | — | {最終仍失敗的原因} |

**始終通過:** {N} 個 scenario 在所有輪次中均通過。

### Manual Behavior Test

> 因技術限制需要人工輔助的 behavior verification

#### {S-id}: {title}
- **結果**: Pass | Fail
- **User 回饋**: {從 manual-results JSON 整合}
- **修復** (如有): {修了什麼}

### User Acceptance Test

> 待 PR review 時由 User 執行的產品驗收

#### {S-id}: {title}
- **狀態**: Pending — 待 PR review 驗收
- **驗收問題**: {acceptance question}
- **驗證步驟**: {steps}
- **預期結果**: {expected}

### Summary

| 指標 | 值 |
|------|-----|
| Automated Scenarios | {N} |
| Manual Behavior Test Scenarios | {N} |
| User Acceptance Test Scenarios | {N} |
| Automated 通過 | {N} / {total} |
| Manual 通過 | {N} / {total} |
| Automated 輪數 | {N} / 5 |
| Manual 觸發的 Re-verification 輪數 | {N} / 3 |
| Fix Rounds | {N} |
| 升級為 Design Issue | {N} |

### 最終狀態: {全部通過 | 部分通過 | 達到輪數上限}

---

## 未解決的問題

{列出仍然失敗的 scenarios，附上分析為什麼在輪數限制內無法修復，以及建議的後續行動}

{如果沒有未解決問題，寫: "所有 scenarios 均已通過。"}
```

---

## Template Notes

- **Language**: User-facing sections in Traditional Chinese; technical terms (file paths, commit hashes, scenario IDs, commands) in English
- **Part 1 — 過程**: Only include scenarios that failed at least once. Every round should have enough detail that a reviewer can understand: what failed, why, how it was fixed, and whether the fix caused regressions. The progression matrix provides the quick overview; the per-round details provide the depth.
- **Part 2 — 結果**: Only include scenarios that had at least one failure or remain failing. Always-passing scenarios are summarized as a single count line ("始終通過: N 個 scenario"). The "首次通過輪次" column helps reviewers gauge how many fix attempts each scenario required.
- **Progression matrix**: Only list scenarios that had at least one non-PASS status. Use REGRESS to flag scenarios that passed then failed — these are critical signals. Always include a "始終通過" count below the table.
- **Design Issues section**: Only include if design issues were surfaced. Omit if none.
- **未解決的問題 section**: Only include if there are remaining failures. If everything passes, write a single line confirming.
- **Integrate manual results**: Do not reference `manual-results-round-{N}.json` as a standalone artifact. All manual verification content belongs in this report.
