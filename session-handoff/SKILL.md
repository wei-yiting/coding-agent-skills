---
name: session-handoff
description: "Use when the user wants to save current progress before stopping, resume or report an interrupted session, split one current session into multiple handoffs before saving, close a completed handoff, change handoff status, or list pending sessions. Trigger on phrases like 'save handoff', 'session handoff', '記錄進度', '明天繼續', '昨天做到哪', 'report handoff', 'close handoff', 'show pending', '改成 pending', '拆成兩個 handoff', '分成多個 session', or similar requests about saving, resuming, or managing interrupted work sessions."
---

# Session Handoff

Record interrupted work sessions so humans can pick up exactly where they left off. This skill captures a snapshot of the current session — environment, code changes, decisions made, and next steps — and stores it for later retrieval.

This is not a task tracker. It only records "in-flight, interrupted" work snapshots. The output is for humans who have been away, so reports should be rich enough for someone to quickly understand the full picture and resume work.

## Script Paths

The skill runtime provides a base directory header. Construct script paths from it:

```
<skill-base-dir>/scripts/save.py
<skill-base-dir>/scripts/close.py
<skill-base-dir>/scripts/status_update.py
```

Storage file: `~/.config/session-handoff/handoff.json` (JSON array of records).

## Operation Selection

| User Intent                    | Operation         | Example Phrases                                                              |
| ------------------------------ | ----------------- | ---------------------------------------------------------------------------- |
| Stop working, save progress    | **Save**          | "記錄進度", "save handoff", "明天繼續", "session handoff", "拆成兩個 handoff" |
| Check what was left incomplete | **Report**        | "昨天做到哪", "report handoff", "show sessions"                              |
| Mark a handoff as done         | **Close**         | "close handoff", "這個完成了", "關掉 handoff"                                |
| Change a handoff's status      | **Status Update** | "改成 pending", "abandon 掉", "撿回來"                                       |
| List shelved items             | **Query Pending** | "show pending", "還有什麼在 pending"                                         |

---

## Save Handoff

### Step 1: Gather Environment Info

Run these commands to collect environment data:

```bash
# Project root (empty string if not in a git repo)
git rev-parse --show-toplevel 2>/dev/null || echo ""

# Branch
git branch --show-current 2>/dev/null || echo ""

# Worktree detection: if these two differ → linked worktree
git rev-parse --git-dir 2>/dev/null
git rev-parse --git-common-dir 2>/dev/null

# Last commit
git log -1 --format='{"hash":"%h","message":"%s","timestamp":"%aI"}' 2>/dev/null

# GitHub repo name (empty string if not a GitHub repo)
gh repo view --json name -q .name 2>/dev/null || echo ""
```

For `cli_tool`: determine from the execution environment (e.g., Claude Code → `"claude-code"`). If you genuinely cannot determine it, ask the user — never guess.

For `repo_name`: use the GitHub repo name from `gh repo view`. If the command fails (not a GitHub repo, no `gh` CLI), fall back to the last path segment of `project_root`.

### Step 2: Gather File Changes

```bash
git status --porcelain 2>/dev/null
```

**If dirty (uncommitted/untracked files exist):**

```bash
git diff --cached --name-only          # staged
git diff --name-only                   # unstaged
git ls-files --others --exclude-standard  # untracked
git diff HEAD                          # diff content for context
```

Read untracked files if needed to understand them.

**If clean (no uncommitted changes):**

```bash
git show --name-only --format="" HEAD  # last commit's files
git diff HEAD~1 HEAD                   # last commit's diff
```

From the diff content and session conversation, produce:

- `git_status_summary`: Concise git state (e.g., `"clean"`, `"2 files with uncommitted changes, 1 untracked file"`)
- `files`: List of relevant file paths
- `description`: A unified summary of what these changes accomplish (not per-file)

### Step 3: Review Save Shape

Decide whether the current session should be stored as one handoff or multiple handoffs.

**Single handoff:** If the work is clearly one coherent task, continue to Step 4.

**Multi-handoff review required:** If the user explicitly wants multiple handoffs, or if there are multiple plausible handoff boundaries and you are not confident which split is correct, stop before saving and discuss the split with the user.

Even if the user already proposed the split, restate it in a structured way and ask for explicit confirmation before saving.

For each proposed handoff, present:

- `task.description`
- `task.workflow_stage`
- scope summary: what file changes, discussion threads, and next steps belong to this handoff
- any overlap, ambiguity, or boundary that still needs confirmation

Read `resources/template-save.md` and follow the `Multi-Save Planning Format` section.

Rules for this step:

- Do not run `save.py`
- Do not generate final record IDs yet
- Do not claim anything has been saved
- Wait for explicit user confirmation before continuing

If the user adjusts the split, update the proposal and ask again.
If most file changes, cowork context, and next steps overlap heavily, recommend a single handoff unless the user still wants separate records.

### Step 4: Dedup Check

Read existing handoff records:

```bash
cat ~/.config/session-handoff/handoff.json 2>/dev/null
```

Check each confirmed handoff candidate against existing `status: "open"` records:

1. Same `environment.project_root` **AND** `environment.branch`
2. `task.description` is semantically similar (same task, possibly at a different stage)

If both match → same task. Note the old record's `id` for replacement.
If same branch but clearly different task description → keep both, no replacement.
If one existing open record appears broader than multiple confirmed candidates, ask the user whether to keep it, close it, or replace it with one of the narrower records. Do not guess.
If uncertain → ask the user.

### Step 5: Build the Record

Construct one full JSON record per confirmed handoff following the **Record Structure** section below.

Key filling guidance:

- `id`: Format `handoff-{YYYYMMDD}-{HHmmss}` using current local time. If you are generating multiple records in one save flow, ensure each `id` is unique, for example by incrementing seconds while preserving order
- `status`: Always `"open"` for new saves
- `created_at` / `updated_at`: Current local time in ISO 8601 with timezone offset
- `task.workflow_stage`: Judge from session context which stage applies
- `task.progress.briefing`: One-paragraph background of what this task is about
- `task.progress.file_changes`: Scope this to the specific confirmed handoff using Step 2 plus the confirmed split boundaries
- `task.progress.cowork`: Synthesize from conversation history for this handoff only — decisions made, ongoing discussions, blockers. Sessions with few code changes but extensive discussion should have rich cowork content
- `task.progress.memo`: Extract noteworthy observations, technical details, or context from the conversation that don't fit into confirmed/in_discussion/blockers but are worth preserving for future sessions. Leave empty if nothing qualifies
- `task.next_steps`: Ordered list of what to do when picking this up

If you are uncertain about any aspect (whether something is confirmed, which stage applies, whether a blocker still exists, whether a file should belong to more than one handoff), ask the user rather than guessing.

### Step 6: Execute Save

```bash
echo '<json_record>' | python3 <skill-base-dir>/scripts/save.py [--replace-id <old-id>]
```

For multiple confirmed handoffs, run `save.py` once per record only after all split/content confirmation is complete.

Use `--replace-id` when Step 4 found a matching record to replace.

If any save command fails, stop immediately and tell the user which records were already written and which ones were not.

The script automatically cleans up expired records (resolved/abandoned with `updated_at` > 7 days). Pending records are never auto-cleaned.

### Step 7: Confirm to User

Read `resources/template-save.md` and follow the `Save Confirmation Format` section.

Use the single-save example or the multi-save example as appropriate. Use `Multi-Save Planning Format` only for the pre-save confirmation step.

---

## Report Handoff

### Step 1: Read Records

Read `~/.config/session-handoff/handoff.json`. If the file doesn't exist, tell the user there are no pending sessions.

**Time filtering:** If the user specifies a time range (e.g., "昨天做到哪"), filter by `updated_at` within that range. Otherwise, show all `status: "open"` records.

Pending records (`status: "pending"`) are excluded from regular reports.

### Step 2: Check Stale Records

For each open record, check if `updated_at` is more than 5 days ago. If so, flag it with ⚠️ and ask:

> 這筆 handoff（{id}）超過 5 天沒更新了。已經完成了嗎？要改成 pending？還是繼續？

Stale records only show basic info (project, task, stage, last update) and the stale warning prompt — no need to display full File Changes, Cowork, or detailed next steps. The user needs to resolve the stale status first before diving into details.

When rendering stale warnings, follow the `Stale Warning` format in `resources/template-overview.md`.

Handle the response:

- "繼續" → run `status_update.py --id <id> --status open` to refresh `updated_at`
- "完成了" → run Close flow
- "先放著" → run Status Update to change to `pending`

If all open records are stale, skip the "要接手哪一個？" question — focus on resolving the stale records first.

After processing all stale resolutions and any close/status-update requests from the user in the same message, re-read `handoff.json` before proceeding to Step 3. The overview must reflect the post-action state — the user should never see a stale or closed record reappear in the overview they just cleaned up.

### Step 3: Present Overview (Stage 1)

Read `resources/template-overview.md` as the formatting source of truth.

The report is a **two-stage flow**:

1. **Overview** — concise list of all open sessions, enough to identify and pick one
2. **Detail** — full context for the selected session, shown only after user picks one

In the Overview, condense each record's cowork and next steps into single summary lines. See the `Overview Field Rules` table in the template for exact rules.

End the Overview with "要接手哪一個？" to prompt the user to select.

### Step 4: Present Detail (Stage 2)

When the user selects a handoff to resume, check environment consistency:

```bash
git rev-parse --show-toplevel 2>/dev/null
git branch --show-current 2>/dev/null
```

Compare with the handoff's `environment.project_root` and `environment.branch`.

**If mismatch**, warn the user:

```
⚠️ 注意：你目前在 [current project/branch]，但這筆 handoff 記錄的是 [handoff project/branch]。
確定要在目前的位置繼續嗎？還是要先切到正確的 branch / directory？
```

Wait for confirmation before continuing.

**If match (or user confirms)**, present the full Detail view using `resources/template-detail.md`. This includes:

- Full CodeChange with file list (labeled Uncommitted/Committed)
- Full Cowork with all items
- Memo (if non-empty)
- Expanded next steps with context drawn from briefing, file_changes, and cowork

Each next step should include enough context so the user can jump right in without re-reading code or old conversations.

---

## Close Handoff

1. Match the record by handoff ID, or by current project+branch if the user doesn't specify. If multiple matches exist, list them and let the user choose.
2. Run:
   ```bash
   python3 <skill-base-dir>/scripts/close.py --id <handoff-id>
   ```
3. Confirm: "已關閉 handoff [id]"
4. Re-read `handoff.json` and present a refreshed Overview of remaining open sessions (same format as Report Step 3). The user just changed the landscape — show them what's left so they can decide what to do next without having to ask again. If no open sessions remain, say "目前沒有其他進行中的 session。" If processing multiple actions in the same message (e.g., close one + update another), present only one refreshed overview after all actions complete.

---

## Status Update

Valid status values: `open`, `pending`, `abandoned`.

1. Match the record by ID, branch, or semantic match from the user's description. If ambiguous, list candidates and ask.
2. Run:
   ```bash
   python3 <skill-base-dir>/scripts/status_update.py --id <handoff-id> --status <new-status>
   ```
3. Confirm the change.
4. Re-read `handoff.json` and present a refreshed Overview of remaining open sessions (same format as Report Step 3). Changing a record's status reshapes what the user sees as "active work" — refresh the view so they stay oriented. If no open sessions remain, say "目前沒有其他進行中的 session。" If processing multiple actions in the same message, present only one refreshed overview after all actions complete.

---

## Query Pending

1. Read `~/.config/session-handoff/handoff.json`, filter for `status: "pending"`.
2. Present using `resources/template-pending.md`.
3. If no pending records exist, say "目前沒有擱置中的項目。"

---

## Record Structure

Each record in `handoff.json` follows this structure. Read `resources/example-records.json` (in this skill's directory) for complete examples.

### Identification

| Field         | Type           | Description                                                                         |
| ------------- | -------------- | ----------------------------------------------------------------------------------- |
| `id`          | string         | `handoff-{YYYYMMDD}-{HHmmss}` from current local time. Ensure uniqueness if creating multiple records in one flow |
| `status`      | string         | `"open"` · `"resolved"` · `"pending"` · `"abandoned"`                               |
| `created_at`  | string         | ISO 8601 with timezone offset. Set on creation                                      |
| `updated_at`  | string         | ISO 8601 with timezone offset. Updated on every save/update/status change           |
| `resolved_at` | string or null | Set when status becomes `resolved` or `abandoned`; cleared when returning to `open` |

**Status definitions:**

- `open` — In progress, not finished. Should be picked up next session
- `resolved` — Done. Auto-cleaned when `updated_at` > 7 days
- `pending` — Shelved, not urgent. Hidden from regular reports. Never auto-cleaned
- `abandoned` — Dropped. Auto-cleaned when `updated_at` > 7 days

### Environment (auto-collected)

| Field                               | Type    | Description                                                          |
| ----------------------------------- | ------- | -------------------------------------------------------------------- |
| `environment.cli_tool`              | string  | `"claude-code"` / `"opencode"` / `"codex-cli"` — detect from runtime |
| `environment.project_root`          | string  | From `git rev-parse --show-toplevel`                                 |
| `environment.repo_name`             | string  | GitHub repo name from `gh repo view --json name -q .name`; fall back to last path segment of `project_root` |
| `environment.branch`                | string  | From `git branch --show-current`                                     |
| `environment.is_worktree`           | boolean | `true` if git-dir ≠ git-common-dir                                   |
| `environment.last_commit.hash`      | string  | Short commit hash                                                    |
| `environment.last_commit.message`   | string  | Commit message subject line                                          |
| `environment.last_commit.timestamp` | string  | ISO 8601                                                             |

### Task (written from session context)

| Field                                           | Type     | Description                                                       |
| ----------------------------------------------- | -------- | ----------------------------------------------------------------- |
| `task.description`                              | string   | One-line summary of the task                                      |
| `task.workflow_stage`                           | string   | Current stage (see values below)                                  |
| `task.progress.briefing`                        | string   | Background context paragraph                                      |
| `task.progress.file_changes.git_status_summary` | string   | Git state: `"clean"`, `"2 uncommitted, 1 untracked"`, etc.        |
| `task.progress.file_changes.files`              | string[] | File paths involved                                               |
| `task.progress.file_changes.description`        | string   | Unified summary of what the changes do                            |
| `task.progress.cowork.confirmed`                | string[] | Decisions and conclusions reached                                 |
| `task.progress.cowork.in_discussion`            | string[] | Ongoing discussions, options being explored                       |
| `task.progress.cowork.blockers`                 | string[] | Issues preventing progress                                        |
| `task.progress.memo`                            | string[] | Noteworthy observations, technical details, or context not covered by cowork fields |
| `task.is_human_reviewing`                       | boolean  | Whether human review is currently happening                       |
| `task.human_review_target`                      | string   | See values below. Empty string when not reviewing                 |
| `task.human_review_summary`                     | string   | What's being reviewed and current state. Empty when not reviewing |
| `task.next_steps`                               | string[] | Ordered list of what to do next                                   |

**`workflow_stage` values:**

| Value            | Meaning                                        |
| ---------------- | ---------------------------------------------- |
| `discussion`     | Discussing a topic without clear direction     |
| `research`       | Investigating, reading docs, comparing options |
| `brainstorming`  | Generating ideas, listing approaches           |
| `planning`       | Direction set, planning concrete steps         |
| `implementation` | Writing code, running tests, deploying         |
| `agent_review`   | Agent running code-review loop                 |
| `human_review`   | Human reviewing / giving feedback              |

**`human_review_target` values** (only when `is_human_reviewing` is true):

`brainstorm_design` · `implementation_planning` · `implementation_result` · `agent_review_result` · `manual_validation`

**Empty field defaults:** strings → `""`, arrays → `[]`, booleans → `false`, nullable fields → `null`.

---

## Output Contract

- Use `A.`, `B.`, `C.` for session blocks in multi-session outputs.
- In Overview, separate session blocks with a dash line + handoff ID on the same line: `------------------------------------------- [handoff-YYYYMMDD-HHmmss]`. The line immediately follows the last content line (no blank line above) and the next block starts on the very next line (no blank line below).
- **Overview (Stage 1):** `A.` line shows `repo_name ｜ branch`. No CLI Tool.
- **Detail (Stage 2):** 專案 line shows `repo_name ｜ branch ｜ cli_tool`.
- Render the project name from `environment.repo_name`; fall back to last path segment of `project_root`. Append `（worktree）` after branch when `is_worktree` is true.
- If `is_human_reviewing` is true, show `Review 狀態` in both Overview and Detail.
- In `Multi-Save Planning Format`, explicitly state that nothing has been saved yet.
- Within Detail, keep `CodeChange`, `Cowork`, `Memo` as label + `-` bullets.
- Reserve `1. 2. 3.` numbering for `詳細下一步` in Detail only.
- Display `updated_at` as relative time in both Overview and Detail.

## Emoji Rules

- ✅ for confirmed items in cowork
- 💬 for in-discussion items in cowork
- 🚧 for blockers in cowork
- ⚠️ for stale warnings (open records > 5 days without update)
- No emoji on section headers (CodeChange, Cowork, Memo, 下一步, etc.)

---

## Edge Cases

1. **Not in a git repo**: Fill git-related environment fields with empty strings, `is_worktree` with `false`, `file_changes.files` with `[]`, `file_changes.git_status_summary` and `file_changes.description` with `""`. Task and cowork sections can still be filled from conversation context.

2. **Log file doesn't exist**: Save creates it automatically (the script handles this). Report says "目前沒有未完成的 session。"

3. **Same branch, different tasks**: If the same branch has multiple open handoffs with clearly different `task.description` values, keep them separate — don't merge. Semantic judgment takes priority, with branch name as a secondary signal.

4. **Ambiguous match for close/update**: If no exact match by ID or current branch, list all candidates and let the user choose.

5. **Environment mismatch on pickup**: When the user picks up a handoff but is in a different project or branch, always warn and wait for confirmation before proceeding.

6. **Explicit multi-save request**: If the user wants to save the current session as multiple handoffs, discuss and confirm the split first. Do not save anything until the user confirms the boundaries and content.

7. **Heavy overlap between proposed handoffs**: If most files, cowork notes, and next steps would be duplicated across records, recommend a single handoff or ask the user to clarify the boundary.

8. **Multiple records created in the same second**: Keep the `handoff-{YYYYMMDD}-{HHmmss}` shape, but ensure each ID is unique before saving.
