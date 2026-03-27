---
name: git-worktree
description: "Git worktree lifecycle manager for isolated development. MUST use this skill whenever users mention worktrees, isolated branches, feature isolation, or parallel development. Also invoke it proactively after complex plans (3+ files, refactors, architecture changes) or whenever risky/experimental work should be isolated. This skill handles detection, proposal, confirmation, creation, working-in-worktree guidance, and cleanup via the bundled scripts/manage_worktree.sh workflow."
---

# Git Worktree Lifecycle Manager

Use this skill to manage isolated branches through the bundled script. Prefer repeatable script commands over ad-hoc `git worktree` sequences so behavior stays consistent across agents.

## Why this skill exists

Use worktrees when a task is risky, broad, or long-running. They isolate file changes in a separate directory while keeping shared git history, so the main workspace stays stable.

Use this skill to:
- reduce accidental cross-task edits,
- run experiments without polluting the main tree,
- keep multiple branches active in parallel.

## Bundled script location and invocation

- Script path inside this skill: `scripts/manage_worktree.sh`
- Skill runtime provides a header with the base directory for this skill.
- Build the executable path by prepending that runtime base directory to `scripts/manage_worktree.sh`.

Use this notation in all commands:

```bash
<skill-base-dir>/scripts/manage_worktree.sh <command> [options]
```

Concrete construction example:

```text
Skill header says base directory: /Users/alex/.claude/skills/git-worktree/
Constructed script path: /Users/alex/.claude/skills/git-worktree/scripts/manage_worktree.sh
```

## Activation guidance

1. **User asks for worktree/isolation** → activate this skill.
2. **Agent judges isolation is helpful** → recommend it for complex or risky tasks (for example: 3+ files, refactor, migration, high-blast-radius edits), while respecting the skip guidance below.

## When not to use worktrees

Skip worktree setup when overhead is likely higher than benefit:

- single-file micro change (typo, tiny config tweak),
- task likely under ~5 minutes,
- user is already on a clean feature branch that isolates the work,
- low-risk and easily reversible edits.

Reason: setup, dependency install, and environment duplication cost time. Reserve isolation for tasks that materially benefit from it.

## Worktree naming convention

Always propose names following this pattern:

| Task Type | Branch Name Pattern | Example |
|-----------|-------------------|---------|
| New feature | `feature/<short-description>` | `feature/add-auth-api` |
| Bug fix | `bugfix/<issue-or-description>` | `bugfix/fix-rag-timeout` |
| Refactoring | `refactor/<scope>` | `refactor/retriever-strategy` |
| Documentation | `docs/<scope>` | `docs/api-reference` |
| Experiment | `experiment/<description>` | `experiment/new-embedding-model` |

Naming rules:
- Use lowercase with hyphens
- Keep suffix concise (usually 2-4 words)
- Derive from task intent, not internal ticket noise

## Lifecycle workflow (Propose → Confirm → Create → Work → Finish)

### Phase 0 — Detect (applies to ALL phases)

Detect context before any worktree operation — create, finish, or remove. This avoids broken commands and wrong assumptions.

1. Check whether current directory is already a linked worktree.
   - Inspect `.git`: if it is a **file** (not directory), you are inside a linked worktree. This matters because finish/remove commands need the branch name of the current worktree, and the script must be invoked with the correct PROJECT_ROOT context.
2. Check existing worktrees in this repository.
   - Run `list` and read paths/branches to identify the target worktree.
3. For create operations, determine sensible base branch default.
   - Prefer repository default branch when known (`main` or `master` typically),
   - otherwise use project flow (`dev` or current branch) based on context.

Suggested commands:

```bash
test -f .git && echo "linked-worktree" || echo "main-worktree-or-standard-repo"
<skill-base-dir>/scripts/manage_worktree.sh list
git symbolic-ref refs/remotes/origin/HEAD
```

If already inside a worktree and isolation is still needed, propose either:
- creating another worktree from the main repo context, or
- reusing the current worktree if it already matches the task branch.

### Phase 1 — Propose

Propose only after detection.

1. Choose branch name from the naming table.
2. Choose a base branch using detection output.
3. State why isolation helps *for this task*.
4. Show the exact command you plan to run.

Communication style:
- Be conversational and adapt to user tone.
- Include key info: branch, base, rationale, command.
- Keep rationale brief if user is experienced; add more context if user seems unfamiliar.

### Phase 2 — Confirm

Get explicit confirmation before create/remove operations.

Ask which options to include:
- `--install-deps`
- `--start-docker`
- `--no-env-copy`

Reason: options affect setup time, runtime behavior, and local resources.

### Phase 3 — Create

After confirmation, run one create command:

```bash
<skill-base-dir>/scripts/manage_worktree.sh create <branch> --base <base-branch> [--install-deps] [--start-docker] [--no-env-copy]
```

Then report:
- branch name,
- worktree directory from script output,
- which optional setup steps ran.

### Phase 4 — Work

Tell the user to move into the generated path:

```bash
cd <worktree-path-from-script-output>
```

Working rules inside a worktree:
- Run all tool operations with that worktree path as working directory.
- Use `git` normally inside it (status, add, commit, branch operations).
- Return to main repo context by using the main repository path.
- If `.env*` files changed in main repo, refresh with:

```bash
<skill-base-dir>/scripts/manage_worktree.sh sync-env <branch>
```

Useful maintenance commands:

```bash
<skill-base-dir>/scripts/manage_worktree.sh list
<skill-base-dir>/scripts/manage_worktree.sh sync-env <branch>
```

### Phase 5 — Finish

Run Phase 0 first: detect whether you are inside the worktree being finished (common scenario). If so, note the branch name from context and remember the script resolves the main repo automatically.

When implementation is done, run:

```bash
<skill-base-dir>/scripts/manage_worktree.sh finish <branch> [--switch] [--no-remove]
```

If user asks for explicit cleanup/removal:

```bash
<skill-base-dir>/scripts/manage_worktree.sh remove <branch> [--force]
```

Report:
- worktree removed or kept,
- whether main tree switched,
- next git step (for example push/PR).

## Error recovery playbook

Use these recoveries before retrying commands.

### 1) Branch already checked out in another worktree

Symptom: create fails because target branch is already checked out elsewhere.

Action:
- run `list` to locate the existing worktree,
- either finish/remove that worktree first,
- or choose a different branch name.

```bash
<skill-base-dir>/scripts/manage_worktree.sh list
<skill-base-dir>/scripts/manage_worktree.sh finish <branch>
```

### 2) Target path already exists

Symptom: script reports worktree path already exists.

Action:
- run `list` and verify whether the worktree already exists,
- if stale, remove/finish it,
- otherwise reuse it intentionally.

```bash
<skill-base-dir>/scripts/manage_worktree.sh list
<skill-base-dir>/scripts/manage_worktree.sh remove <branch>
```

### 3) Uncommitted changes block finish/remove

Symptom: finish/remove refuses because tree is dirty.

Action:
- suggest `commit` or `stash` first,
- only use `remove --force` when user explicitly accepts data-loss risk.

```bash
<skill-base-dir>/scripts/manage_worktree.sh remove <branch> --force
```

### 4) Base branch not found

Symptom: create fails with unknown base branch.

Action:
- verify local/remote branches,
- fetch remotes,
- retry with a valid base.

```bash
git branch --all
git fetch --all --prune
```

### 5) Script missing or not executable

Symptom: command not found / permission denied.

Action:
- verify path from runtime header,
- fix executable bit,
- retry.

```bash
chmod +x <skill-base-dir>/scripts/manage_worktree.sh
```

## Command quick reference (do not reimplement script logic)

```bash
<skill-base-dir>/scripts/manage_worktree.sh create <branch> [--base <branch>] [--install-deps] [--start-docker] [--no-env-copy]
<skill-base-dir>/scripts/manage_worktree.sh finish <branch> [--switch] [--no-remove] [--no-env-sync-back]
<skill-base-dir>/scripts/manage_worktree.sh list
<skill-base-dir>/scripts/manage_worktree.sh remove <branch> [--force] [--no-env-sync-back]
<skill-base-dir>/scripts/manage_worktree.sh sync-env <branch>
```

Script behavior worth remembering:
- `create` defaults `--base` to current branch when omitted,
- `create` copies `.env*` files unless `--no-env-copy` is set,
- `finish` and `remove` sync `.env*` files back to main repo before removal (skip with `--no-env-sync-back`),
- `finish` expects clean worktree state,
- `remove --force` bypasses cleanliness checks.

## Important caveats

1. Ask for explicit consent before using `--force` on remove.
2. Uncommitted changes block normal finish/remove; resolve by commit/stash or forced remove with consent.
3. `.env` files are synced bidirectionally — copied to worktree on create, synced back to main repo on finish/remove. Use `--no-env-sync-back` to skip the reverse sync.
4. Docker services may conflict on host ports when multiple worktrees start the same stack.
5. `node_modules` and `.venv` are separate per worktree by design; isolation improves safety but increases disk/time cost.
6. IDE settings (for example `.vscode` / `.idea`) are per-worktree, which is useful for task-specific configuration.
7. A branch can only be actively checked out in one worktree at a time.

## Example interactions

### Example 1 — User asks directly (short style)

**User**: "Need a worktree for auth callback fix."

**Assistant**:
```text
Good call. Suggest branch `bugfix/auth-callback` from `main`.
I’ll run:
<skill-base-dir>/scripts/manage_worktree.sh create bugfix/auth-callback --base main

Include `--install-deps` or keep setup minimal?
```

### Example 2 — Agent recommends for complex refactor

**Assistant**:
```text
This refactor touches 8 files across parser/retriever/eval. Isolation will reduce rollback risk.
Proposed branch: `refactor/retriever-eval-split`
Base: `dev`
Planned command:
<skill-base-dir>/scripts/manage_worktree.sh create refactor/retriever-eval-split --base dev --install-deps

Confirm and I’ll create it.
```

### Example 3 — Detect that user is already in a worktree

**Assistant**:
```text
You’re already in a linked worktree (`.git` is a file). I can keep working here,
or create a separate one from the main repo if you want stricter isolation.
```

### Example 4 — Finish and switch back to branch in main tree

**User**: "Done. Close the worktree and switch main tree to this branch."

**Assistant action**:
```bash
<skill-base-dir>/scripts/manage_worktree.sh finish feature/api-pagination --switch
```

**Assistant follow-up**:
```text
Finished.
- Removed worktree: yes
- Switched main tree: feature/api-pagination

Next step: push branch and open PR.
```
