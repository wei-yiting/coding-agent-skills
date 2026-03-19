---
name: pull-request
description: |
  How to create, update, and manage Pull Requests with a standardized description format.
  Use this skill whenever the user asks to: create a PR, open a PR, publish a PR, send a PR,
  update a PR description, edit PR body, or any task involving `gh pr create` or `gh pr edit`.
  Also trigger when the user says "發 PR", "開 PR", "送 PR", or mentions pull request in any form.
---

# Pull Request

A good PR description is a **narrative for the reviewer** — it explains the story of why this change exists, how it was approached, and what specifically changed. The reviewer should understand the design intent without reading the diff. The diff confirms correctness; the description provides meaning.

## Gathering Context

Before writing anything, understand the full scope. Run these in parallel:

```bash
git branch --show-current
git status
git log <base>...HEAD --oneline        # Every commit on this branch
git diff <base>...HEAD --stat          # File-level change summary
git diff <base>...HEAD                 # Full diff for architectural understanding
gh pr list --state all --limit 5 --json number,title,body  # Previous PR style
```

The base branch is usually `main` — confirm by checking the repo convention.

**Why read the full diff, not just `--stat`?** The stat tells you which files changed; the full diff reveals _how_ they changed — design patterns, naming conventions, the relationship between changes across files. You need this to write a meaningful Solution section.

**Why check previous PRs?** Every repo has its own voice. Some use bullet points, some use prose. Some include screenshots, some don't. Match the existing convention rather than imposing a new one. The format below is the **default** — adapt if the repo has an established style.

**Why read ALL commits?** A PR represents all work since the branch diverged, not just the latest commit. A branch might have 5 commits: initial implementation, bug fix, code review response, test additions, lint fix. The PR description synthesizes all of these into a coherent story — it doesn't enumerate commits.

## PR Title

Conventional commit style. Imperative mood.

```
<type>: <concise summary>
```

| Type       | When                                   |
| ---------- | -------------------------------------- |
| `feat`     | New feature or capability              |
| `fix`      | Bug fix                                |
| `refactor` | Code restructuring, no behavior change |
| `chore`    | Dependencies, configs, tooling         |
| `docs`     | Documentation only                     |
| `test`     | Test additions or fixes                |
| `perf`     | Performance improvement                |

**Example 1:** `feat: v1 single orchestrator agent architecture`
**Example 2:** `refactor: migrate observability from LangSmith to Langfuse`

## PR Description Structure

Four sections: **Purpose**, **Solution**, **Key Changes**, **Validation**.

Scale the depth to the PR's complexity — a one-file config fix doesn't need the same treatment as a multi-module architecture change. But the four sections always apply, even if some are one-liners.

### Purpose — Why does this PR exist?

This is the most important section. Answer the question a reviewer would ask: "Why are we doing this?"

Don't describe what changed — that's what the diff is for. Describe the **motivation**: the problem, the business need, the strategic reason. If migrating from technology A to B, explain why B was chosen over A. If fixing a bug, describe the user-facing symptom, not the code-level root cause (that goes in Solution).

**Bad:** "Replace LangSmith with Langfuse for observability."
→ This just restates the title. The reviewer still doesn't know _why_.

**Good:** "Replace LangSmith with Langfuse as the observability backend. The RAG pipeline is planned to use LlamaIndex, while the agent layer runs on LangChain/LangGraph. LangSmith only supports the LangChain ecosystem. Langfuse provides first-class integrations for both, making it the right choice for a unified observability layer."
→ Now the reviewer understands the strategic reasoning.

### Solution — How was it solved?

Describe the **architectural approach**, not the line-by-line diff. A reader should understand your design after reading this section, before they ever open a file.

For non-trivial PRs, include a "Key architectural decisions" list. Each entry names a decision, states what was chosen, and explains why. This is where you justify design tradeoffs.

When the architecture or flow is complex, include a Mermaid diagram to help reviewers visualize the design — a sequence diagram for request flows, a graph for module relationships, etc. Diagrams are especially valuable when the PR introduces new layers, changes data flow direction, or reorganizes module boundaries.

**Example (architectural decisions):**

```
Key architectural decisions:
- **CallbackHandler per request**: Injected in run()/arun() via _build_langfuse_config() — one handler per invocation, no shared mutable state
- **Decorator stacking**: @tool (outer) → @observe (inner) preserves LangChain tool schema while adding Langfuse tracing
```

For simple PRs (typo fix, dependency bump), a single sentence suffices — don't force architectural decisions where there aren't any.

### Key Changes — What specifically changed?

Group by **module/area**, not by commit. Reviewers navigate by file path, not by git history.

Use module path in subheaders so reviewers can jump to the relevant directory.

**Example:**

```markdown
### Orchestrator (`backend/agent_engine/agents/base.py`)
- Added _build_langfuse_config() for per-request CallbackHandler construction
- run() and arun() now wrap invoke with propagate_attributes() context manager

### Tools (`backend/agent_engine/tools/`)
- Replaced @trace_step() with @observe() on all 4 tool functions
```

Include **Deleted**, **New Files**, and **Dependencies** subsections when applicable — these are easy to miss in a diff but critical for reviewers to notice.

Include a **Tests** subsection describing what test coverage changed. This section should almost always exist unless the PR is a trivial one-liner. Describe in prose:
- What the new test cases verify
- What existing test cases were modified, and why
- What test cases were removed, and why (e.g., the code they tested was deleted)

### Validation — What evidence supports this PR?

List every verification actually performed. Include the specific commands and their outcomes. Honesty matters — don't list "Tests: all passed" if you didn't run them.

**Example:**

```markdown
## Validation
- **Linter**: `ruff check backend/` — all checks passed
- **Type checker**: `pyright backend/` — 0 errors
- **Tests**: `pytest backend/tests/` — 51 passed
```

## Creating the PR

```bash
# Push branch if not yet pushed
git push -u origin <branch-name>

# Create PR with HEREDOC body for proper formatting
gh pr create --base main --head <branch-name> \
  --title "<type>: <summary>" \
  --body "$(cat <<'EOF'
## Purpose
...

## Solution
...

## Key Changes
...

## Validation
...
EOF
)"
```

After creation, report the PR URL to the user.

## Updating a PR Description

Do not use `gh pr edit --body` or `--body-file` — they are unreliable due to a GraphQL deprecation issue and can silently fail. Use the GitHub REST API instead:

```bash
# 1. Write the new description to /tmp/pr-body.md (use Write tool)

# 2. Convert to JSON and update via REST API
jq -n --rawfile body /tmp/pr-body.md '{"body": $body}' > /tmp/pr-body.json
gh api repos/<owner>/<repo>/pulls/<number> \
  --method PATCH \
  --input /tmp/pr-body.json \
  --jq '.body' | head -3

# 3. Verify the update took effect
gh pr view <number> --json body --jq '.body' | head -5
```
