# Query Pending Format

Uses the same Overview format but filtered for `status: "pending"`.

```
你有 N 個暫時擱置的 session：

A. fin-lab-x ｜ feat/v1-frontend-streaming（worktree）
   任務：Prepare upstream fix for Langfuse async generator bug
   階段：Research ｜ 約 2 天前
   CodeChange：none
   - ✅ 確認 issue langfuse/langfuse#12520，v3/v4 皆受影響
   - 🚧 需先建立本地 repro + test case
   - 下一步：在 langfuse-python 建立最小重現並提交 PR

   [handoff-20260320-104648]
```
