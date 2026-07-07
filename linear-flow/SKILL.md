---
name: linear-flow
description: >-
  Linear-driven issue lifecycle protocol: /issue-start (check out issue context into a session),
  /issue-sync (checkpoint progress + session resume info to Linear), /issue-ship (verify, deliver,
  hand off to the human gate), /issue-close (post-completion cleanup). Auto-advances the Linear
  issue status to match the work stage. Two project profiles: dev (FinLab-X / DONG-XX — worktrees,
  PRs, Design→…→Ready for Merge) and content (Interview Preparation / PREP-XX — articles, videos,
  interview practice, Idea→…→Published). Use whenever work corresponds to a Linear issue, when the
  user says issue-start/sync/ship/close, mentions a DONG-XX or PREP-XX id, or asks to update
  Linear progress.
---

# Linear Flow

Linear is the **single source of truth** for work state. A Claude Code session is a stateless
worker: it checks out state from Linear at the start, and checks results back in before it ends.

**The one hard rule**: work state may only live in durable storage (git remote / published cloud
doc) + Linear. Never end a session leaving the only copy of anything on local disk or in
conversation memory.

## Prerequisites

Linear MCP tools (`mcp__claude_ai_Linear__*`) may be deferred — load them in ONE ToolSearch call:

```
ToolSearch "select:mcp__claude_ai_Linear__get_issue,mcp__claude_ai_Linear__list_comments,mcp__claude_ai_Linear__save_issue,mcp__claude_ai_Linear__save_comment,mcp__claude_ai_Linear__list_issues"
```

## Project profiles

The protocol (start / sync / ship / close + session-resume bookkeeping) is identical across
profiles; what differs is the status model and what "deliver" means. Pick the profile from the
issue's team key.

| | dev profile | content profile |
|---|---|---|
| Team / prefix | `DongWYT` / `DONG-XX` | `Interview Prep` / `PREP-XX` |
| Projects | `FinLab-X` | `Interview Preparation`（文章、YouTube、面試練習、portfolio） |
| Work medium | git worktree + branch | 文章草稿、影片腳本/剪輯、練習紀錄——存放處寫在 issue description |
| Durable storage | git remote (push) | git repo push（若是 repo 內檔案）或雲端文件連結（Google Docs / Heptabase / Notion）貼進 issue |
| "Ship" means | open PR → human review → merge | 完稿 → Ready to Publish → 實際發佈 → Published（附公開 URL） |
| Human gate | PR review + merge | 發佈前的最終過稿 |

## Dev profile status model (stage-based)

Statuses mirror the dev pipeline. **Whenever the work enters a stage, immediately move the issue
to that status** (`save_issue` with `state`) — do not batch status updates for later.

| Status | Type | Stage meaning | Entered when… |
|---|---|---|---|
| `Noted` / `Soon (P1)` / `Later (P2)` | backlog | triage buckets | issue captured, not scheduled |
| `Todo (P0)` | unstarted | ready to start now | issue is next up |
| `Design` | started | exploring intent & solution | `design-brainstorming` starts, or open decisions pending |
| `Planning` | started | turning design into executable plan | `behavior-validation-plan` / `implementation-planning` / `generate-briefing` starts |
| `Implementation` | started | writing code | `subagent-driven-development` / TDD implementation starts |
| `Verification` | started | proving it works | `bdd-e2e-loop` / `verify` / test-suite passes being established |
| `Code Review` | started | agent quality gates before PR | `code-review-loop` / `do-i-understand` starts |
| `Human Code Review` | started | PR open, human reviewing | PR opened (also set by the team's GitHub automation "On PR open") |
| `Ready for Merge` | started | human review passed, awaiting merge | human signs off on the PR |
| `Merge & Deployed` | completed | merged + worktree cleaned | after merge (GitHub automation sets this on PR merge) |
| `Canceled` | canceled | dropped | user decision |

If a stage status does not exist in the team yet (statuses are team settings, not creatable via
MCP), fall back to the closest existing status and tell the user which statuses are missing.

Skill → status auto-move map (trigger on skill START, not completion):

- design-brainstorming → `Design`
- behavior-validation-plan, implementation-planning, generate-briefing, apply-briefing-update → `Planning`
- subagent-driven-development, test-driven-development (implementation work) → `Implementation`
- bdd-e2e-loop, verify → `Verification`
- code-review-loop, do-i-understand, requesting-code-review → `Code Review`
- pull-request (PR opened) → `Human Code Review`
- human approves the PR → `Ready for Merge`

## Content profile status model (team `Interview Prep`)

| Status | Type | Meaning | Move here when… |
|---|---|---|---|
| `Idea` | backlog | 點子池 | 靈感捕捉，尚未承諾 |
| `Queued` | unstarted | 排入近期 | 決定要做了 |
| `In Progress` | started | 寫作 / 錄製 / 練習中 | 實際開工（/issue-start 後第一次動工） |
| `Polish` | started | 修稿 / 剪輯 / 迭代 | 初稿完成，進入打磨 |
| `Ready to Publish` | started | 完稿待發佈 / 排程 | 內容定稿，等人工最終過稿或排程 |
| `Published` | completed | 已發佈 | 文章上線 / 影片公開——final comment 附公開 URL |
| `Done` | completed | 完成（不發佈類） | 面試練習、portfolio 整理等內部工作完成 |

Content-profile adaptations of the verbs:

- **/issue-start**: no worktree step. Read issue + latest sync comment, recap, locate the working
  material from the issue description (repo path or cloud-doc link), move status.
- **/issue-sync**: the "push" step becomes a **durable-storage check** — files in a git repo get
  committed AND pushed; cloud docs get their link pasted in the sync comment (the doc itself is
  durable); anything that exists only on local disk gets flagged in the comment as at-risk with a
  concrete note of where it lives. Everything else (checklist update, status correction, sync
  comment with session id + resume command) is identical to the dev profile.
- **/issue-ship**: deliverable finalized → status `Ready to Publish` + ship comment（成品位置、
  剩餘的人工步驟：排程、封面、SEO、平台設定）. After actual publication → `Published` + final
  comment with the public URL. Practice/portfolio issues skip publish and go straight to `Done`.
- **/issue-close**: verify nothing local-only remains, close out as `Published`/`Done`.

## Session identity (needed by every sync)

Resolve the current session's resume coordinates:

```bash
proj_dir="$HOME/.claude/projects/$(pwd | tr '/' '-')"
session_id=$(ls -t "$proj_dir"/*.jsonl 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/\.jsonl$//')
echo "cwd=$(pwd) session_id=$session_id"
```

Caveats: run this from the session's primary working directory (the one Claude Code was launched
in — not a `cd`-ed subdirectory). The newest `.jsonl` is the current session. If the user renamed
the session (`/rename`), include that name too — it is what shows in the `claude --resume` picker.

## /issue-start <DONG-XX>

1. **Read state**: `get_issue` (with `includeRelations: true`) + `list_comments`. The latest
   `🔄 Sync` comment is the authoritative "where we left off" — it contains the previous session's
   resume info and next steps. Relay a 3-5 line recap to the user before doing anything.
2. **Blockers**: if the issue is blocked by an unfinished issue, surface that and stop for the
   user's call.
3. **Worktree**: find the branch's worktree (`git worktree list`); the issue description usually
   names it. If none exists, create one via the `git-worktree` skill — prefer the branch name the
   issue description specifies, else Linear's suggested `gitBranchName`.
4. **Status**: move the issue to the stage status matching the work about to happen (see map).
5. **Start comment** (`save_comment` on the issue):

   ```markdown
   ### ▶️ Session start — <YYYY-MM-DD HH:mm>
   **Stage**: <status>
   **這個 session 的目標**: <1-2 lines>
   **Session**: `<session_id>`<（name: xxx）if renamed>
   **Resume**: `cd <worktree-abs-path> && claude --resume <session_id>`
   ```

## /issue-sync

Run when pausing, when the user asks, at any natural checkpoint, and ALWAYS before ending a
session that touched issue work. Steps:

1. **Commit** meaningful WIP (small, honest commit messages; never commit broken state silently —
   say what state it's in).
2. **Push** — mandatory, no exceptions. `git push -u origin <branch>` if no upstream yet.
3. **Checklist**: update the issue description's `- [ ]` items that are now done (`save_issue`
   preserving the rest of the description verbatim).
4. **Status**: correct the stage status if it drifted.
5. **Sync comment** (`save_comment`):

   ```markdown
   ### 🔄 Sync — <YYYY-MM-DD HH:mm>
   **Stage**: <status>
   **已完成**: <bullets, concrete>
   **下一步**: <bullets — written for a cold-start reader with zero session context>
   **Blockers**: <or "無">
   **Branch**: `<branch>` @ `<short-sha>`（pushed ✓）
   **Session**: `<session_id>`<（name: xxx）>
   **Resume**: `cd <worktree-abs-path> && claude --resume <session_id>`
   ```

The "下一步" section is the handoff contract: the next session (possibly a different model) must
be able to act on it without re-doing archaeology.

## /issue-ship

1. **Verify**: run the relevant verification (test suite, `verify` skill, BDD plan). Do not ship
   on stale results — re-run after the last code change.
2. **Commit + push** everything, including `artifacts/current/` planning docs (commit them on the
   branch; git history preserves them even if untracked later pre-merge).
3. **Understanding check**: run the `do-i-understand` skill on the slice diff — interview the
   human, put the resulting Author's understanding block into the PR description, and carry the
   `⚠ Not yet accounted for` regions into the ship comment's review-focus list (they are the
   抽查 targets for the Slice PR gate). Skip when the slice is trivial (docs, config,
   one-liners) or only touches patterns the human has already attested to — but say the check
   was skipped and why. Never skip when the diff contains concepts new to the human, or touches
   auth / money / migrations / concurrency.
4. **PR**: open via the `pull-request` skill.
5. **Linear**: attach the PR URL to the issue (`save_issue` `links`), move status to
   `Human Code Review`, and post a ship comment: verification evidence (test counts, what was
   run), PR link, anything the human reviewer should focus on, plus session/resume info as in
   sync. When the human signs off, move to `Ready for Merge`.
6. Tell the user what is now waiting on them (review + merge).

## /issue-close <DONG-XX>

Only after the PR is actually merged (check with `gh pr view`):

1. Remove the worktree + delete the branch via the `git-worktree` skill (verify no unpushed /
   untracked valuables first — check `git status` and gitignored `artifacts/`, `results/` dirs).
2. Move status to `Merge & Deployed`. Final comment: merge commit, what shipped, follow-up issues
   spawned (link them).
3. **Unblock sweep**: fetch this issue's relations (`get_issue` with `includeRelations: true`).
   For every issue this one was blocking and which now has no other open blockers, post a short
   「🔓 已解鎖（blocker DONG-XX 完成）」comment there, and re-evaluate its status and
   `🙋 human-action` label — an unblocked issue whose first pending item is human's gets the
   label now, not at some future sync.

## General rules

- **Issue checklists are split into two sections**: `## 🧑 Human todo`（決策、review、作答、
  key/憑證提供——只有人能做的）and `## 🤖 Agent todo`（其餘一切）. Every new issue gets both
  sections; when scope changes, re-sort items accordingly. If the human section is empty, say so
  explicitly（「無——全部可交給 agent」）so the user knows at a glance.
- **`🙋 human-action` label = ball in the human's court** (workspace label, works in both teams).
  Semantics: the issue has a Human-todo item that is actionable NOW and progress waits on it（不是
  「總有一天要 review」而是「現在輪到你」）. This is the board's「你有事要做」signal — keep it
  truthful, never decorative. **Re-evaluate the label at every one of these touchpoints**:
  1. **Issue creation** — if the first actionable item is human's (e.g., a decision), add it at birth.
  2. **Every status/stage move** — moving a stage forward often flips whose turn it is
     (e.g., entering `Human Code Review` → add; human decision unblocks `Implementation` → remove).
  3. **Stage completion / agent work exhausted** — when the agent finishes everything it can do
     without the human, add the label as part of the same update.
  4. **/issue-start, /issue-sync, /issue-ship, /issue-close** — each verb ends by checking the
     label matches reality.
  5. **Human action completed** — the moment the human's reply/review/answer is processed
     (e.g., addressing their comment, receiving their decision), remove the label in the same
     turn, and check their corresponding `## 🧑 Human todo` checkbox.
- One issue = one worktree = one PR (matches the slice contract in CLAUDE.md).
- Substantive work with no Linear issue → create the issue first (`save_issue`), then
  `/issue-start` it. Trivial fixes (typos, one-liners) are exempt.
- **Dependencies are declared as Linear relations at creation time, never as prose alone**:
  hard prerequisites（沒完成就不能動工）→ `blockedBy`; informational coupling → `relatedTo`.
  Prose in the description is only for soft sequencing preferences（「建議等 X 之後」）— if
  violating the order would break or waste work, it must be a `blockedBy` relation so the
  /issue-start blocker check and the board's 🚫 marker can enforce it. When scope changes add a
  new prerequisite, add the relation in the same update.
- Issue descriptions carry durable state (context, checklist, worktree path); comments carry the
  timeline (sessions, syncs, decisions). Don't bury decisions in comment threads — fold accepted
  decisions back into the description.
- **Write descriptions durable, not precise** — they outlive sessions. State behavioral
  contracts, interfaces/types, independently verifiable acceptance criteria, and explicit
  out-of-scope; avoid file paths, line numbers, and code snippets, which go stale between
  sessions. Precision lives in `artifacts/current/implementation.md` (a short-lived execution
  contract, where explicit paths are correct); durability lives in the issue. On /issue-start,
  before executing against an existing implementation.md, verify its referenced paths still
  exist.
- When a user comment on an issue changes scope or direction, reply in-thread AND update the
  description / spawn issues so the decision is durable.
