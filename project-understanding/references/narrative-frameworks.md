# Narrative Frameworks

Templates for the draft narrative (Step 3) and the final recap document (Step 5). Fill them in the interview's language (see SKILL.md § Language).

## STAR skeleton (one per story)

Each line ends with its provenance tag. Keep S and T to one or two sentences — interviewers care about A and R.

```markdown
### <story title — the one-liner the user opens with>

- **Situation**: <系統當時的狀態、痛點> ✅/❓
- **Task**: <使用者負責解決什麼、成功條件是什麼> ✅/❓
- **Action**: <關鍵 2–4 步：做了什麼、為何這樣做而非別的> ✅/❓
- **Result**: <可量化結果優先；沒有數字就寫可觀察的改變> ✅/❓ (數字通常是 user-only gap)
```

## Technical deep-dive annex (one per story)

```markdown
#### 現在的架構

<Mermaid diagram — components and data flow of the area as it stands today>
<3–5 句白話說明，這是使用者被問「講一下架構」時的口頭版本>

#### 關鍵決策

| 決策 | 考慮過的替代方案 | 為何這樣選 | 付出的代價 |
|---|---|---|---|
| <決策> ✅/❓ | <alternatives> | <why> | <trade-off — 每個決策都有代價；寫不出代價代表還沒真的理解這個決策> |

#### 踩過的坑

- <問題 → 怎麼發現 → 怎麼解> ✅/❓ (排錯故事在面試中價值極高，優先挖掘 revert/hotfix)
```

## Follow-up questions (per story)

Derive from this story's actual trade-offs — the generic version of a question is worth less than the one anchored in this repo's specifics. Probe along four axes:

1. **替代方案**: 「為什麼不用 <這個 repo 真實考慮過或明顯可行的 X>？」
2. **極限**: 「10 倍流量/資料量時哪裡先壞？」「這個設計的失效模式是什麼？」
3. **重來**: 「現在重做會改什麼？」(答案應該來自 annex 的「付出的代價」欄)
4. **深挖**: 挑 Action 裡最技術性的一步往下問一層 — 這是驗證使用者是否真的理解 agent 寫的 code 的地方。

## Recap document (Step 5 output)

```markdown
# <Repo> 面試複習 — <topic>

## ⚠ 面試前重點複習
<rehearsal 中的 weak spots，每項附上正確答案的一句話版本。放最上面 — 這是面試當天要 cram 的清單>

## 30 秒版本
<這個 story 的 elevator pitch，用使用者在 rehearsal 中自己的說法>

## <Story 1>
<STAR skeleton — 全部 ✅，或明確標示「未確認」>
<Technical deep-dive annex>
<預期追問 + 每題的答題方向一句話>

## <Story 2> ...

## 使用者的原話
<rehearsal 中使用者講得好的句子，原樣保留 — 面試時用自己的話最自然>
```

Everything in the final document is either ✅ or explicitly marked 未確認 — the user must be able to trust that anything unmarked is safe to say out loud in the interview.
