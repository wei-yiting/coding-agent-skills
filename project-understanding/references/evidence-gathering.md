# Evidence Gathering

How to reconstruct the "why" of a repo's development from what it left behind. The history's *shape* is itself evidence — a revert followed by a different approach is a trade-off story sitting in plain sight.

## Survey (no scope given)

Goal: find 3–6 candidate stories. Candidates rank by **decision density** — reverts, multi-iteration subsystems, refactor waves, migrations — not by line count.

```bash
git log --oneline --graph --first-parent -60        # mainline shape
git log --merges --first-parent --format='%h %ad %s' --date=short -40   # PR boundaries
gh pr list --state merged --limit 40 --json number,title,mergedAt,additions,deletions
git log -i --grep='revert\|rollback\|redo\|rewrite' --oneline           # trade-offs in plain sight
git log --format= --name-only | sort | uniq -c | sort -rn | head -20    # hot directories
ls artifacts/ docs/ 2>/dev/null; find . -ipath '*adr*' -name '*.md' 2>/dev/null | head
```

If `gh` fails (no remote / not authenticated), say so once and lean on merge commits + artifacts instead.

## Deep dive (scoped target)

For a **path/module/feature**:

```bash
git log --follow --oneline -- <path>                # full evolution
git log -i --grep='<feature keyword>' --oneline
gh pr list --state merged --search '<keyword>' --json number,title
```

For a **PR**: `gh pr view <N> --json title,body,files,comments,reviews` — the review threads are the densest why-source; read objections and how they were answered.

For a **branch/worktree**: `git worktree list`, then `git log main..<branch> --oneline` and `git diff main...<branch> --stat` — an unmerged worktree is a story about work in flight; check Linear/issue references in commit messages for its intent.

Design artifacts may exist only in branch history, not the working tree:

```bash
git log --all --oneline -- 'artifacts/'
git show <sha>:artifacts/current/design.md
```

Reading order: PR descriptions + review threads → design docs (design.md, implementation.md, briefing.md, ADRs) → commit sequence for the area → **the code as it stands now** (read the key files; the architecture description must match today's reality, since interviewers ask "how does it work", and getting this wrong in the recap poisons the whole rehearsal).

## Signals worth chasing

- A revert + reintroduction under a different design → ask "what broke the first approach?"
- A PR with a long review thread → the objection and its resolution is a ready-made trade-off answer.
- A config/dependency swap (ORM, queue, framework) → alternatives were weighed; find where.
- Large squashed agent-generated commits → presumed-weak area for the user (see Principles in SKILL.md).
- Commits referencing issue IDs (DONG-XX etc.) → the issue carries intent the commit message dropped.

## Recording provenance

As you collect, keep a working list where every fact carries its source:

```
✅ 改用 event-driven 是為了解耦 billing — PR #42 description
✅ Redis cache layer added after the N+1 fix failed — commit a1b2c3 + design.md v2
❓ 推測選 Postgres LISTEN/NOTIFY 而非 Kafka 是因為 ops 成本 — 無文件，需使用者確認
```

The ❓ list is a deliverable of this step — it becomes the confirmation checklist in the rehearsal.
