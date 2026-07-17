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

### Gathering Validation Artifacts

If `artifacts/current/` exists, read the following files to inform the Validation and User Acceptance Test sections:

- `bdd-scenarios.md` — feature and journey scenario titles
- `verification-plan.md` — automated/manual verification methods and UAT steps
- `bdd-verification-report.md` — actual verification results
- `code-review-improvement-report.md` — code review summary

**Important:** `artifacts/` is git-ignored and will not be included in the PR. Do NOT reference artifact file paths in the PR description — instead, extract the relevant information and inline it directly.

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

Core sections: **Purpose**, **Solution**, **Key Changes**, **Validation**, **User Acceptance Test**.

**Before writing, size up the diff and pick the depth deliberately.** The section list is a menu of questions to answer, not a form to fill — every section must earn its depth from *this* diff. The first four sections always apply, but their weight scales:

- **Small / focused PR** (few files, one concern — config fix, infra tweak, isolated bugfix): Purpose is 1–2 sentences; Solution is a short paragraph with only the non-obvious decisions inlined (skip the "Key decisions" list if there's only one); Key Changes is flat bullets, one per file; Validation is a compact 2-column table (Check / Result).
- **Medium / large PR** (multi-module, new architecture, behavior redesign): full treatment — decisions list, module-grouped Key Changes, 3-column Validation, diagrams where flow is complex.

The self-check while drafting each section: *"would the reviewer of this specific diff need this at this depth, or am I filling in a template?"* If a structure element (subheader, decisions list, UAT) exists only because the format suggests it, drop it.

### Two global rules that apply to every section

**Rule 1: Be concise. The reviewer should skim the whole description in under a minute.**

This is the single most common failure mode — PR descriptions balloon into multi-paragraph essays that bury the signal. Before submitting, re-read the draft as a reviewer:

- **Purpose**: 2–3 sentences. Not 5 paragraphs.
- **Solution**: One short paragraph + a bullet list of key decisions (each bullet = one sentence + a brief why-clause). Not a section-by-section essay covering every architectural choice.
- **Key Changes**: 1–2 bullets per area. Not a function-by-function changelog.
- **Known Limitations / Open Issues**: Optional. Omit the section entirely if the only "limitation" is a tradeoff already implied by the design. Do not invent caveats to fill the section.

If a paragraph could be one sentence, cut it. If a sentence could be three words, cut it. Length is not a proxy for quality — it inversely correlates with reviewer engagement.

**Rule 2: Never reference internal artifact IDs.**

`artifacts/` is git-ignored and never appears in the PR. IDs like `DD-06`, `S-stream-01`, `J-stream-01`, `C08`, `M-1.3`, `m-1.1` are dangling references for any reviewer who only sees the PR. They are also a sign that the PR description is leaking implementation-process detail that does not belong in a reviewer-facing artifact.

This rule applies to **every** section, not just Validation:
- ❌ "Single-worker deployment assumption (DD-06)"
- ✅ "Single-worker deployment is assumed; the in-memory session lock would not extend to multi-worker."
- ❌ "Verified by S-tool-03 and J-stream-01"
- ✅ "Verified by tool error sanitization scenarios and a complete financial-analysis journey"

Before running `gh pr create`, search the draft for `DD-`, `S-`, `J-`, `C0`, `M-`, or any other artifact ID pattern. Replace with prose or delete.

Optional trailing section (at most one, always last): **Known Limitations**, **Open Issues**, or **Future Improvements**. Use when the PR has noteworthy caveats, unresolved items, or planned follow-ups that the reviewer should be aware of. Pick the name that best fits the content:

| Section | When to use |
|---------|-------------|
| Known Limitations | Acknowledged design tradeoffs or constraints that are intentionally accepted in this PR |
| Open Issues | Items discovered during implementation that need resolution but are not blockers for merge |
| Future Improvements | Planned enhancements that are out of scope for this PR but worth documenting for follow-up |

If there is nothing noteworthy, omit the section entirely — do not add an empty one.

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

**Formatting:** Use a clean subheader for the module/area name. List the relevant file paths as a blockquote (`>`) on the first line under the subheader, then bullet points for the changes. Keep file paths out of the subheader itself — subheaders should be human-readable area names.

The subheader + blockquote structure is for PRs spanning **multiple modules/areas**. When the PR touches only a handful of files in one area, skip the structure entirely — a flat bullet list (`` `path` — what and why ``, one line per file) reads faster than three one-bullet subsections.

**Granularity guideline:** Each module gets 1–2 bullet points summarizing _what_ it does and _why_ it exists, not an exhaustive list of every function or method added. The reviewer can see the full details in the diff — the Key Changes section tells them where to look and what to expect, not everything that happened.

**Good format:**
```markdown
### Eval Runner

> `backend/evals/eval_runner.py`

- Convention-based scenario discovery with directory name validation
- Dual path: `_run_local_eval()` (no Braintrust import) and Braintrust `Eval()` path
- Task/scorer wrappers for error isolation, result CSV with original column preservation
```

**Bad format — file paths in subheader:**
```markdown
### Eval Runner (`backend/evals/eval_runner.py`)
- Convention-based scenario discovery with directory name validation
...
```

**Too detailed:**
```markdown
### Eval Runner

> `backend/evals/eval_runner.py`

- Added `discover_scenarios()` that scans `scenarios/` for subdirectories containing `dataset.csv` + `eval_spec.yaml`
- Added `_validate_directory_name()` using regex `^[a-zA-Z0-9_-]+$` to reject spaces
- Added `_check_duplicate_config_names()` to detect `--all` mode duplicate experiment names
- Added `_run_local_eval()` function that executes task and scorers without importing braintrust
- Added `_wrap_task()` that detects None returns and catches exceptions with ERROR markers
- Added `_wrap_scorer()` that isolates failures, filters Braintrust-injected kwargs, aligns Score.name
- ...
```

Include **Dependencies** subsection when packages are added or removed — these are easy to miss in a diff but critical for reviewers to notice.

Include a **Tests** subsection summarizing test coverage scope (module count, test count) and what the tests verify at a high level. One or two lines is sufficient.

### Validation — What evidence supports this PR?

Present validation results as a **table** for quick scanning. The table should cover all verification methods actually performed.

**Standard columns:** Category, Scope, Result.

**Standard categories** (include all that apply):

| Category | What goes in Scope |
|----------|--------------------|
| Linter | Command run (e.g., `ruff check backend/`) |
| Unit Tests | Test count and module coverage summary |
| Automated Behavior Verification | **Features** and **Journeys** as separate HTML bullet lists (`<ul><li>`) with scenario counts |
| Manual Behavior Test | Describe what was verified (not scenario IDs) |
| Code Review | Number of rounds and issues found/fixed |

**Example:**

```markdown
## Validation

| Category | Scope | Result |
|----------|-------|--------|
| Linter | `ruff check backend/` | Passed |
| Unit Tests | 99 tests across 5 modules (dataset loader, scenario config, scorer registry, eval runner, eval tasks) | All passed |
| Automated Behavior Verification | **Features:**<ul><li>Scenario Discovery (8 scenarios)</li><li>CSV Dataset & Column Mapping (10 scenarios)</li><li>Scorer System (9 scenarios)</li><li>Eval Runner CLI (7 scenarios)</li><li>Result CSV Output (5 scenarios)</li><li>Braintrust Integration (4 scenarios)</li></ul>**Journeys:**<ul><li>New user setup error recovery</li><li>CSV-to-eval full pipeline</li><li>Mixed scorer flow</li><li>Single scenario end-to-end</li></ul> | All passed |
| Manual Behavior Test | Default mode dual output (local CSV + Braintrust experiment); LLM-judge LLM calls isolated from task trace | All passed |
| Code Review | 6 rounds of automated review, 14 issues found and fixed | All resolved |
```

**Key rules:**
- Use descriptive content, not IDs or codes (write "LLM-judge trace isolation", not "S-bt-07") — see Rule 2 above
- For Automated Behavior Verification, list **feature titles** and **journey titles** — these tell the reviewer what behaviors were verified
- Never reference `artifacts/` paths — the artifacts are git-ignored and won't be in the PR

### User Acceptance Test — What should the reviewer manually verify?

Include this section when manual verification gives the reviewer something **beyond what the Validation table already shows** — a judgment call only a human can make (UX feel, output quality, workflow ergonomics), or a multi-step flow worth walking through hands-on. This is the reviewer's hands-on checklist.

**Omit it when it would only repeat the Validation table's commands.** If "UAT" would be re-running the same checks the author already ran and tabled, the section is pure duplication — the reviewer can copy commands from Validation if they want to reproduce. The self-check: *"does this UAT ask the reviewer to judge something, or just to re-execute my validation?"* Only the former earns the section.

Structure:
1. **Acceptance question** — what is being validated (framed as a question)
2. **Steps** — concrete, copy-pasteable commands and actions
3. **Checklist** — specific items to verify (use `- [ ]` checkboxes)
4. **Expected result** — what success looks like

**Example:**

```markdown
## User Acceptance Test

> **Prompt iteration workflow with mixed programmatic + LLM-judge scores**
>
> Acceptance question: Can Braintrust's experiment diff effectively support prompt iteration decisions?

**Steps:**
1. Run eval with current prompt:
   ```bash
   uv run python -m backend.evals.eval_runner language_policy
   ```
2. Modify the agent's system prompt
3. Run eval again:
   ```bash
   uv run python -m backend.evals.eval_runner language_policy
   ```
4. Open Braintrust UI → Compare the two experiments

5. Verify:
   - [ ] Each test case shows 3 scorer scores
   - [ ] Per-case regression/improvement is visible in the diff view
   - [ ] Drill-down shows full trace (input → tool calls → output)
   - [ ] The diff information is sufficient to decide whether the prompt change is good or bad

**Expected result:** Clear per-case regression/improvement, trace drill-down provides sufficient debugging context.
```

Source the UAT content from `verification-plan.md` (Manual Verification → User Acceptance Test section) if it exists. Include all UAT scenarios defined there.

## Pre-push Validation (hard gate)

Mandatory before every push that includes a code change, for both new PRs and updates. Do not skip a step because "the default command doesn't include it" or "CI will catch it."

- [ ] Linter
- [ ] Unit tests
- [ ] Integration tests (including any suites deselected by default — e.g. `pytest -m integration`)
- [ ] Any other project suites (type check, build, frontend lint/test, etc.)

Only push after every box is checked. A red linter or failing test is never a valid "pre-existing" excuse — fix the root cause first.

Body-only or comment-only updates (no code change) do not require rerunning this checklist.

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

## User Acceptance Test
...

## Known Limitations / Open Issues / Future Improvements (optional — pick one if needed)
...

---
Linear: DEV-XX
EOF
)"
```

**Linear linking**: when the work corresponds to a Linear issue, the body MUST end with a
trailing `Linear: <ISSUE-ID>` line (as shown above) — Linear's GitHub integration links the PR
to the issue by that mention, and all status automations (PR opened / merged) depend on the
link. It must be present at creation time; adding it after a GitHub event (e.g. post-merge)
does not fire that event's automation. Omit the line only when there is no corresponding issue.

After creation, report the PR URL to the user.

## Updating a PR Description

Do not use `gh pr edit --body` or `--body-file` — they are unreliable due to a GraphQL deprecation issue and can silently fail. Use the GitHub REST API instead:

```bash
# 1. Write the new description to a topic-specific tmp file (use Write tool).
#    Do NOT use a generic name like /tmp/pr-body.md — multiple concurrent PR
#    workflows may collide. Use /tmp/pr-body-<branch-or-topic>.md instead.

# 2. Convert to JSON and update via REST API
jq -n --rawfile body /tmp/pr-body-<topic>.md '{"body": $body}' > /tmp/pr-body-<topic>.json
gh api repos/<owner>/<repo>/pulls/<number> \
  --method PATCH \
  --input /tmp/pr-body-<topic>.json \
  --jq '.body' | head -3

# 3. Verify the update took effect
gh pr view <number> --json body --jq '.body' | head -5
```
