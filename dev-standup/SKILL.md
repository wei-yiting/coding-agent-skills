---
name: dev-standup
description: >-
  Interactive "where was I" briefing at session start: pulls in-flight Linear issues, scans git
  worktrees, then delivers a prioritized, descriptive briefing as an interactive HTML dashboard
  (dependency graph, human-vs-agent action queues, per-issue narrative cards, text-selection
  comments) plus an optional spoken briefing with voice Q&A. Two modes: all-issues standup, or a
  deep-dive on one issue/worktree. Use when the user asks where things stand, what to work on,
  says "standup", asks to be briefed on a specific issue or worktree ("brief me on DONG-63",
  "幫我 standup", "語音跟我報告"), or returns to a project after time away — instead of
  re-deriving state from git archaeology.
---

# Dev Standup

Rebuild "where was I" from the two sources of truth: Linear (intent + progress) and git
remotes (code). Never answer from memory of prior sessions — always re-read live state.

The deliverable is a **briefing, not a status dump**. Linear already stores statuses and
comments; the value this skill adds is synthesis: cross-checking Linear against git reality,
drawing the dependency picture, splitting next moves into human vs agent, and ranking what
actually matters today. If the output reads like Linear-as-text, it has failed — see the
writing rules in `references/report-guide.md`.

## Modes

- **Full standup** (default): all in-flight issues + all worktrees → dashboard + briefing.
- **Focused** (`/dev-standup DONG-63`, a worktree name, or "brief me on X"): one issue or
  worktree, at greater depth — full issue history, diff summary vs main, artifacts on disk,
  PR state, its dependency neighborhood. Same pipeline, different section skeleton
  (see report-guide.md).

## Step 1 — Gather (parallelize what's independent)

Load Linear tools if deferred (one ToolSearch call):
`select:mcp__claude_ai_Linear__list_issues,mcp__claude_ai_Linear__list_comments,mcp__claude_ai_Linear__get_issue`

1. **Linear issues** — `list_issues` for the relevant projects (default: `FinLab-X` and
   `Interview Preparation`), all non-completed. For issues in started states,
   `list_comments` and extract the **latest `🔄 Sync` / `▶️ Session start` comment** (last
   progress, next steps, `claude --resume` command). Content-profile issues (`PREP-XX`)
   have no worktree — their risk check is "does the latest sync flag local-only material?"
2. **Dependencies** — `list_issues` truncates descriptions and hides relations, and the
   dependency graph is a core deliverable: call `get_issue` for every in-flight issue and
   collect blocker edges from both formal relations and description markers（`⛔ Blocked
   by`、`前置條件`）. In focused mode also pull the full comment thread.
3. **Worktree scan** — run from the worktree container directory (default
   `~/Documents/dev-projects/fin-lab-x-wt`, main repo at `../fin-lab-x`); adapt per project:

```bash
cd ~/Documents/dev-projects/fin-lab-x-wt
for d in */; do
  d=${d%/}
  git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || { echo "$d | NOT-A-GIT-DIR"; continue; }
  branch=$(git -C "$d" branch --show-current)
  dirty=$(git -C "$d" status --porcelain | wc -l | tr -d ' ')
  if git -C "$d" rev-parse --abbrev-ref @{u} >/dev/null 2>&1; then
    unpushed=$(git -C "$d" rev-list @{u}..HEAD --count)
  else
    unpushed="NO-UPSTREAM($(git -C "$d" rev-list main..HEAD --count 2>/dev/null || echo '?'))"
  fi
  ignored=$(git -C "$d" status --porcelain --ignored=matching -- artifacts .artifacts backend/evals/results 2>/dev/null | grep -c '^!!' || true)
  last=$(git -C "$d" log -1 --format='%cr')
  echo "$d | $branch | dirty:$dirty | unpushed:$unpushed | ignored-artifacts:$ignored | last:$last"
done
```

4. **PR state** — `gh pr list --state open` in the main repo (and `gh pr view` for issues
   whose sync comments mention a PR), so cards can say "PR #15 open, no review yet" instead
   of guessing.
5. **Previous snapshot** — read the newest `standup/state/*.json` (if any) for the Δ
   section. Schema in report-guide.md.

In focused mode add: `git -C <worktree> diff main --stat | tail -5`, recent `git log
--oneline -10`, and a listing of `artifacts/current/` in that worktree.

## Step 2 — Synthesize & prioritize

For every issue, cross-reference Linear intent with git reality and decide **whose ball is
next** — human (decision / review / credential / approval) or agent (everything already
unblocked and mechanical). Discrepancies between the two sources are findings, not noise: a
worktree with work but no matching Linear issue (or vice versa) gets flagged so the
tracking gap is closed.

Rank 今日焦點 by, in order:

1. **資料安全** — anything violating no-lone-copies (NO-UPSTREAM, unpushed, dirty trees
   holding verified work) outranks features: it's the only category where waiting loses work.
2. **決策槓桿** — the human decision blocking the most downstream work.
3. **收割** — verified work one mechanical step from safe/merged (commit → push → PR).
4. **明示優先級** — Urgent/P0 labels from Linear.
5. **腐化風險** — branches drifting from main the longest.

## Step 3 — Deliver: chat TL;DR + HTML dashboard

In chat: 3–5 sentence TL;DR (top focus, biggest risk, what's waiting on the user) + the
report path. **Do not reproduce the whole report in chat.**

Then generate the HTML from `assets/template.html` following
`references/report-guide.md` exactly (section skeleton, HTML patterns, placeholder map,
assembly mechanics — the template is ~2900 lines, never Read it whole):

- Output: `<container>/standup/<YYYY-MM-DD>.html`（focused:
  `<container>/standup/<YYYY-MM-DD>-<slug>.html`）; create the directory if needed.
  Comments persist in the sidecar `<basename>.comments.json` next to it.
- Save the machine-readable snapshot to `standup/state/<YYYY-MM-DD>.json` for next time's Δ.
- `open` the HTML, and tell the user (once, briefly) they can select text → comment, and
  say「comment 完了」when done.

This skill reports and briefs; it does **not** start fixing anything uninvited. The user
picks; explicit instructions inside comments or Q&A are picks.

## Step 4 — Voice briefing (optional, ask once)

Check availability first: ToolSearch for `mcp__voicemode__converse`. If unavailable, skip
this step **silently** — no question, no apology. If available, ask once (AskUserQuestion,
one question):要不要語音 briefing？

When on, the spoken layer complements the HTML on screen — it's a standup narration, not
the page read aloud:

- **Spoken language = English（voice `af_sky`）, text stays 台灣繁中.** The user only
  accepts Taiwan-accented Mandarin, and the local Kokoro TTS's zh voices（`zf_*`/`zm_*`）
  are all mainland-accented — verified 2026-07-07 and rejected. Don't re-offer Chinese
  speech unless the TTS setup gains a zh-TW voice; re-check only when the voice list
  changes（`curl http://127.0.0.1:8880/v1/audio/voices`）.
- **Script** (~60–120 秒): one-sentence opener on overall state → 今日焦點 top 3 with the
  *why* → what's waiting on the user → close with an invitation for questions. Speak in
  short sentences; split long runs into 2–3 `converse` calls rather than one monologue.
  Say issue ids as words（"DONG sixty-four"）— digits in ids TTS poorly.
- **Q&A loop**: each `converse` call speaks and then listens (the transcript comes back as
  the user's question). Use `listen_duration_max: 120`, `listen_duration_min: 5` —
  standup questions are shorter than interview answers. Answer from gathered data; if a
  question needs data you don't have, say so, fetch it, then speak the answer. Exit when
  the user indicates they're done（「沒問題了」「開始工作吧」etc.）.
- **Truncated transcripts**: if a question cuts off mid-thought, don't guess — speak
  「不好意思，你剛說到一半？」and stitch the transcripts.
- **Degrade gracefully**: if `converse` errors, say so in chat. If the voicemode MCP is
  down but the local Kokoro server is up, the briefing (speak-only) can still be delivered
  directly — `curl http://127.0.0.1:8880/v1/audio/speech` per chunk + `afplay`; Q&A then
  happens by text. Only fall fully silent when both are unreachable.

## Step 5 — Comment loop

When the user says they've commented (or pastes exported JSON): read the sidecar
`<basename>.comments.json`（fall back to pasted JSON）and process each active comment,
anchored to its section/issue:

- **Question** → answer in chat, citing the underlying data.
- **Instruction**（「這個先做」「開工」）→ that's the user picking work: act on it, or if
  it's a whole work item, hand off per the `linear-flow` issue-start procedure.
- **Decision** that belongs on a Linear issue（e.g. answering a decision point an issue is
  waiting on）→ offer to write it back to that issue as a comment so Linear stays the
  source of truth.

Summarize what was done per comment so the user can `✓ Resolve` them in the page.
