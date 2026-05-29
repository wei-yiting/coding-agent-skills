---
name: address-pr-comments
description: |
  Fetch GitHub PR review comments, triage them, address each with code changes, validate, commit, and push.
  Use this skill whenever the user wants to address PR review comments, handle reviewer feedback, fix things
  reviewers flagged, respond to PR threads, or process any GitHub pull request review feedback.
  Trigger on phrases like: "address PR comments", "fix the review feedback", "handle PR review",
  "處理 PR comment", "回覆 review", "看一下 review 的意見", "PR 被 comment 了", "address review".
  Also use when the user pastes a PR URL and asks to address or fix something from it.
argument-hint: "[pr-number or pr-url] (omit to auto-detect from current branch)"
---

# Address PR Review Comments

This skill processes GitHub PR review comments end-to-end: fetch → triage → confirm with user → apply code changes → validate → commit → push.

The guiding principle is **conservative, reviewer-respecting changes**: only change what the reviewer asked for, always validate before committing, and never post replies or push without the user's awareness.

## Step 1 — Resolve the PR

Determine the PR number from the argument or the current branch:

```bash
# If $ARGUMENTS looks like a URL, extract the PR number from it.
# If $ARGUMENTS is a number, use it directly.
# Otherwise, detect from the current branch:
gh pr view --json number,url,headRefName --jq '{number, url, headRefName}'
```

If no PR is associated with the current branch, stop and tell the user. Also confirm the local branch matches the PR's head branch — addressing comments on the wrong branch creates confusion.

## Step 2 — Fetch and structure comments

Fetch all review feedback. The GitHub API has three separate endpoints because comments live in different places:

```bash
# Inline code comments (the most common — reviewer clicked a line and commented)
gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate

# Review-level bodies (the summary the reviewer writes when submitting a review)
gh api repos/{owner}/{repo}/pulls/{number}/reviews --paginate

# Issue-level comments (conversation below the PR description, not attached to code)
gh api repos/{owner}/{repo}/issues/{number}/comments --paginate
```

Resolve `{owner}/{repo}` dynamically:

```bash
gh repo view --json nameWithOwner --jq '.nameWithOwner'
```

Run all fetches in parallel. Then structure the results:

1. **Inline comments**: group by `path` (file) and thread (`in_reply_to_id`). A thread is a conversation — read the full chain to understand context, not just the latest reply.
2. **Review bodies**: these often contain a summary of all the reviewer's concerns. Cross-reference with inline comments to avoid double-counting.
3. **Issue comments**: usually higher-level discussion. May contain action items or just conversation.

**Filter out noise**: skip comments authored by the PR creator (these are usually responses to reviewers, not action items) unless they contain explicit TODOs like "I'll fix this" or "TODO". Also skip bot comments (CI, linters, dependabot).

If no actionable comments are found, tell the user and stop.

## Step 3 — Triage and present to user

Classify each comment and present a numbered summary. This step exists because misinterpreting a reviewer's intent wastes time — a 30-second confirmation from the user prevents wrong-direction work.

For each comment, determine:

| Classification | What it means | Action |
|----------------|---------------|--------|
| **Code change** | Reviewer wants something in the code to change | Read file, make the fix |
| **Nit / style** | Minor formatting, naming, or style suggestion | Quick fix, same as above |
| **Question** | Reviewer is asking for clarification, not a code change | Draft a reply (Step 7) |
| **Already resolved** | The thread was resolved on GitHub, or a later commit already addressed it | Skip |
| **Unclear** | You can't confidently determine what the reviewer wants | Flag for user clarification |

Present the triage as a numbered list:

```
1. [Code change] `markdown_cleaner.py:175` — Reviewer asks to remove the frontmatter requirement from _strip_cover_page
2. [Nit] `test_markdown_cleaner.py:42` — Rename _wrap_with_frontmatter to _with_frontmatter
3. [Question] PR conversation — Reviewer asks why we chose 100-char threshold for stub detection
4. [Already resolved] `pipeline.py:89` — Thread was resolved by reviewer
```

Wait for the user to confirm or adjust the plan before proceeding. They might reclassify items, deprioritize some, or add context you're missing.

## Step 4 — Apply changes

Work through actionable items (code change + nit) grouped by file, so you read each file once and make all related changes together.

For each file:

1. **Read the file** — not just the commented line, but enough surrounding context to understand the function, class, or module. Reviewer comments often reference behavior that spans multiple lines. Understanding the context prevents changes that fix the commented line but break something nearby.
2. **Read the full comment thread** — later replies in a thread may refine, retract, or redirect the original comment. The last message in the thread is often the most accurate description of what the reviewer wants.
3. **Make the change** — apply exactly what the reviewer asked for. If the reviewer said "rename X to Y", rename X to Y. Don't also refactor the function, add type hints, or reorganize imports while you're there. Scope creep in review responses creates new review cycles.
4. **Spot-check** — verify no syntax errors or broken imports in the modified file.

If a comment is on code that has been deleted or substantially rewritten since the review, flag it to the user rather than guessing where the comment applies now.

## Step 5 — Validate

Run the project's lint and test suite on all modified files. This catches regressions before the reviewer sees them — pushing code that fails CI after a review round erodes trust.

Detect the project's tooling from config files:

- Python: `ruff check` / `pytest` (look for `pyproject.toml`, `ruff.toml`)
- Node/TS: `eslint` / `vitest` or `jest` (look for `package.json`)
- Go: `golangci-lint` / `go test`
- Fall back to whatever the project's CI runs

If validation fails, fix the issue before proceeding. If the fix is non-trivial or unrelated to the PR comments, tell the user.

## Step 6 — Commit and push

Stage only the files changed to address review comments. Use conventional commit format:

```
fix(<scope>): address PR review — <concise summary>
```

The scope should match the area of the codebase (e.g., `sec-pipeline`, `auth`, `api`). The summary should describe the substance of the changes, not just "address comments". Good: `address PR review — remove frontmatter requirement, trim docs`. Bad: `address PR review comments`.

The commit body should list key changes as bullet points tied to what the reviewer asked for. Do not reference GitHub comment IDs or URLs in the commit message — they're meaningless outside the PR UI.

Push with regular `git push`. If the push is rejected due to upstream changes, pull and rebase first, then re-run validation before pushing.

## Step 7 — Handle non-code comments

For any **question** or **unclear** items from Step 3, draft reply text and present it to the user. Never post replies to GitHub automatically — the user should review and approve every outgoing message, because tone and context in PR conversations matter and you may be missing political or interpersonal nuance.

Present each draft reply with the original comment for context:

```
Comment: "Why 100 chars for the stub threshold?"
Draft reply: "The 100-char threshold was calibrated against 29 10-K filings..."
```

The user can edit, approve, or skip each reply.
