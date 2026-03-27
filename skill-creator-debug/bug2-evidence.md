# Bug 2 Evidence: Temp Command File Identity Mismatch

## Test Setup

Ran `run_eval.py` with Bug 2 reverted (temp command file approach) against the `pull-request` skill.
Bugs 3a and 3b were kept fixed to isolate Bug 2's effect.

- Skill: `pull-request`
- Model: `claude-sonnet-4-6`
- 10 queries: 5 should-trigger, 5 should-not-trigger
- 1 run per query

## Key Evidence: Both Skills Visible in Context

During the eval run, Claude Code's system-reminder showed **both the original skill and the temp command file** loaded into context simultaneously:

```
- pull-request: How to create, update, and manage Pull Requests with a standardized description format.
  Use this skill whenever the user asks to: create a PR, open a PR, publish a PR, send a PR,
  update a PR description, edit PR body, or any task involving `gh pr create` or `gh pr edit`.
  Also trigger when the user says "發 PR", "開 PR", "送 PR", or mentions pull request in any form.

- pull-request-skill-2f13f743: How to create, update, and manage Pull Requests with a standardized description format.
  Use this skill whenever the user asks to: create a PR, open a PR, publish a PR, send a PR,
  update a PR description, edit PR body, or any task involving `gh pr create` or `gh pr edit`.
  Also trigger when the user says "發 PR", "開 PR", "送 PR", or mentions pull request in any form.
```

Both descriptions are **identical**. The only difference is the name:
- `pull-request` (original skill from `.claude/skills/`)
- `pull-request-skill-2f13f743` (temp command file from `.claude/commands/`)

## Agent Behavior Log: Single Query Trace

To confirm what Claude actually does at runtime, we ran a manual `claude -p` with the temp command
file present and captured the full stream output. Query: `"create a PR for this feature branch"`.

**Available skills in context (from system-reminder):**

```
- pull-request: How to create, update, and manage Pull Requests...
- pull-request-skill-test1234: How to create, update, and manage Pull Requests...
```

Both skills visible, identical descriptions, different names.

**Claude's actions (in order):**

```
[assistant] Thinking: The user wants to create a PR for the current feature branch.
            Let me invoke the pull-request skill first as instructed....

[assistant] Tool: Skill
  Input: {"skill": "pull-request"}          ← picked "pull-request", NOT "pull-request-skill-test1234"

[assistant] Tool: Bash
  Input: {"command": "git branch --show-current"}

[assistant] Tool: Bash
  Input: {"command": "gh pr list --state all --limit 5 --json number,title,body"}

[assistant] Tool: Bash
  Input: {"command": "git status && git log --oneline -10"}

[assistant] Tool: Bash
  Input: {"command": "git log origin/main...HEAD --oneline"}

[assistant] Tool: Bash
  Input: {"command": "git diff origin/main...HEAD --stat"}

[assistant] Tool: Bash
  Input: {"command": "git diff origin/main...HEAD"}

[assistant] Tool: Read  (reading diff output, multiple chunks)

[assistant] Tool: Bash
  Input: {"command": "git remote -v && git branch -a"}

[assistant] Text: 目前在 main 分支上，比 origin/main 超前 4 個 commit...
```

Claude invoked `Skill` with `{"skill": "pull-request"}` — the original skill name. The temp command
file `pull-request-skill-test1234` was visible in context but never selected. The eval's detection
logic would check for `pull-request-skill-test1234` in the tool input and find no match → `return False`.

## Eval Result: Recall = 0%

```
Results: 5/10 passed
  [FAIL] rate=0/1 expected=True: open a pull request with all the changes we just made
  [FAIL] rate=0/1 expected=True: 發 PR 到 main branch
  [FAIL] rate=0/1 expected=True: create a PR for this feature branch
  [FAIL] rate=0/1 expected=True: I need to send a PR for review, can you help me set it up?
  [FAIL] rate=0/1 expected=True: help me write a good PR description for these changes
  [PASS] rate=0/1 expected=False: commit these changes with a good message
  [PASS] rate=0/1 expected=False: review the code in src/auth.ts and suggest improvements
  [PASS] rate=0/1 expected=False: run the test suite and fix any failures
  [PASS] rate=0/1 expected=False: deploy this to production
  [PASS] rate=0/1 expected=False: refactor this function to be more readable
```

- **5/5 should-trigger queries**: all `trigger_rate: 0.0` (FAIL)
- **5/5 should-not-trigger queries**: all `trigger_rate: 0.0` (PASS — correctly not triggered)
- **Recall: 0%**, Precision: N/A (no true positives)

## Root Cause

The old `run_single_query()` created a temp file at `.claude/commands/pull-request-skill-{uuid}.md`
while the real skill at `.claude/skills/pull-request/SKILL.md` remained present. Both `.claude/commands/`
and `.claude/skills/` are [functionally equivalent](https://docs.anthropic.com/en/docs/claude-code/slash-commands)
— Claude Code loads descriptions from both into context via
[progressive disclosure](https://docs.anthropic.com/en/docs/claude-code/slash-commands) (name + description
only, no body visible at decision time).

Claude consistently chose `pull-request` over `pull-request-skill-{uuid}` — likely because the
auto-generated UUID name looks like a test artifact. The detection logic then checked for the temp
file's name in the Skill tool input and found no match.

## Fix

Replace the temp command file approach with in-place SKILL.md description swapping:
1. Before eval: overwrite the real skill's description in SKILL.md with the test description
2. Run queries: only one skill exists, Claude invokes it by its real name
3. After eval: restore the original SKILL.md content (via try/finally)

This eliminates the identity mismatch entirely — the skill name Claude invokes is the same name
the eval checks for.

## Reproduction

```bash
# Run eval with Bug 2 reverted (temp command file approach):
cd skill-creator
python3 -m scripts.run_eval_bug3_test \
  --eval-set ../pull-request-workspace/trigger-eval.json \
  --skill-path ../pull-request \
  --num-workers 3 \
  --timeout 60 \
  --runs-per-query 1 \
  --model claude-sonnet-4-6 \
  --verbose
```

Test run date: 2026-03-21.
